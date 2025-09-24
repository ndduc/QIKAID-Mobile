import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<String> _errorController = 
      StreamController<String>.broadcast();
  StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  String? _sessionId;
  String? _cognitoId;
  String? _accessToken;
  String? _meetingTitle;
  
  // Store the access token and cognito ID for use in messages
  String? accessToken;
  String? cognitoId;
  
  // Keep-alive timer
  Timer? _keepAliveTimer;
  
  // Message buffering for split messages
  String _messageBuffer = '';
  bool _isReceivingPartialMessage = false;
  
  // Audio streaming state
  bool _isStreamingStarted = false;
  String? _currentUtteranceId;
  
  // Getters
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;
  
  /// Connect to the comprehend WebSocket service with retry logic
  Future<bool> connect({
    required String cognitoId,
    required String accessToken,
    String? sessionId,
    String? meetingTitle,
  }) async {
    _cognitoId = cognitoId;
    _accessToken = accessToken;
    _sessionId = sessionId ?? 'mobile-session-${DateTime.now().millisecondsSinceEpoch}';
    _meetingTitle = meetingTitle ?? 'Mobile Live Session';
    
    // Store for use in messages
    this.accessToken = accessToken;
    this.cognitoId = cognitoId;
    
    print('🔌 WEBSOCKET: Starting connection to comprehend service...');
    
    // Try connection with retry logic
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('🔌 WEBSOCKET: Connection attempt $attempt/3');
        
        final wsUrl = ApiConfig.getLiveSessionWebSocketUrl();
        print('🔌 WEBSOCKET: Connecting to: $wsUrl');
        
        // Connect to ngrok WebSocket with authentication
        final authenticatedUriString = '$wsUrl?access_token=${Uri.encodeComponent(accessToken)}&cognitoId=${Uri.encodeComponent(cognitoId)}&user_identifier=${Uri.encodeComponent('ndduc01@gmail.com')}&userIdForBinary=${Uri.encodeComponent('f798ed40-f850-41fd-9a65-4d787fa6a21d')}&profileIdForBinary=${Uri.encodeComponent('d479e65d-0f5a-4527-a473-203c9ce2062a')}';
        final authenticatedUri = Uri.parse(authenticatedUriString);
        
        print('🔌 WEBSOCKET: Connecting to ngrok WebSocket: $authenticatedUri');
        print('🔌 WEBSOCKET CONNECTION DETAILS:');
        print('   - Attempt: $attempt/3');
        print('   - URL: $authenticatedUri');
        
        // Create WebSocket with custom configuration for larger messages
        _channel = WebSocketChannel.connect(
          authenticatedUri,
          protocols: ['chat', 'superchat'],
        );
        
        // Listen for messages
        _channel!.stream.listen(
          _onMessage,
          onError: _onError,
          onDone: _onDisconnected,
        );
        
        // Wait for connection to be established
        await Future.delayed(Duration(milliseconds: 1500));
        
        // Check if connection is still active
        if (_channel != null && _channel!.closeCode == null) {
          _isConnected = true;
          _connectionController.add(true);
          print('✅ WEBSOCKET: Connected successfully on attempt $attempt');
          print('✅ WEBSOCKET CONNECTION ESTABLISHED:');
          print('   - WebSocket URL: $wsUrl');
          print('   - Channel Status: ACTIVE');
          print('   - Close Code: ${_channel!.closeCode}');
          print('   - Ready to send audio data!');
          
          // Start keep-alive mechanism
          _startKeepAlive();
          
          return true;
        } else {
          print('⚠️ WEBSOCKET: Connection attempt $attempt failed, retrying...');
          print('⚠️ WEBSOCKET FAILURE DETAILS:');
          print('   - Channel: ${_channel != null ? "EXISTS" : "NULL"}');
          print('   - Close Code: ${_channel?.closeCode}');
          await _cleanupChannel();
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 2000)); // Wait before retry
          }
        }
      } catch (e) {
        print('⚠️ WEBSOCKET: Connection attempt $attempt failed: $e');
        await _cleanupChannel();
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 2000)); // Wait before retry
        }
      }
    }
    
    print('❌ WEBSOCKET: All connection attempts failed');
    _errorController.add('Failed to connect after 3 attempts');
    return false;
  }
  
  /// Start audio streaming session
  Future<void> startAudioStreaming({
    String? languageCode,
    String? speakerName,
  }) async {
    if (!_isConnected || _channel == null) {
      print('❌ WEBSOCKET: Cannot start streaming - not connected');
      return;
    }
    
    if (_isStreamingStarted) {
      print('⚠️ WEBSOCKET: Streaming already started');
      return;
    }
    
    try {
      final startMessage = {
        'type': 'start',
        'encoding': 'LINEAR16',
        'sampleRateHz': 16000,
        'channels': 1,
        'languageCode': languageCode ?? 'en-US',
        'sessionId': _sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'cognitoId': cognitoId,
        'userIdentifier': 'ndduc01@gmail.com',
        'accessToken': accessToken,
      };
      
      print('🎤 WEBSOCKET: Starting audio streaming session');
      _channel!.sink.add(jsonEncode(startMessage));
      _isStreamingStarted = true;
      print('✅ WEBSOCKET: Audio streaming started');
      
    } catch (e) {
      print('❌ WEBSOCKET START STREAMING ERROR: $e');
      _errorController.add('Failed to start streaming: $e');
    }
  }
  
  /// Send PCM frame as binary data
  Future<void> sendPcmFrame(Uint8List pcmFrame) async {
    if (!_isConnected || _channel == null || !_isStreamingStarted) {
      return;
    }
    
    try {
      // Send as binary frame
      _channel!.sink.add(pcmFrame);
    } catch (e) {
      print('❌ WEBSOCKET PCM FRAME ERROR: $e');
    }
  }
  
  /// Send utterance start marker
  Future<void> sendUtteranceStart({
    required String utteranceId,
    required int totalBytes,
  }) async {
    if (!_isConnected || _channel == null) {
      return;
    }
    
    try {
      final message = {
        'type': 'utterance_start',
        'utteranceId': utteranceId,
        'contentType': 'audio/L16;rate=16000;channels=1',
        'totalBytes': totalBytes,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': _sessionId,
      };
      
      print('🎤 WEBSOCKET: Starting utterance $utteranceId ($totalBytes bytes)');
      _channel!.sink.add(jsonEncode(message));
      _currentUtteranceId = utteranceId;
      
    } catch (e) {
      print('❌ WEBSOCKET UTTERANCE START ERROR: $e');
    }
  }
  
  /// Send utterance end marker
  Future<void> sendUtteranceEnd() async {
    if (!_isConnected || _channel == null || _currentUtteranceId == null) {
      return;
    }
    
    try {
      final message = {
        'type': 'utterance_end',
        'utteranceId': _currentUtteranceId,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': _sessionId,
      };
      
      print('🎤 WEBSOCKET: Ending utterance $_currentUtteranceId');
      _channel!.sink.add(jsonEncode(message));
      _currentUtteranceId = null;
      
    } catch (e) {
      print('❌ WEBSOCKET UTTERANCE END ERROR: $e');
    }
  }
  
  /// Stop audio streaming session
  Future<void> stopAudioStreaming() async {
    if (!_isConnected || _channel == null || !_isStreamingStarted) {
      return;
    }
    
    try {
      final stopMessage = {
        'type': 'stop',
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': _sessionId,
      };
      
      print('🎤 WEBSOCKET: Stopping audio streaming session');
      _channel!.sink.add(jsonEncode(stopMessage));
      _isStreamingStarted = false;
      _currentUtteranceId = null;
      print('✅ WEBSOCKET: Audio streaming stopped');
      
    } catch (e) {
      print('❌ WEBSOCKET STOP STREAMING ERROR: $e');
    }
  }

  /// Send audio data to the WebSocket (legacy method - kept for compatibility)
  Future<void> sendAudioData({
    required Uint8List audioData,
    required String audioFormat,
    String? languageCode,
    String? speakerName,
  }) async {
    if (!_isConnected || _channel == null) {
      print('❌ WEBSOCKET: Cannot send audio - not connected');
      _errorController.add('Not connected to WebSocket');
      return;
    }
    
    try {
      final audioMessage = {
        'type': 'AUDIO_DATA',
        'audioId': 'audio-${DateTime.now().millisecondsSinceEpoch}',
        'audioData': base64Encode(audioData),
        'audioFormat': audioFormat,
        'sampleRate': '16000',
        'languageCode': languageCode ?? 'en-US',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'MOBILE',
        'sessionId': _sessionId,
        'speakerFLName': speakerName ?? '',
        'userId': 'f798ed40-f850-41fd-9a65-4d787fa6a21d',
        'meetingTitle': _meetingTitle,
        'selectedUserProfileId': "d479e65d-0f5a-4527-a473-203c9ce2062a",
        'cognitoId': cognitoId,
        'userIdentifier': 'ndduc01@gmail.com',
        'accessToken': accessToken,
        'origin': 'MOBILE',
      };
      
      print('🎤 WEBSOCKET: Sending audio data (${audioData.length} bytes)');
      print('📤 WEBSOCKET CALL DETAILS:');
      print('   - WebSocket URL: ${ApiConfig.getLiveSessionWebSocketUrl()}');
      print('   - Connection Status: ${_isConnected ? "CONNECTED" : "DISCONNECTED"}');
      print('   - Channel Status: ${_channel != null ? "ACTIVE" : "NULL"}');
      print('   - Message Type: AUDIO_DATA');
      print('   - Audio ID: ${audioMessage['audioId']}');
      print('   - Audio Format: ${audioMessage['audioFormat']}');
      print('   - Sample Rate: ${audioMessage['sampleRate']}');
      print('   - Language: ${audioMessage['languageCode']}');
      print('   - Session ID: ${audioMessage['sessionId']}');
      print('   - Data Size: ${audioData.length} bytes');
      print('   - Base64 Length: ${base64Encode(audioData).length} characters');
      print('   - Timestamp: ${audioMessage['timestamp']}');
      print('📤 WEBSOCKET: Raw JSON being sent:');
      print('   ${jsonEncode(audioMessage)}');
      
      _channel!.sink.add(jsonEncode(audioMessage));
      print('✅ WEBSOCKET: Audio data sent successfully!');
      
    } catch (e) {
      print('❌ WEBSOCKET SEND ERROR: $e');
      _errorController.add('Failed to send audio: $e');
    }
  }
  
  /// Send text message to the WebSocket
  Future<void> sendTextMessage({
    required String text,
    String? speakerName,
  }) async {
    if (!_isConnected || _channel == null) {
      print('❌ WEBSOCKET: Cannot send text - not connected');
      _errorController.add('Not connected to WebSocket');
      return;
    }
    
    try {
      final textMessage = {
        'type': 'TRANSCRIPT_TEXT',
        'transcriptId': 'text-${DateTime.now().millisecondsSinceEpoch}',
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'MOBILE',
        'sessionId': _sessionId,
        'speakerFLName': speakerName ?? '',
        'userId': 'f798ed40-f850-41fd-9a65-4d787fa6a21d',
        'meetingTitle': _meetingTitle,
        'selectedUserProfileId': cognitoId,
        'cognitoId': cognitoId,
        'userIdentifier': 'ndduc01@gmail.com',
        'accessToken': accessToken,
        'origin': 'MOBILE',
      };
      
      print('📝 WEBSOCKET: Sending text message: "$text"');
      print('📤 WEBSOCKET CALL DETAILS:');
      print('   - WebSocket URL: ${ApiConfig.getLiveSessionWebSocketUrl()}');
      print('   - Connection Status: ${_isConnected ? "CONNECTED" : "DISCONNECTED"}');
      print('   - Channel Status: ${_channel != null ? "ACTIVE" : "NULL"}');
      print('   - Message Type: TRANSCRIPT_TEXT');
      print('   - Transcript ID: ${textMessage['transcriptId']}');
      print('   - Text: "$text"');
      print('   - Session ID: ${textMessage['sessionId']}');
      print('   - Timestamp: ${textMessage['timestamp']}');
      print('📤 WEBSOCKET: Raw JSON being sent:');
      print('   ${jsonEncode(textMessage)}');
      
      _channel!.sink.add(jsonEncode(textMessage));
      print('✅ WEBSOCKET: Text message sent successfully!');
      
    } catch (e) {
      print('❌ WEBSOCKET SEND ERROR: $e');
      _errorController.add('Failed to send text: $e');
    }
  }
  
  /// Handle incoming messages with chunking support
  void _onMessage(dynamic message) {
    try {
      print('📨 WEBSOCKET: Received message (${message.toString().length} chars)');
      
      // Mark as connected when we receive the first message
      if (!_isConnected) {
        _isConnected = true;
        _connectionController.add(true);
        print('✅ WEBSOCKET: Connection established (first message received)');
      }
      
      // Handle message chunking
      String messageStr = message.toString();
      
      // Check if this is a partial message (doesn't end with } or ])
      if (!messageStr.trim().endsWith('}') && !messageStr.trim().endsWith(']')) {
        print('📨 WEBSOCKET: Received partial message, buffering...');
        _messageBuffer += messageStr;
        _isReceivingPartialMessage = true;
        return;
      }
      
      // If we were receiving a partial message, combine with buffer
      if (_isReceivingPartialMessage) {
        print('📨 WEBSOCKET: Completing buffered message...');
        messageStr = _messageBuffer + messageStr;
        _messageBuffer = '';
        _isReceivingPartialMessage = false;
      }
      
      print('📨 WEBSOCKET: Processing complete message (${messageStr.length} chars)');
      
      final Map<String, dynamic> data = jsonDecode(messageStr);
      print('📨 WEBSOCKET: Message type: ${data['type']}');
      
      // Handle different message types
      switch (data['type']) {
        case 'TRANSCRIPTION_RESULT':
          print('🎤 WEBSOCKET: Transcription result: "${data['text']}"');
          break;
        case 'CLASSIFICATION_RESULT':
          print('🧠 WEBSOCKET: Classification result received');
          break;
        case 'ERROR':
          print('❌ WEBSOCKET: Server error: ${data['error']}');
          _errorController.add('Server error: ${data['error']}');
          break;
        default:
          print('📨 WEBSOCKET: Unknown message type: ${data['type']}');
      }
      
      _messageController.add(data);
      
    } catch (e) {
      print('❌ WEBSOCKET MESSAGE PARSE ERROR: $e');
      print('❌ WEBSOCKET: Raw message: ${message.toString()}');
      _errorController.add('Failed to parse message: $e');
      
      // Reset buffer on error
      _messageBuffer = '';
      _isReceivingPartialMessage = false;
    }
  }
  
  /// Clean up WebSocket channel
  Future<void> _cleanupChannel() async {
    try {
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
      }
      _isConnected = false;
    } catch (e) {
      print('⚠️ WEBSOCKET: Cleanup error: $e');
    }
  }

  /// Handle WebSocket errors
  void _onError(error) {
    print('❌ WEBSOCKET ERROR: $error');
    _isConnected = false;
    _connectionController.add(false);
    
    // Only show error to user if we're not in retry mode
    // This prevents showing temporary connection errors during retry attempts
    if (_channel == null || _channel!.closeCode != null) {
      _errorController.add('WebSocket error: $error');
    }
  }
  
  /// Handle WebSocket disconnection
  void _onDisconnected() {
    print('🔌 WEBSOCKET: Disconnected');
    _isConnected = false;
    _connectionController.add(false);
  }
  
  /// Start keep-alive mechanism
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          // Send ping message to keep connection alive
          final pingMessage = {
            'type': 'PING',
            'timestamp': DateTime.now().toIso8601String(),
            'sessionId': _sessionId,
          };
          _channel!.sink.add(jsonEncode(pingMessage));
          print('🏓 WEBSOCKET: Sent keep-alive ping');
        } catch (e) {
          print('❌ WEBSOCKET KEEP-ALIVE ERROR: $e');
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
    print('🏓 WEBSOCKET: Keep-alive mechanism started');
  }
  
  /// Stop keep-alive mechanism
  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    print('🏓 WEBSOCKET: Keep-alive mechanism stopped');
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      print('🔌 WEBSOCKET: Disconnecting...');
      
      // Stop audio streaming first
      if (_isStreamingStarted) {
        await stopAudioStreaming();
      }
      
      // Stop keep-alive
      _stopKeepAlive();
      
      if (_channel != null) {
        await _channel!.sink.close(status.goingAway);
        _channel = null;
      }
      
      _isConnected = false;
      _isStreamingStarted = false;
      _currentUtteranceId = null;
      _connectionController.add(false);
      
      print('✅ WEBSOCKET: Disconnected successfully');
    } catch (e) {
      print('❌ WEBSOCKET DISCONNECT ERROR: $e');
    }
  }
  
  /// Dispose of resources
  Future<void> dispose() async {
    try {
      _stopKeepAlive();
      await disconnect();
      await _messageController.close();
      await _errorController.close();
      await _connectionController.close();
      print('🗑️ WEBSOCKET: Service disposed');
    } catch (e) {
      print('❌ WEBSOCKET DISPOSE ERROR: $e');
    }
  }
}
