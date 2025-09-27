import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  
  // Dual-lane streams
  final StreamController<Uint8List> _micFrameController = StreamController<Uint8List>.broadcast(); // Raw mic frames
  final StreamController<Uint8List> _liveFrameController = StreamController<Uint8List>.broadcast(); // Lane 1: Live frames
  final StreamController<Uint8List> _utteranceController = StreamController<Uint8List>.broadcast(); // Lane 2: Complete utterances
  final StreamController<RecordingState> _stateController = StreamController<RecordingState>.broadcast();
  
  // VAD state with hysteresis
  final List<Uint8List> _utteranceBuffer = [];
  bool _isSpeaking = false;
  int _overCount = 0;
  int _underCount = 0;
  Timer? _maxSpeechTimer;
  
  // Adaptive noise floor
  double _noiseFloor = 0.01;
  static const double _noiseFloorAlpha = 0.95; // EMA smoothing factor
  static const double _speechMultiplier = 3.0; // Speech threshold = noiseFloor * multiplier
  
  // Configuration
  static const int _frameMs = 20; // 20ms frames for live streaming
  static const int _frameBytes = 16000 * 1 * 2 * _frameMs ~/ 1000; // 640 bytes per frame
  static const int _startFrames = 2; // 40ms to start speech
  static const int _stopFrames = 10; // 200ms to stop speech
  static const int _maxSpeechDurationMs = 5000; // Force send after 5 seconds
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
  
  /// Initialize the recorder
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _recorder.openRecorder();
      _isInitialized = true;
      print('🎤 AUDIO RECORDING: Initialized successfully');
    } catch (e) {
      print('❌ AUDIO RECORDING: Initialization failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Start recording with dual-lane streaming
  Future<void> startRecording() async {
    if (_isRecording || !_isInitialized) return;
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('❌ AUDIO RECORDING: Microphone permission denied');
        _stateController.add(RecordingState.error);
        return;
      }
      
      // Reset VAD state
      _resetVadState();
      
      // Start recording with PCM16, 16kHz, mono
      await _recorder.startRecorder(
        toStream: _micFrameController,
        codec: Codec.pcm16,
        sampleRate: _sampleRate,
        numChannels: 1,
      );
      
      _isRecording = true;
      _stateController.add(RecordingState.recording);
      
      // Start processing mic frames
      _startMicFrameProcessing();
      
      print('🎤 AUDIO RECORDING: Started with dual-lane streaming');
      print('   - Lane 1: Live frames (${_frameMs}ms, ${_frameBytes} bytes)');
      print('   - Lane 2: VAD utterances with hysteresis');
      
    } catch (e) {
      print('❌ AUDIO RECORDING: Start failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _recorder.stopRecorder();
      _isRecording = false;
      
      // Flush any remaining frames
      _flushRemainingFrames();
      
      // Send any remaining utterance
      if (_isSpeaking && _utteranceBuffer.isNotEmpty) {
        _flushUtterance();
      }
      
      _stateController.add(RecordingState.stopped);
      print('🎤 AUDIO RECORDING: Stopped');
      
    } catch (e) {
      print('❌ AUDIO RECORDING: Stop failed: $e');
      _stateController.add(RecordingState.error);
    }
  }
  
  /// Start processing mic frames for dual-lane streaming
  void _startMicFrameProcessing() {
    _micFrameController.stream.listen((pcmData) {
      _processMicFrame(pcmData);
    });
  }
  
  /// Process each mic frame for dual-lane streaming
  void _processMicFrame(Uint8List pcmData) {
    // Lane 1: Live streaming - slice into 20ms frames
    _frameBuffer.add(pcmData);
    final buffer = _frameBuffer.toBytes();
    var offset = 0;
    
    while (buffer.length - offset >= _frameBytes) {
      final frame = Uint8List.sublistView(buffer, offset, offset + _frameBytes);
      
      // Only send live frames when speech is detected and frame is not silent
      if (_isSpeaking && !_isSilentFrame(frame)) {
        _liveFrameController.add(frame);
      }
      
      offset += _frameBytes;
    }
    
    _frameBuffer.clear();
    if (offset < buffer.length) {
      _frameBuffer.add(Uint8List.sublistView(buffer, offset));
    }
    
    // Lane 2: VAD with hysteresis
    final isSpeech = _rmsAboveAdaptiveThreshold(pcmData);
    _updateVadState(isSpeech, pcmData);
  }
  
  /// Calculate RMS and check against adaptive threshold with speech characteristics
  bool _rmsAboveAdaptiveThreshold(Uint8List pcmData) {
    final rms = _calculateRms(pcmData);
    
    // Update adaptive noise floor (EMA)
    if (rms < _noiseFloor * _speechMultiplier) {
      _noiseFloor = _noiseFloorAlpha * _noiseFloor + (1 - _noiseFloorAlpha) * rms;
    }
    
    final threshold = _noiseFloor * _speechMultiplier;
    final isAboveThreshold = rms > threshold;
    
    // Additional speech characteristics check (temporarily disabled)
    // if (isAboveThreshold) {
    //   return _hasSpeechCharacteristics(pcmData);
    // }
    
    return isAboveThreshold;
  }
  
  /// Calculate RMS (Root Mean Square) of PCM data
  double _calculateRms(Uint8List pcmData) {
    if (pcmData.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (int i = 0; i < pcmData.length; i += 2) {
      if (i + 1 < pcmData.length) {
        // Convert bytes to 16-bit signed integer (little-endian)
        final sample = (pcmData[i] | (pcmData[i + 1] << 8));
        final signedSample = sample > 32767 ? sample - 65536 : sample;
        sum += signedSample * signedSample;
      }
    }
    
    return sqrt(sum / (pcmData.length / 2));
  }
  
  /// Update VAD state with hysteresis
  void _updateVadState(bool isSpeech, Uint8List pcmData) {
    if (isSpeech) {
      _overCount++;
      _underCount = 0;
      
      if (!_isSpeaking && _overCount >= _startFrames) {
        // Speech started
        _isSpeaking = true;
        _utteranceBuffer.clear();
        _maxSpeechTimer?.cancel();
        _maxSpeechTimer = Timer(
          Duration(milliseconds: _maxSpeechDurationMs),
          () {
            if (_isSpeaking && _utteranceBuffer.isNotEmpty) {
              print('🎤 AUDIO RECORDING: Force sending utterance after ${_maxSpeechDurationMs}ms');
              _flushUtterance();
            }
          },
        );
        print('🎤 AUDIO RECORDING: Speech started (${_overCount} frames)');
      }
      
      if (_isSpeaking) {
        _utteranceBuffer.add(pcmData);
      }
    } else {
      _underCount++;
      _overCount = 0;
      
      if (_isSpeaking && _underCount >= _stopFrames) {
        // Speech ended
        _maxSpeechTimer?.cancel();
        if (_utteranceBuffer.isNotEmpty) {
          print('🎤 AUDIO RECORDING: Speech ended (${_underCount} frames)');
          _flushUtterance();
        }
        _isSpeaking = false;
      }
    }
  }
  
  /// Flush utterance buffer as complete sentence
  void _flushUtterance() {
    if (_utteranceBuffer.isEmpty || !_isSpeaking) return;
    
    try {
      // Combine all PCM chunks
      final totalBytes = _utteranceBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Uint8List(totalBytes);
      var offset = 0;
      
      for (final chunk in _utteranceBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Wrap with WAV header for complete utterance
      final wavBytes = _wrapPcmAsWav(combinedAudio, _sampleRate, numChannels: 1);
      _utteranceController.add(wavBytes);
      
      print('📤 AUDIO RECORDING: Sent utterance (${wavBytes.length} bytes)');
      
      // Reset utterance buffer
      _utteranceBuffer.clear();
      _isSpeaking = false;
      
    } catch (e) {
      print('❌ AUDIO RECORDING: Utterance flush error: $e');
    }
  }
  
  /// Flush any remaining frames in buffer
  void _flushRemainingFrames() {
    if (_frameBuffer.isNotEmpty) {
      final remainingFrames = _frameBuffer.toBytes();
      _liveFrameController.add(remainingFrames);
      _frameBuffer.clear();
      print('📤 AUDIO RECORDING: Flushed remaining frames (${remainingFrames.length} bytes)');
    }
  }
  
  /// Reset VAD state
  void _resetVadState() {
    _utteranceBuffer.clear();
    _isSpeaking = false;
    _overCount = 0;
    _underCount = 0;
    _maxSpeechTimer?.cancel();
    _maxSpeechTimer = null;
    _noiseFloor = 0.01; // Reset noise floor
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
      await _recorder.closeRecorder();
      await _micFrameController.close();
      await _liveFrameController.close();
      await _utteranceController.close();
      await _stateController.close();
      print('🗑️ AUDIO RECORDING: Service disposed');
    } catch (e) {
      print('❌ AUDIO RECORDING: Dispose error: $e');
    }
  }
  
  /// Analyze audio characteristics to distinguish speech from noise
  bool _hasSpeechCharacteristics(Uint8List pcmData) {
    if (pcmData.isEmpty) return false;
    
    // 1. Zero Crossing Rate (ZCR) - speech has moderate ZCR, noise has high ZCR
    final zcr = _calculateZeroCrossingRate(pcmData);
    if (zcr > 0.3) return false; // High ZCR indicates noise
    
    // 2. Spectral Centroid - speech has lower spectral centroid than noise
    final spectralCentroid = _calculateSpectralCentroid(pcmData);
    if (spectralCentroid > 2000) return false; // High frequency indicates noise
    
    // 3. Energy distribution - speech has more energy in lower frequencies
    final energyRatio = _calculateLowHighEnergyRatio(pcmData);
    if (energyRatio < 0.5) return false; // Low ratio indicates noise
    
    // 4. Temporal variation - speech has more variation than steady noise
    final temporalVariation = _calculateTemporalVariation(pcmData);
    if (temporalVariation < 0.1) return false; // Low variation indicates noise
    
    return true; // Passed all speech characteristic tests
  }
  
  /// Calculate Zero Crossing Rate
  double _calculateZeroCrossingRate(Uint8List pcmData) {
    int crossings = 0;
    for (int i = 1; i < pcmData.length - 1; i += 2) {
      int current = (pcmData[i] & 0xFF) | ((pcmData[i + 1] & 0xFF) << 8);
      if (current > 32767) current -= 65536;
      
      int previous = (pcmData[i - 1] & 0xFF) | ((pcmData[i] & 0xFF) << 8);
      if (previous > 32767) previous -= 65536;
      
      if ((current >= 0) != (previous >= 0)) {
        crossings++;
      }
    }
    return crossings / (pcmData.length / 2);
  }
  
  /// Calculate Spectral Centroid (simplified frequency analysis)
  double _calculateSpectralCentroid(Uint8List pcmData) {
    // Simplified frequency analysis using sample variation
    double sum = 0;
    double weightedSum = 0;
    
    for (int i = 0; i < pcmData.length - 1; i += 2) {
      int sample = (pcmData[i] & 0xFF) | ((pcmData[i + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536;
      
      double magnitude = sample.abs().toDouble();
      sum += magnitude;
      weightedSum += magnitude * (i / 2); // Weight by sample position
    }
    
    return sum > 0 ? weightedSum / sum : 0;
  }
  
  /// Calculate Low/High frequency energy ratio
  double _calculateLowHighEnergyRatio(Uint8List pcmData) {
    double lowEnergy = 0;
    double highEnergy = 0;
    int halfLength = pcmData.length ~/ 2;
    
    // Low frequency (first half)
    for (int i = 0; i < halfLength - 1; i += 2) {
      int sample = (pcmData[i] & 0xFF) | ((pcmData[i + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536;
      lowEnergy += sample * sample;
    }
    
    // High frequency (second half)
    for (int i = halfLength; i < pcmData.length - 1; i += 2) {
      int sample = (pcmData[i] & 0xFF) | ((pcmData[i + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536;
      highEnergy += sample * sample;
    }
    
    return highEnergy > 0 ? lowEnergy / highEnergy : 1.0;
  }
  
  /// Calculate temporal variation (variance in amplitude)
  double _calculateTemporalVariation(Uint8List pcmData) {
    if (pcmData.length < 4) return 0;
    
    List<double> amplitudes = [];
    for (int i = 0; i < pcmData.length - 1; i += 2) {
      int sample = (pcmData[i] & 0xFF) | ((pcmData[i + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536;
      amplitudes.add(sample.abs().toDouble());
    }
    
    if (amplitudes.isEmpty) return 0;
    
    double mean = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    double variance = amplitudes.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / amplitudes.length;
    
    return sqrt(variance) / mean; // Coefficient of variation
  }
  
  /// Check if a frame is silent (all zeros or very low amplitude)
  bool _isSilentFrame(Uint8List frame) {
    if (frame.isEmpty) return true;
    
    // Calculate RMS (Root Mean Square) to detect silence
    double sum = 0;
    int sampleCount = 0;
    
    // Process 16-bit PCM samples (2 bytes per sample)
    for (int i = 0; i < frame.length - 1; i += 2) {
      // Convert bytes to 16-bit signed integer
      int sample = (frame[i] & 0xFF) | ((frame[i + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536; // Convert to signed
      
      sum += sample * sample;
      sampleCount++;
    }
    
    if (sampleCount == 0) return true;
    
    double rms = sqrt(sum / sampleCount);
    double threshold = 100.0; // Same threshold as server-side
    
    return rms < threshold;
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
