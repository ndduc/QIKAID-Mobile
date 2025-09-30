class ApiConfig {
  // Development server configurations
  static const String _androidEmulatorAuth = 'http://10.0.2.2:8081'; // Android emulator auth
  static const String _localSimulatorAuth = 'http://192.168.50.1:8081'; // iOS simulator auth
  static const String _networkIPAuth = 'https://api.qikaid.com'; // Production auth
  
  // WebSocket configurations for comprehend service
  static const String _androidEmulatorWS = 'ws://10.0.2.2:8080'; // Android emulator WebSocket
  static const String _localSimulatorWS = 'ws://192.168.50.1:8080'; // iOS simulator WebSocket
  static const String _networkIPWS = 'wss://api.qikaid.com/comprehend/ws/transcript'; // Production WebSocket
  static const String _ngrokWS = 'wss://7ff93a3b1224.ngrok-free.app/comprehend/ws/transcript'; // Ngrok WebSocket

  // Current configuration - change this based on your setup
  static const String authBaseUrl = _networkIPAuth; // Default to production auth
  static const String wsBaseUrl = _ngrokWS; // Default to ngrok WebSocket
  
  // Helper method to get the current auth base URL
  static String getAuthBaseUrl() {
    return authBaseUrl;
  }
  
  // Helper method to get the current WebSocket base URL
  static String getWebSocketBaseUrl() {
    return wsBaseUrl;
  }
  
  // Helper method to check if we're using localhost
  static bool isLocalhost() {
    return authBaseUrl.contains('localhost') || authBaseUrl.contains('127.0.0.1') ||
           wsBaseUrl.contains('localhost') || wsBaseUrl.contains('127.0.0.1');
  }
  
  // Helper method to get WebSocket URL for live sessions
  static String getLiveSessionWebSocketUrl() {
    return wsBaseUrl;
  }
}
