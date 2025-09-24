class SessionConfig {
  // Live session configuration
  static const bool enableLiveSession = true;
  static const bool disableSpeechToTextInLiveSession = true;
  
  // WebSocket configuration
  static const int audioChunkDurationMs = 1000; // Send audio chunks every 1 second
  static const String defaultAudioFormat = 'wav';
  static const int defaultSampleRate = 16000;
  static const String defaultLanguageCode = 'en-US';
  
  // Audio recording configuration
  static const int maxRecordingDurationMinutes = 30;
  static const bool enableAudioCompression = true;
  static const int audioBitRate = 128000;
  
  // WebSocket connection configuration
  static const int connectionTimeoutSeconds = 10;
  static const int reconnectAttempts = 3;
  static const int reconnectDelaySeconds = 2;
  
  // Feature flags
  static const bool enableManualTextInput = true;
  static const bool enableAudioVisualization = false;
  static const bool enableRealTimeTranscription = true;
  static const bool enableTranslation = true;
  
  // Development settings
  static const bool enableDebugLogging = true;
  static const bool useSimulatedAudio = true; // Set to true for testing without microphone
  
  /// Check if speech-to-text should be disabled for live sessions
  static bool shouldDisableSpeechToText() {
    return disableSpeechToTextInLiveSession;
  }
  
  /// Check if live session is enabled
  static bool isLiveSessionEnabled() {
    return enableLiveSession;
  }
  
  /// Get audio configuration for live sessions
  static Map<String, dynamic> getAudioConfig() {
    return {
      'chunkDurationMs': audioChunkDurationMs,
      'format': defaultAudioFormat,
      'sampleRate': defaultSampleRate,
      'languageCode': defaultLanguageCode,
      'bitRate': audioBitRate,
      'maxDurationMinutes': maxRecordingDurationMinutes,
      'compression': enableAudioCompression,
    };
  }
  
  /// Get WebSocket configuration
  static Map<String, dynamic> getWebSocketConfig() {
    return {
      'connectionTimeoutSeconds': connectionTimeoutSeconds,
      'reconnectAttempts': reconnectAttempts,
      'reconnectDelaySeconds': reconnectDelaySeconds,
    };
  }
  
  /// Get feature flags
  static Map<String, bool> getFeatureFlags() {
    return {
      'enableManualTextInput': enableManualTextInput,
      'enableAudioVisualization': enableAudioVisualization,
      'enableRealTimeTranscription': enableRealTimeTranscription,
      'enableTranslation': enableTranslation,
      'enableDebugLogging': enableDebugLogging,
      'useSimulatedAudio': useSimulatedAudio,
    };
  }
}
