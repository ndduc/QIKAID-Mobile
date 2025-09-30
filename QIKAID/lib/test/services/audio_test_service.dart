import 'dart:async';
import 'package:vad/vad.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simple audio test service to debug VAD package issues
class AudioTestService {
  VadHandlerBase? _vadHandler;
  bool _isInitialized = false;
  bool _isRecording = false;
  
  // Test results
  final List<String> _testLogs = [];
  int _speechStartCount = 0;
  int _speechEndCount = 0;
  int _frameProcessedCount = 0;
  int _errorCount = 0;
  
  List<String> get testLogs => List.unmodifiable(_testLogs);
  int get speechStartCount => _speechStartCount;
  int get speechEndCount => _speechEndCount;
  int get frameProcessedCount => _frameProcessedCount;
  int get errorCount => _errorCount;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _testLogs.add('$timestamp - $message');
    print('🧪 AUDIO TEST: $message');
  }
  
  /// Initialize VAD handler with detailed logging
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _addLog('🔧 Initializing VAD handler...');
      
      // Check microphone permission first
      final permissionStatus = await Permission.microphone.status;
      _addLog('🎤 Microphone permission status: $permissionStatus');
      
      if (permissionStatus != PermissionStatus.granted) {
        _addLog('❌ Microphone permission not granted');
        return false;
      }
      
      // Create VAD handler
      _addLog('🔧 Creating VadHandler...');
      _vadHandler = VadHandler.create(isDebug: true);
      _addLog('✅ VadHandler created successfully');
      
      // Setup event listeners
      _setupVadListeners();
      
      _isInitialized = true;
      _addLog('✅ VAD service initialized successfully');
      return true;
      
    } catch (e, stackTrace) {
      _addLog('❌ VAD initialization failed: $e');
      _addLog('❌ Stack trace: $stackTrace');
      _errorCount++;
      return false;
    }
  }
  
  /// Setup VAD event listeners with detailed logging
  void _setupVadListeners() {
    if (_vadHandler == null) {
      _addLog('❌ Cannot setup listeners - VAD handler is null');
      return;
    }
    
    _addLog('🔧 Setting up VAD event listeners...');
    
    // Speech start detection
    _vadHandler!.onSpeechStart.listen((_) {
      _speechStartCount++;
      _addLog('🎤 Speech start detected (count: $_speechStartCount)');
    });
    
    // Real speech start (not misfire)
    _vadHandler!.onRealSpeechStart.listen((_) {
      _addLog('🎤 Real speech start confirmed');
    });
    
    // Speech end detection
    _vadHandler!.onSpeechEnd.listen((List<double> samples) {
      _speechEndCount++;
      _addLog('🔇 Speech end detected (${samples.length} samples, count: $_speechEndCount)');
    });
    
    // VAD misfire detection
    _vadHandler!.onVADMisfire.listen((_) {
      _addLog('⚠️ VAD misfire detected');
    });
    
    // Frame processing for live streaming
    _vadHandler!.onFrameProcessed.listen((frameData) {
      _frameProcessedCount++;
      _addLog('📊 Frame processed (count: $_frameProcessedCount)');
      
      // Log frame data details
      _addLog('📊 Frame data type: ${frameData.runtimeType}');
      
      // Handle VAD package specific frame data structure
      // The VAD package returns a record with frame, isSpeech, and notSpeech
      try {
        // Access the record fields directly
        final frameDataRecord = frameData as dynamic;
        if (frameDataRecord != null) {
          _addLog('📊 Frame data: $frameDataRecord');
          // Try to access common properties
          if (frameDataRecord.toString().contains('isSpeech')) {
            _addLog('📊 Contains speech probability data');
          }
        }
      } catch (e) {
        _addLog('📊 Frame data parsing error: $e');
      }
    });
    
    // Error handling
    _vadHandler!.onError.listen((error) {
      _errorCount++;
      _addLog('❌ VAD error: $error');
    });
    
    _addLog('✅ VAD event listeners setup complete');
  }
  
  /// Start recording with VAD
  Future<bool> startRecording() async {
    if (!_isInitialized || _isRecording) {
      _addLog('❌ Cannot start recording - not initialized or already recording');
      return false;
    }
    
    try {
      _addLog('🎤 Starting VAD recording...');
      
      // Request microphone permission
      final status = await Permission.microphone.request();
      _addLog('🎤 Microphone permission request result: $status');
      
      if (status != PermissionStatus.granted) {
        _addLog('❌ Microphone permission denied');
        return false;
      }
      
      // Start VAD listening with optimized parameters
      _addLog('🔧 Starting VAD listening...');
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
      _addLog('✅ VAD recording started successfully');
      _addLog('🎯 Speak normally to test speech detection');
      return true;
      
    } catch (e, stackTrace) {
      _addLog('❌ VAD start recording failed: $e');
      _addLog('❌ Stack trace: $stackTrace');
      _errorCount++;
      return false;
    }
  }
  
  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) {
      _addLog('⚠️ Not recording, nothing to stop');
      return;
    }
    
    try {
      _addLog('🛑 Stopping VAD recording...');
      await _vadHandler!.stopListening();
      _isRecording = false;
      _addLog('✅ VAD recording stopped');
      
    } catch (e, stackTrace) {
      _addLog('❌ VAD stop recording failed: $e');
      _addLog('❌ Stack trace: $stackTrace');
      _errorCount++;
    }
  }
  
  /// Get test summary
  Map<String, dynamic> getTestSummary() {
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'speechStartCount': _speechStartCount,
      'speechEndCount': _speechEndCount,
      'frameProcessedCount': _frameProcessedCount,
      'errorCount': _errorCount,
      'totalLogs': _testLogs.length,
    };
  }
  
  /// Clear test data
  void clearTestData() {
    _testLogs.clear();
    _speechStartCount = 0;
    _speechEndCount = 0;
    _frameProcessedCount = 0;
    _errorCount = 0;
    _addLog('🧹 Test data cleared');
  }
  
  /// Dispose of resources
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      await _vadHandler?.dispose();
      _addLog('🗑️ Audio test service disposed');
    } catch (e) {
      _addLog('❌ Dispose error: $e');
    }
  }
}
