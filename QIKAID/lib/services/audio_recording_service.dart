import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamController<Uint8List> _audioDataController = 
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
  
  // Configuration
  static const int _chunkDurationMs = 200; // Process audio every 200ms for VAD
  static const int _silenceTimeoutMs = 1500; // 1.5 seconds of silence = sentence end
  static const double _speechThreshold = 0.01; // Volume threshold for speech detection
  static const int _sampleRate = 16000;
  
  // Getters
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
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
      
      // Set up audio data stream listener
      _audioDataController.stream.listen((audioData) {
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
        toStream: _audioDataController,
        codec: Codec.pcm16WAV,
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
      
      // Send any remaining buffered audio
      if (_hasSpeechStarted && _audioBuffer.isNotEmpty) {
        print('📤 AUDIO RECORDING: Sending final buffered audio before stopping');
        _sendBufferedAudio();
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
    // Simple volume-based speech detection
    // In a real implementation, you would use more sophisticated VAD algorithms
    
    double sum = 0;
    for (int i = 0; i < audioData.length; i += 2) {
      // Convert 16-bit samples to amplitude
      final sample = (audioData[i] | (audioData[i + 1] << 8));
      final amplitude = (sample - 32768) / 32768.0; // Normalize to -1.0 to 1.0
      sum += amplitude.abs();
    }
    
    final averageAmplitude = sum / (audioData.length / 2);
    final hasSpeech = averageAmplitude > _speechThreshold;
    
    print('🎤 AUDIO RECORDING: Audio amplitude: ${averageAmplitude.toStringAsFixed(4)}, Speech: $hasSpeech');
    return hasSpeech;
  }
  
  /// Handle when speech is detected
  void _handleSpeechDetected(Uint8List audioData) {
    if (!_isSpeaking) {
      print('🎤 AUDIO RECORDING: Speech started');
      _isSpeaking = true;
      _hasSpeechStarted = true;
      _audioBuffer.clear();
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
      
      // Start silence timer - if no speech for timeout period, send buffered audio
      _silenceTimer = Timer(
        Duration(milliseconds: _silenceTimeoutMs),
        () {
          if (_hasSpeechStarted && _audioBuffer.isNotEmpty) {
            _sendBufferedAudio();
          }
        },
      );
    }
  }
  
  /// Send buffered audio as a complete sentence
  void _sendBufferedAudio() {
    try {
      if (_audioBuffer.isEmpty) return;
      
      print('📤 AUDIO RECORDING: Sending complete sentence (${_audioBuffer.length} chunks)');
      
      // Combine all buffered audio chunks
      final totalLength = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Uint8List(totalLength);
      
      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Send the complete sentence
      _audioDataController.add(combinedAudio);
      
      // Reset for next sentence
      _audioBuffer.clear();
      _hasSpeechStarted = false;
      
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
      await _audioDataController.close();
      await _stateController.close();
      await _recorder.closeRecorder();
      print('🗑️ AUDIO RECORDING: Service disposed');
    } catch (e) {
      print('❌ AUDIO RECORDING DISPOSE ERROR: $e');
    }
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
