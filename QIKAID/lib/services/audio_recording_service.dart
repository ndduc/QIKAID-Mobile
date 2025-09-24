import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  // Public stream: emits only aggregated utterances (complete sentences)
  StreamController<Uint8List> _audioDataController = 
      StreamController<Uint8List>.broadcast();
  // Internal stream: receives raw mic frames from the recorder
  StreamController<Uint8List> _micFrameController = 
      StreamController<Uint8List>.broadcast();
  // Optional public stream for completed utterances (if needed by UI)
  StreamController<Uint8List> _utteranceController = 
      StreamController<Uint8List>.broadcast();
  StreamController<RecordingState> _stateController = 
      StreamController<RecordingState>.broadcast();
  
  bool _isRecording = false;
  bool _isInitialized = false;
  Timer? _recordingTimer;
  Timer? _silenceTimer;
  
  // Audio buffer for speech detection
  List<Uint8List> _audioBuffer = [];
  bool _isSpeaking = false;
  bool _hasSpeechStarted = false;
  Timer? _maxSpeechTimer; // Timer to force send after max speech duration
  
  // Configuration
  static const int _chunkDurationMs = 200; // Process audio every 200ms for VAD
  static const int _silenceTimeoutMs = 1000; // 1 second of silence = sentence end
  static const int _maxSpeechDurationMs = 5000; // Force send after 5 seconds of continuous speech
  static const double _speechThreshold = 0.02; // RMS threshold for speech detection
  static const int _sampleRate = 16000;
  
  // Getters
  // Raw mic frames (use this for real-time streaming to WS)
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  // Completed utterances after VAD segmentation (optional consumer)
  Stream<Uint8List> get utteranceStream => _utteranceController.stream;
  Stream<RecordingState> get stateStream => _stateController.stream;
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the audio recording service
  Future<bool> initialize() async {
    try {
      print('🎤 AUDIO RECORDING: Initializing audio recording service...');
      
      // Check microphone permission
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        print('❌ AUDIO RECORDING: Microphone permission denied');
        _stateController.add(RecordingState.error('Microphone permission required'));
        return false;
      }
      
      // Open the recorder
      await _recorder.openRecorder();
      print('✅ AUDIO RECORDING: Recorder opened successfully');
      
      // Listen to raw mic frames and run VAD/segmentation
      _micFrameController.stream.listen((audioData) {
        _processRealTimeAudioData(audioData);
      });
      
      _isInitialized = true;
      _stateController.add(RecordingState.initialized());
      
      print('✅ AUDIO RECORDING: Service initialized successfully');
      return true;
    } catch (e) {
      print('❌ AUDIO RECORDING INIT ERROR: $e');
      _stateController.add(RecordingState.error('Initialization failed: $e'));
      return false;
    }
  }
  
  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      print('🎤 AUDIO RECORDING: Starting audio recording...');
      
      if (!_isInitialized) {
        print('🎤 AUDIO RECORDING: Service not initialized, initializing...');
        final initialized = await initialize();
        if (!initialized) {
          print('❌ AUDIO RECORDING: Failed to initialize service');
          return false;
        }
      }
      
      if (_isRecording) {
        print('⚠️ AUDIO RECORDING: Already recording');
        return true;
      }
      
      // Start recording with real microphone
      await _recorder.startRecorder(
        toStream: _micFrameController,
        codec: Codec.pcm16, // raw PCM frames, no per-chunk WAV headers
        sampleRate: _sampleRate,
      );
      
      _isRecording = true;
      _stateController.add(RecordingState.recording());
      
      // Start periodic audio chunk processing
      _startAudioChunkProcessing();
      
      print('✅ AUDIO RECORDING: Recording started successfully');
      return true;
    } catch (e) {
      print('❌ AUDIO RECORDING START ERROR: $e');
      _stateController.add(RecordingState.error('Failed to start recording: $e'));
      return false;
    }
  }
  
  /// Stop recording audio
  Future<void> stopRecording() async {
    try {
      print('🛑 AUDIO RECORDING: Stopping audio recording...');
      
      if (!_isRecording) {
        print('⚠️ AUDIO RECORDING: Not currently recording');
        return;
      }
      
      // Stop the recording timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      // Stop silence timer
      _silenceTimer?.cancel();
      _silenceTimer = null;
      
      // Stop max speech timer
      _maxSpeechTimer?.cancel();
      _maxSpeechTimer = null;
      
      // Send any remaining buffered audio (final sentence)
      if (_hasSpeechStarted && _audioBuffer.isNotEmpty) {
        print('📤 AUDIO RECORDING: Sending final buffered audio before stopping');
        _sendBufferedAudio();
        // Reset state after sending final audio
        _hasSpeechStarted = false;
        _audioBuffer.clear();
      }
      
      // Stop recording
      await _recorder.stopRecorder();
      
      _isRecording = false;
      _isSpeaking = false;
      _hasSpeechStarted = false;
      _audioBuffer.clear();
      
      _stateController.add(RecordingState.stopped());
      
      print('✅ AUDIO RECORDING: Recording stopped successfully');
    } catch (e) {
      print('❌ AUDIO RECORDING STOP ERROR: $e');
      _stateController.add(RecordingState.error('Failed to stop recording: $e'));
    }
  }
  
  /// Start periodic audio chunk processing with speech detection
  void _startAudioChunkProcessing() {
    _recordingTimer = Timer.periodic(
      Duration(milliseconds: _chunkDurationMs),
      (timer) async {
        if (_isRecording) {
          await _processAudioChunkWithVAD();
        }
      },
    );
  }
  
  /// Process real-time audio data from flutter_sound
  void _processRealTimeAudioData(Uint8List audioData) {
    try {
      // Analyze audio for speech activity
      final hasSpeech = _detectSpeech(audioData);
      
      if (hasSpeech) {
        print('🎤 AUDIO RECORDING: Speech detected - buffering audio');
        _handleSpeechDetected(audioData);
      } else {
        print('🔇 AUDIO RECORDING: Silence detected');
        _handleSilenceDetected();
      }
    } catch (e) {
      print('❌ AUDIO RECORDING: Error processing real-time audio: $e');
    }
  }

  /// Process audio chunk with Voice Activity Detection (VAD) - fallback method
  Future<void> _processAudioChunkWithVAD() async {
    try {
      // This method is kept for compatibility but real-time processing
      // now happens in _processRealTimeAudioData
      if (_isRecording) {
        // Generate fallback audio data if needed
        final audioData = _generateRealTimeAudioChunk();
        
        if (audioData != null) {
          _processRealTimeAudioData(audioData);
        }
      }
    } catch (e) {
      print('❌ AUDIO RECORDING CHUNK ERROR: $e');
    }
  }
  
  /// Detect speech in audio data
  bool _detectSpeech(Uint8List audioData) {
    // RMS-based speech detection on signed 16-bit PCM (little-endian)
    double sumSquares = 0.0;
    int sampleCount = audioData.length ~/ 2;
    for (int i = 0; i + 1 < audioData.length; i += 2) {
      int lo = audioData[i];
      int hi = audioData[i + 1];
      int sample = (hi << 8) | lo; // little-endian
      if ((sample & 0x8000) != 0) {
        sample = sample - 0x10000; // convert to signed 16-bit
      }
      double normalized = sample / 32768.0; // -1.0..+1.0
      sumSquares += normalized * normalized;
    }
    double rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) : 0.0;
    bool hasSpeech = rms > _speechThreshold;
    print('🎤 AUDIO RECORDING: RMS: ${rms.toStringAsFixed(4)}, Speech: $hasSpeech');
    return hasSpeech;
  }
  
  /// Handle when speech is detected
  void _handleSpeechDetected(Uint8List audioData) {
    if (!_isSpeaking) {
      print('🎤 AUDIO RECORDING: Speech started');
      _isSpeaking = true;
      _hasSpeechStarted = true;
      _audioBuffer.clear();
      
      // Start max speech timer to force send after continuous speech
      _maxSpeechTimer = Timer(
        Duration(milliseconds: _maxSpeechDurationMs),
        () {
          if (_hasSpeechStarted && _audioBuffer.isNotEmpty) {
            print('📤 AUDIO RECORDING: Force sending after ${_maxSpeechDurationMs}ms of continuous speech');
            _sendBufferedAudio();
            // Reset for next sentence - continue listening
            _hasSpeechStarted = false;
            _audioBuffer.clear();
            _isSpeaking = false;
          }
        },
      );
    }
    
    // Add audio to buffer
    _audioBuffer.add(audioData);
    
    // Cancel silence timer since we're speaking
    _silenceTimer?.cancel();
  }
  
  /// Handle when silence is detected
  void _handleSilenceDetected() {
    if (_isSpeaking) {
      print('🔇 AUDIO RECORDING: Speech ended, starting silence timer');
      _isSpeaking = false;
      
      // Cancel max speech timer since we detected silence
      _maxSpeechTimer?.cancel();
      _maxSpeechTimer = null;
      
      // Start silence timer - if no speech for timeout period, send buffered audio
      _silenceTimer = Timer(
        Duration(milliseconds: _silenceTimeoutMs),
        () {
          if (_hasSpeechStarted && _audioBuffer.isNotEmpty) {
            print('📤 AUDIO RECORDING: Sending complete sentence after ${_silenceTimeoutMs}ms silence');
            _sendBufferedAudio();
            // Reset for next sentence - continue listening
            _hasSpeechStarted = false;
            _audioBuffer.clear();
          }
        },
      );
    }
  }
  
  /// Send buffered audio as a complete sentence
  void _sendBufferedAudio() {
    try {
      if (_audioBuffer.isEmpty) return;
      
      print('📤 AUDIO RECORDING: Sending complete sentence (${_audioBuffer.length} chunks, ${_audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length)} bytes)');
      
      // Combine all buffered audio chunks
      final totalLength = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Uint8List(totalLength);
      
      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Wrap the combined raw PCM into a single WAV with one header
      final wavBytes = _wrapPcmAsWav(combinedAudio, _sampleRate, numChannels: 1);

      // Emit the complete sentence WAV to the utterance stream
      _utteranceController.add(wavBytes);
      
      print('✅ AUDIO RECORDING: Complete sentence sent (${combinedAudio.length} bytes)');
      
    } catch (e) {
      print('❌ AUDIO RECORDING SEND ERROR: $e');
    }
  }
  
  /// Generate real-time audio chunk (placeholder for actual microphone input)
  Uint8List? _generateRealTimeAudioChunk() {
    try {
      // This is a placeholder method
      // In a real implementation, you would:
      // 1. Read from microphone stream
      // 2. Process raw audio data
      // 3. Return actual audio bytes
      
      // For now, we'll generate audio that represents microphone input
      // This simulates what would come from a real microphone
      final samples = (_sampleRate * (_chunkDurationMs / 1000)).round();
      final audioData = Uint8List(samples * 2);
      
      // Generate audio that simulates real microphone input
      // This includes background noise and potential speech
      final random = Random();
      for (int i = 0; i < samples; i++) {
        // Simulate background noise + potential speech
        final noise = (random.nextDouble() - 0.5) * 0.1; // Background noise
        final speech = random.nextDouble() > 0.7 ? (random.nextDouble() - 0.5) * 0.5 : 0; // Occasional speech
        
        final sample = ((noise + speech) * 32767).round();
        final clampedSample = sample.clamp(-32768, 32767);
        
        audioData[i * 2] = clampedSample & 0xFF;
        audioData[i * 2 + 1] = (clampedSample >> 8) & 0xFF;
      }
      
      return audioData;
    } catch (e) {
      print('❌ AUDIO RECORDING: Error generating real-time audio chunk: $e');
      return null;
    }
  }
  
  /// Check microphone permission
  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ AUDIO RECORDING: Permission check error: $e');
      return false;
    }
  }
  
  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopRecording();
      await _micFrameController.close();
      await _utteranceController.close();
      await _audioDataController.close();
      await _stateController.close();
      await _recorder.closeRecorder();
      print('🗑️ AUDIO RECORDING: Service disposed');
    } catch (e) {
      print('❌ AUDIO RECORDING DISPOSE ERROR: $e');
    }
  }

  /// Create a minimal WAV header and prepend to PCM16LE mono data
  Uint8List _wrapPcmAsWav(Uint8List pcm, int sampleRate, {int numChannels = 1, int bitsPerSample = 16}) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final subchunk2Size = pcm.length;
    final chunkSize = 36 + subchunk2Size;

    final header = BytesBuilder();
    // RIFF chunk descriptor
    header.add(ascii.encode('RIFF'));
    header.add(_intToBytesLE(chunkSize, 4));
    header.add(ascii.encode('WAVE'));
    // fmt subchunk
    header.add(ascii.encode('fmt '));
    header.add(_intToBytesLE(16, 4)); // Subchunk1Size for PCM
    header.add(_intToBytesLE(1, 2)); // AudioFormat = 1 (PCM)
    header.add(_intToBytesLE(numChannels, 2));
    header.add(_intToBytesLE(sampleRate, 4));
    header.add(_intToBytesLE(byteRate, 4));
    header.add(_intToBytesLE(blockAlign, 2));
    header.add(_intToBytesLE(bitsPerSample, 2));
    // data subchunk
    header.add(ascii.encode('data'));
    header.add(_intToBytesLE(subchunk2Size, 4));

    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(header.toBytes());
    bytesBuilder.add(pcm);
    return bytesBuilder.toBytes();
  }

  Uint8List _intToBytesLE(int value, int byteCount) {
    final bytes = Uint8List(byteCount);
    for (int i = 0; i < byteCount; i++) {
      bytes[i] = (value >> (8 * i)) & 0xFF;
    }
    return bytes;
  }
}

/// Recording state class
class RecordingState {
  final bool isInitialized;
  final bool isRecording;
  final bool isStopped;
  final String? error;
  
  const RecordingState({
    this.isInitialized = false,
    this.isRecording = false,
    this.isStopped = false,
    this.error,
  });
  
  factory RecordingState.initialized() {
    return const RecordingState(isInitialized: true);
  }
  
  factory RecordingState.recording() {
    return const RecordingState(isInitialized: true, isRecording: true);
  }
  
  factory RecordingState.stopped() {
    return const RecordingState(isInitialized: true, isStopped: true);
  }
  
  factory RecordingState.error(String error) {
    return RecordingState(error: error);
  }
  
  bool get hasError => error != null;
}
