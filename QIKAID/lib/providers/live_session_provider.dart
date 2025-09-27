import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../services/audio_recording_service_v2.dart';

/// Live session state
class LiveSessionState {
  final bool isConnected;
  final bool isRecording;
  final bool isInitialized;
  final String? currentText;
  final String? error;
  final String? sessionId;
  final String? cognitoId;
  
  const LiveSessionState({
    this.isConnected = false,
    this.isRecording = false,
    this.isInitialized = false,
    this.currentText,
    this.error,
    this.sessionId,
    this.cognitoId,
  });
  
  LiveSessionState copyWith({
    bool? isConnected,
    bool? isRecording,
    bool? isInitialized,
    String? currentText,
    String? error,
    String? sessionId,
    String? cognitoId,
  }) {
    return LiveSessionState(
      isConnected: isConnected ?? this.isConnected,
      isRecording: isRecording ?? this.isRecording,
      isInitialized: isInitialized ?? this.isInitialized,
      currentText: currentText ?? this.currentText,
      error: error ?? this.error,
      sessionId: sessionId ?? this.sessionId,
      cognitoId: cognitoId ?? this.cognitoId,
    );
  }
}

/// Live session notifier
class LiveSessionNotifier extends StateNotifier<LiveSessionState> {
  final WebSocketService _webSocketService;
  final AudioRecordingService _audioRecordingService;
  
  StreamSubscription? _wsMessageSubscription;
  StreamSubscription? _wsErrorSubscription;
  StreamSubscription? _wsConnectionSubscription;
  StreamSubscription? _audioDataSubscription;
  StreamSubscription? _liveFrameSubscription;
  StreamSubscription? _audioStateSubscription;
  
  LiveSessionNotifier(
    this._webSocketService,
    this._audioRecordingService,
  ) : super(const LiveSessionState()) {
    _initializeServices();
  }
  
  /// Initialize services and set up listeners
  Future<void> _initializeServices() async {
    try {
      print('🎯 LIVE SESSION: Initializing live session services...');
      
      // Initialize audio recording service
      try {
        await _audioRecordingService.initialize();
        print('✅ LIVE SESSION: Audio recording service initialized');
      } catch (e) {
        print('❌ LIVE SESSION: Audio initialization failed: $e');
        state = state.copyWith(
          error: 'Failed to initialize audio recording service: $e',
        );
        return;
      }
      
      // Set up WebSocket listeners
      _wsMessageSubscription = _webSocketService.messageStream.listen(_onWebSocketMessage);
      _wsErrorSubscription = _webSocketService.errorStream.listen(_onWebSocketError);
      _wsConnectionSubscription = _webSocketService.connectionStream.listen(_onWebSocketConnection);
      
      // Set up audio recording listeners
      // Dual-lane audio streaming: utterances + live frames
      _audioDataSubscription = _audioRecordingService.utteranceStream.listen(_onUtteranceData);
      _audioStateSubscription = _audioRecordingService.stateStream.listen(_onAudioState);
      
      state = state.copyWith(isInitialized: true);
      
      print('✅ LIVE SESSION: Services initialized successfully');
    } catch (e) {
      print('❌ LIVE SESSION INIT ERROR: $e');
      state = state.copyWith(error: 'Initialization failed: $e');
    }
  }
  
  /// Connect to live session
  Future<bool> connect({
    required String cognitoId,
    required String accessToken,
    String? sessionId,
    String? meetingTitle,
  }) async {
    try {
      print('🎯 LIVE SESSION: Connecting to live session...');
      
      state = state.copyWith(
        cognitoId: cognitoId,
        sessionId: sessionId,
        error: null,
      );
      
      // Connect to WebSocket
      final connected = await _webSocketService.connect(
        cognitoId: cognitoId,
        accessToken: accessToken,
        sessionId: sessionId,
        meetingTitle: meetingTitle,
      );
      
      if (connected) {
        print('✅ LIVE SESSION: Connected successfully');
        return true;
      } else {
        print('❌ LIVE SESSION: Failed to connect');
        state = state.copyWith(error: 'Failed to connect to live session');
        return false;
      }
    } catch (e) {
      print('❌ LIVE SESSION CONNECT ERROR: $e');
      state = state.copyWith(error: 'Connection failed: $e');
      return false;
    }
  }
  
