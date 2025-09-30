import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:vad/vad.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingServiceVAD {
  VadHandlerBase? _vadHandler;
  
  // Dual-lane streams (maintaining compatibility with existing code)
  final StreamController<Uint8List> _liveFrameController = StreamController<Uint8List>.broadcast(); // Lane 1: Live frames
  final StreamController<Uint8List> _utteranceController = StreamController<Uint8List>.broadcast(); // Lane 2: Complete utterances
  final StreamController<RecordingState> _stateController = StreamController<RecordingState>.broadcast();
  
  // Sentence detection state
  final List<double> _sentenceBuffer = [];
  Timer? _sentenceTimer;
  bool _isSpeaking = false;
  bool _hasSpeechStarted = false;
  
  // Configuration
  static const int _frameMs = 20; // 20ms frames for live streaming
  static const int _frameBytes = 16000 * 1 * 2 * _frameMs ~/ 1000; // 640 bytes per frame
  static const int _silenceTimeoutMs = 1500; // 1.5 seconds of silence = sentence end
  static const int _sampleRate = 16000;
  
  // Buffer for 20ms frame slicing
  final BytesBuilder _frameBuffer = BytesBuilder();
  
  bool _isRecording = false;
  bool _isInitialized = false;
  
  // Public getters
  Stream<Uint8List> get liveFrameStream => _liveFrameController.stream;
  Stream<Uint8List> get utteranceStream => _utteranceController.stream;
  Stream<RecordingState> get stateStream => _stateController.stream;
  bool get isRecording => _isRecording;
  
  /// Initialize the VAD handler
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Create VAD handler
      _vadHandler = VadHandler.create(isDebug: true);
      
      // Setup VAD event listeners
      _setupVadListeners();
      
      _isInitialized = true;
      print('🎤 VAD AUDIO RECORDING: Initialized successfully');
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Initialization failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Setup VAD event listeners
  void _setupVadListeners() {
    if (_vadHandler == null) return;
    
    // Speech start detection
    _vadHandler!.onSpeechStart.listen((_) {
      print('🎤 VAD AUDIO RECORDING: Speech start detected');
      _handleSpeechStart();
    });
    
    // Real speech start (not misfire)
    _vadHandler!.onRealSpeechStart.listen((_) {
      print('🎤 VAD AUDIO RECORDING: Real speech start confirmed');
      _handleRealSpeechStart();
    });
    
    // Speech end detection
    _vadHandler!.onSpeechEnd.listen((List<double> samples) {
      print('🎤 VAD AUDIO RECORDING: Speech end detected (${samples.length} samples)');
      _handleSpeechEnd(samples);
    });
    
    // VAD misfire detection
    _vadHandler!.onVADMisfire.listen((_) {
      print('⚠️ VAD AUDIO RECORDING: VAD misfire detected');
      _handleVadMisfire();
    });
    
    // Frame processing for live streaming
    _vadHandler!.onFrameProcessed.listen((frameData) {
      _handleFrameProcessed(frameData);
    });
    
    // Error handling
    _vadHandler!.onError.listen((error) {
      print('❌ VAD AUDIO RECORDING: VAD error: $error');
      _stateController.add(RecordingState.error);
    });
  }
  
  /// Start recording with VAD
  Future<void> startRecording() async {
    if (_isRecording || !_isInitialized) return;
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('❌ VAD AUDIO RECORDING: Microphone permission denied');
        _stateController.add(RecordingState.error);
        return;
      }
      
      // Reset sentence detection state
      _resetSentenceState();
      
      // Start VAD listening with optimized parameters
      await _vadHandler!.startListening(
        positiveSpeechThreshold: 0.5,    // Speech detection threshold
        negativeSpeechThreshold: 0.35,   // Silence detection threshold
        preSpeechPadFrames: 1,           // Frames before speech starts
        redemptionFrames: 8,             // Frames to wait before ending speech
        frameSamples: 1536,             // Samples per frame
        minSpeechFrames: 3,             // Minimum frames for valid speech
        submitUserSpeechOnPause: false,  // Don't auto-submit on pause
        model: 'legacy',                // Use legacy model for compatibility
      );
      
      _isRecording = true;
      _stateController.add(RecordingState.recording);
      
      print('🎤 VAD AUDIO RECORDING: Started with VAD-based detection');
      print('   - Lane 1: Live frames (${_frameMs}ms, ${_frameBytes} bytes)');
      print('   - Lane 2: VAD utterances with sentence detection');
      
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Start failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _vadHandler!.stopListening();
      _isRecording = false;
      
      // Flush any remaining frames
      _flushRemainingFrames();
      
      // Send any remaining sentence
      if (_isSpeaking && _sentenceBuffer.isNotEmpty) {
        _flushSentence();
      }
      
      _stateController.add(RecordingState.stopped);
      print('🎤 VAD AUDIO RECORDING: Stopped');
      
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Stop failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Handle speech start event
  void _handleSpeechStart() {
    if (!_isSpeaking) {
      print('🎤 VAD AUDIO RECORDING: Speech started');
      _isSpeaking = true;
      _hasSpeechStarted = true;
      _sentenceBuffer.clear();
    }
    
    // Cancel sentence timer since we're speaking
    _sentenceTimer?.cancel();
  }
  
  /// Handle real speech start (not misfire)
  void _handleRealSpeechStart() {
    print('🎤 VAD AUDIO RECORDING: Real speech confirmed');
    // Additional logic for confirmed speech can be added here
  }
  
  /// Handle speech end event
  void _handleSpeechEnd(List<double> samples) {
    if (_isSpeaking) {
      print('🎤 VAD AUDIO RECORDING: Speech ended, starting sentence timer');
      _isSpeaking = false;
      
      // Add samples to sentence buffer
      _sentenceBuffer.addAll(samples);
      
      // Start sentence completion timer
      _sentenceTimer = Timer(
        Duration(milliseconds: _silenceTimeoutMs),
        () {
          if (_hasSpeechStarted && _sentenceBuffer.isNotEmpty) {
            _flushSentence();
          }
        },
      );
    }
  }
  
  /// Handle VAD misfire
  void _handleVadMisfire() {
    print('⚠️ VAD AUDIO RECORDING: VAD misfire - ignoring false speech detection');
    // Reset state on misfire
    _isSpeaking = false;
    _sentenceTimer?.cancel();
  }
  
  /// Handle frame processing for live streaming
  void _handleFrameProcessed(dynamic frameData) {
    try {
      // Extract audio samples and speech probability from VAD frame data
      if (frameData != null && frameData is Map) {
        // Extract audio samples
        final audioSamples = _extractAudioSamples(frameData);
        
        // Extract speech probability
        final isSpeechProb = frameData['isSpeech'] as double? ?? 0.0;
        final notSpeechProb = frameData['notSpeech'] as double? ?? 0.0;
        
        if (audioSamples != null && audioSamples.isNotEmpty) {
          // Convert samples to PCM bytes for live streaming
          final pcmBytes = _convertSamplesToPcm(audioSamples);
          
          // Add to frame buffer for slicing
          _frameBuffer.add(pcmBytes);
          final buffer = _frameBuffer.toBytes();
          var offset = 0;
          
          // Slice into 20ms frames for live streaming
          while (buffer.length - offset >= _frameBytes) {
            final frame = Uint8List.sublistView(buffer, offset, offset + _frameBytes);
            
            // Only send live frames when speech is detected (either by VAD state or probability)
            final hasSpeechProbability = isSpeechProb > 0.5;
            if (_isSpeaking || hasSpeechProbability) {
              _liveFrameController.add(frame);
            }
            
            offset += _frameBytes;
          }
          
          _frameBuffer.clear();
          if (offset < buffer.length) {
            _frameBuffer.add(Uint8List.sublistView(buffer, offset));
          }
          
          print('🎤 VAD AUDIO RECORDING: Frame processed (${audioSamples.length} samples, speech: ${isSpeechProb.toStringAsFixed(3)})');
        }
      }
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Frame processing error: $e');
    }
  }
  
  /// Extract audio samples from VAD frame data
  List<double>? _extractAudioSamples(dynamic frameData) {
    try {
      // Handle the actual VAD package frame data structure
      if (frameData is Map) {
        // VAD package structure: {List<double> frame, double isSpeech, double notSpeech}
        if (frameData.containsKey('frame')) {
          final frame = frameData['frame'];
          if (frame is List) {
            return frame.cast<double>();
          }
        }
        
        // Try other possible property names
        if (frameData.containsKey('samples')) {
          final samples = frameData['samples'];
          if (samples is List) {
            return samples.cast<double>();
          }
        }
        if (frameData.containsKey('audio')) {
          final audio = frameData['audio'];
          if (audio is List) {
            return audio.cast<double>();
          }
        }
      }
      
      // If frameData is directly a list of samples
      if (frameData is List) {
        return frameData.cast<double>();
      }
      
      print('⚠️ VAD AUDIO RECORDING: Unknown frame data structure: ${frameData.runtimeType}');
      print('⚠️ VAD AUDIO RECORDING: Frame data keys: ${frameData is Map ? frameData.keys.toList() : 'Not a Map'}');
      return null;
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Error extracting samples: $e');
      return null;
    }
  }
  
  /// Flush sentence buffer as complete utterance
  void _flushSentence() {
    if (_sentenceBuffer.isEmpty || !_hasSpeechStarted) return;
    
    try {
      // Convert samples to PCM bytes
      final pcmBytes = _convertSamplesToPcm(_sentenceBuffer);
      
      // Wrap with WAV header for complete utterance
      final wavBytes = _wrapPcmAsWav(pcmBytes, _sampleRate, numChannels: 1);
      _utteranceController.add(wavBytes);
      
      print('📤 VAD AUDIO RECORDING: Sent complete sentence (${wavBytes.length} bytes)');
      
      // Reset sentence buffer
      _sentenceBuffer.clear();
      _hasSpeechStarted = false;
      
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Sentence flush error: $e');
    }
  }
  
  /// Flush any remaining frames in buffer
  void _flushRemainingFrames() {
    if (_frameBuffer.isNotEmpty) {
      final remainingFrames = _frameBuffer.toBytes();
      _liveFrameController.add(remainingFrames);
      _frameBuffer.clear();
      print('📤 VAD AUDIO RECORDING: Flushed remaining frames (${remainingFrames.length} bytes)');
    }
  }
  
  /// Reset sentence detection state
  void _resetSentenceState() {
    _sentenceBuffer.clear();
    _isSpeaking = false;
    _hasSpeechStarted = false;
    _sentenceTimer?.cancel();
    _sentenceTimer = null;
  }
  
  /// Convert double samples to PCM16 bytes
  Uint8List _convertSamplesToPcm(List<double> samples) {
    final pcmBytes = Uint8List(samples.length * 2);
    
    for (int i = 0; i < samples.length; i++) {
      // Convert double sample to 16-bit signed integer
      int sample = (samples[i] * 32767).round().clamp(-32768, 32767);
      
      // Convert to bytes (little-endian)
      pcmBytes[i * 2] = sample & 0xFF;
      pcmBytes[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    
    return pcmBytes;
  }
  
  /// Wrap PCM data with WAV header
  Uint8List _wrapPcmAsWav(Uint8List pcm, int sampleRate, {int numChannels = 1, int bitsPerSample = 16}) {
    final header = BytesBuilder();
    
    // RIFF header
    header.add(ascii.encode('RIFF'));
    header.addByte(0); header.addByte(0); header.addByte(0); header.addByte(0); // File size (placeholder)
    header.add(ascii.encode('WAVE'));
    
    // Format chunk
    header.add(ascii.encode('fmt '));
    header.addByte(16); header.addByte(0); header.addByte(0); header.addByte(0); // Chunk size
    header.addByte(1); header.addByte(0); // Audio format (PCM)
    header.addByte(numChannels); header.addByte(0); // Number of channels
    header.addByte(sampleRate & 0xFF); header.addByte((sampleRate >> 8) & 0xFF); 
    header.addByte((sampleRate >> 16) & 0xFF); header.addByte((sampleRate >> 24) & 0xFF); // Sample rate
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    header.addByte(byteRate & 0xFF); header.addByte((byteRate >> 8) & 0xFF);
    header.addByte((byteRate >> 16) & 0xFF); header.addByte((byteRate >> 24) & 0xFF); // Byte rate
    header.addByte(numChannels * bitsPerSample ~/ 8); header.addByte(0); // Block align
    header.addByte(bitsPerSample); header.addByte(0); // Bits per sample
    
    // Data chunk
    header.add(ascii.encode('data'));
    header.addByte(pcm.length & 0xFF); header.addByte((pcm.length >> 8) & 0xFF);
    header.addByte((pcm.length >> 16) & 0xFF); header.addByte((pcm.length >> 24) & 0xFF); // Data size
    header.add(pcm);
    
    // Update file size in RIFF header
    final bytes = header.toBytes();
    final fileSize = bytes.length - 8;
    bytes[4] = fileSize & 0xFF;
    bytes[5] = (fileSize >> 8) & 0xFF;
    bytes[6] = (fileSize >> 16) & 0xFF;
    bytes[7] = (fileSize >> 24) & 0xFF;
    
    return bytes;
  }
  
  
  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopRecording();
      await _vadHandler?.dispose();
      await _liveFrameController.close();
      await _utteranceController.close();
      await _stateController.close();
      print('🗑️ VAD AUDIO RECORDING: Service disposed');
    } catch (e) {
      print('❌ VAD AUDIO RECORDING: Dispose error: $e');
    }
  }
}

enum RecordingState {
  idle,
  recording,
  stopped,
  error,
}

extension RecordingStateExtension on RecordingState {
  bool get hasError => this == RecordingState.error;
  String? get error => hasError ? 'Audio recording error occurred' : null;
}