  /// Start live session (start recording and sending audio)
  Future<bool> startSession() async {
    try {
      print('🎯 LIVE SESSION: Starting live session...');
      
      // Start audio streaming session if connected
      if (state.isConnected) {
        await _webSocketService.startAudioStreaming(
          languageCode: 'en-US',
          speakerName: 'User',
        );
      } else {
        print('⚠️ LIVE SESSION: Starting in offline mode (no WebSocket connection)');
        print('🎤 LIVE SESSION: This is for testing microphone functionality only');
      }
      
      // Start audio recording
      await _audioRecordingService.startRecording();
      
      // Subscribe to live frame stream only (utterance stream already subscribed in _initializeServices)
      _liveFrameSubscription = _audioRecordingService.liveFrameStream.listen(_onLiveFrameData);
      
      state = state.copyWith(isRecording: true, error: null);
      print('✅ LIVE SESSION: Live session started successfully');
      print('🎤 LIVE SESSION: Dual-lane audio streaming active');
      print('   - Lane 1: Live frames (20ms) for real-time captions');
      print('   - Lane 2: VAD utterances for complete sentences');
      return true;
    } catch (e) {
      print('❌ LIVE SESSION START ERROR: $e');
      state = state.copyWith(error: 'Failed to start live session: $e');
      return false;
    }
  }
  
  /// Stop live session
  Future<void> stopSession() async {
    try {
      print('🎯 LIVE SESSION: Stopping live session...');
      
      // Cancel subscriptions
      _audioDataSubscription?.cancel();
      _liveFrameSubscription?.cancel();
      
      // Stop audio streaming session if connected
      if (state.isConnected) {
        await _webSocketService.stopAudioStreaming();
      }
      
      // Stop audio recording
      await _audioRecordingService.stopRecording();
      
      state = state.copyWith(
        isRecording: false,
        currentText: null,
        error: null,
      );
      
      print('✅ LIVE SESSION: Live session stopped successfully');
    } catch (e) {
      print('❌ LIVE SESSION STOP ERROR: $e');
      state = state.copyWith(error: 'Failed to stop live session: $e');
    }
  }
  
  /// Disconnect from live session
  Future<void> disconnect() async {
    try {
      print('🎯 LIVE SESSION: Disconnecting from live session...');
      
      // Stop session if running
      if (state.isRecording) {
        await stopSession();
      }
      
      // Disconnect WebSocket
      await _webSocketService.disconnect();
      
      state = state.copyWith(
        isConnected: false,
        isRecording: false,
        currentText: null,
        error: null,
      );
      
      print('✅ LIVE SESSION: Disconnected successfully');
    } catch (e) {
      print('❌ LIVE SESSION DISCONNECT ERROR: $e');
      state = state.copyWith(error: 'Failed to disconnect: $e');
    }
  }
  
  /// Send text message manually
  Future<void> sendTextMessage(String text) async {
    try {
      print('🎯 LIVE SESSION: Sending text message: "$text"');
      
      await _webSocketService.sendTextMessage(text: text);
      
    } catch (e) {
      print('❌ LIVE SESSION SEND TEXT ERROR: $e');
      state = state.copyWith(error: 'Failed to send text: $e');
    }
  }
  
  /// Handle WebSocket messages
  void _onWebSocketMessage(Map<String, dynamic> message) {
    try {
      print('🎯 LIVE SESSION: Received WebSocket message: ${message['type']}');
      
      switch (message['type']) {
        case 'TRANSCRIPTION_RESULT':
          final text = message['text'] as String?;
          if (text != null && text.isNotEmpty) {
            state = state.copyWith(currentText: text, error: null);
            print('🎯 LIVE SESSION: Updated text: "$text"');
          }
          break;
        case 'CLASSIFICATION_RESULT':
          print('🎯 LIVE SESSION: Classification result received');
          break;
        case 'ERROR':
          final error = message['error'] as String?;
          state = state.copyWith(error: error);
          break;
      }
    } catch (e) {
      print('❌ LIVE SESSION MESSAGE HANDLER ERROR: $e');
    }
  }
  
  /// Handle WebSocket errors
  void _onWebSocketError(String error) {
    print('❌ LIVE SESSION: WebSocket error: $error');
    state = state.copyWith(error: error);
  }
  
  /// Handle WebSocket connection changes
  void _onWebSocketConnection(bool isConnected) {
    print('🎯 LIVE SESSION: WebSocket connection: $isConnected');
    state = state.copyWith(isConnected: isConnected);
  }
  
  /// Handle utterance data (complete sentences)
  void _onUtteranceData(Uint8List audioData) {
    try {
      print('🎯 LIVE SESSION: Processing utterance data (${audioData.length} bytes)');
      
      // Only send to WebSocket if connected
      if (state.isConnected) {
        // Send utterance start marker
        final utteranceId = 'utt-${DateTime.now().millisecondsSinceEpoch}';
        _webSocketService.sendUtteranceStart(
          utteranceId: utteranceId,
          totalBytes: audioData.length,
        );
        
        // Send utterance data in chunks
        _sendUtteranceInChunks(audioData);
        
        // Send utterance end marker
        _webSocketService.sendUtteranceEnd();
        
        print('📤 LIVE SESSION: Utterance sent to WebSocket');
      } else {
        print('🎤 LIVE SESSION: Utterance captured (offline mode - not sending to WebSocket)');
        print('🎤 LIVE SESSION: Audio amplitude: ${_calculateAudioAmplitude(audioData).toStringAsFixed(4)}');
      }
      
    } catch (e) {
      print('❌ LIVE SESSION UTTERANCE HANDLER ERROR: $e');
    }
  }
  
  /// Handle live frame data (20ms frames for real-time captions)
  void _onLiveFrameData(Uint8List frameData) {
    try {
      if (state.isConnected) {
        _webSocketService.sendPcmFrame(frameData);
      }
    } catch (e) {
      print('❌ LIVE SESSION LIVE FRAME ERROR: $e');
    }
  }
  
  /// Send utterance data in chunks
  void _sendUtteranceInChunks(Uint8List audioData) {
    const chunkSize = 16 * 1024; // 16KB chunks
    
    for (var i = 0; i < audioData.length; i += chunkSize) {
      final end = (i + chunkSize > audioData.length) ? audioData.length : i + chunkSize;
      final chunk = Uint8List.sublistView(audioData, i, end);
      _webSocketService.sendPcmFrame(chunk);
    }
  }
  
  /// Calculate audio amplitude for debugging
  double _calculateAudioAmplitude(Uint8List audioData) {
    double sum = 0;
    for (int i = 0; i < audioData.length; i += 2) {
      final sample = (audioData[i] | (audioData[i + 1] << 8));
      final amplitude = (sample - 32768) / 32768.0;
      sum += amplitude.abs();
    }
    return sum / (audioData.length / 2);
  }
  
  /// Handle audio state changes
  void _onAudioState(RecordingState audioState) {
    try {
      print('🎯 LIVE SESSION: Audio state changed');
      
      if (audioState.hasError) {
        state = state.copyWith(error: audioState.error);
      }
      
    } catch (e) {
      print('❌ LIVE SESSION AUDIO STATE HANDLER ERROR: $e');
    }
  }
  
  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsErrorSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _audioDataSubscription?.cancel();
    _liveFrameSubscription?.cancel();
    _audioStateSubscription?.cancel();
    
    _webSocketService.dispose();
    _audioRecordingService.dispose();
    
    super.dispose();
  }
}

/// Live session service provider
final liveSessionServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Audio recording service provider
final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Live session notifier provider
final liveSessionNotifierProvider = StateNotifierProvider<LiveSessionNotifier, LiveSessionState>((ref) {
  final webSocketService = ref.watch(liveSessionServiceProvider);
  final audioRecordingService = ref.watch(audioRecordingServiceProvider);
  return LiveSessionNotifier(webSocketService, audioRecordingService);
});

/// Live session state provider (for UI)
final liveSessionStateProvider = StateProvider<LiveSessionState>((ref) {
  return ref.watch(liveSessionNotifierProvider);
});


