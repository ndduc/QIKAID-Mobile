import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/auth_models.dart';
import '../config/api_config.dart';

class AuthService {
  static String get _baseUrl => ApiConfig.getAuthBaseUrl();
  static const String _userKey = 'user_data';
  static const String _offlineAuthKey = 'offline_auth';

  // Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Sign up with API
  Future<SignUpResponse> signUp(String email, String password) async {
    try {
      final isOnline = await this.isOnline();
      
      if (!isOnline) {
        return const SignUpResponse(
          success: false,
          message: 'Sign up requires internet connection',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/users/create'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(SignUpRequest(
          email: email,
          password: password,
        ).toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final signUpResponse = SignUpResponse.fromJson(jsonDecode(response.body));
        return signUpResponse;
      } else {
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          return SignUpResponse(
            success: false,
            message: errorData['message'] ?? 'Sign up failed',
          );
        } catch (e) {
          return SignUpResponse(
            success: false,
            message: 'Sign up failed: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      return SignUpResponse(
        success: false,
        message: 'Sign up error: $e',
      );
    }
  }

  // Forgot password with API
  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    try {
      final isOnline = await this.isOnline();
      
      if (!isOnline) {
        return const ForgotPasswordResponse(
          success: false,
          message: 'Forgot password requires internet connection',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/users/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:3000',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
        body: jsonEncode(ForgotPasswordRequest(
          email: email,
        ).toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseBody = jsonDecode(response.body);
          final forgotPasswordResponse = ForgotPasswordResponse.fromJson(responseBody);
          return forgotPasswordResponse;
        } catch (e) {
          // If response body doesn't match expected format, assume success
          print('DEBUG: API returned 200 but response format unexpected: $e');
          return const ForgotPasswordResponse(
            success: true,
            message: 'Password reset email sent successfully',
          );
        }
      } else {
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          return ForgotPasswordResponse(
            success: false,
            message: errorData['message'] ?? 'Forgot password request failed',
          );
        } catch (e) {
          return ForgotPasswordResponse(
            success: false,
            message: 'Forgot password request failed: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      return ForgotPasswordResponse(
        success: false,
        message: 'Forgot password error: $e',
      );
    }
  }

  // Confirm forgot password with API
  Future<ConfirmForgotPasswordResponse> confirmForgotPassword(
    String email,
    String confirmationCode,
    String newPassword,
  ) async {
    try {
      final isOnline = await this.isOnline();
      
      if (!isOnline) {
        return const ConfirmForgotPasswordResponse(
          success: false,
          message: 'Confirm forgot password requires internet connection',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/users/confirm-forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:3000',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
        body: jsonEncode(ConfirmForgotPasswordRequest(
          email: email,
          confirmationCode: confirmationCode,
          newPassword: newPassword,
        ).toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final confirmResponse = ConfirmForgotPasswordResponse.fromJson(jsonDecode(response.body));
        return confirmResponse;
      } else {
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          return ConfirmForgotPasswordResponse(
            success: false,
            message: errorData['message'] ?? 'Confirm forgot password failed',
          );
        } catch (e) {
          return ConfirmForgotPasswordResponse(
            success: false,
            message: 'Confirm forgot password failed: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      return ConfirmForgotPasswordResponse(
        success: false,
        message: 'Confirm forgot password error: $e',
      );
    }
  }

  // Login with API
  Future<LoginResponse> login(String username, String password) async {
    try {
      final isOnline = await this.isOnline();
      
      if (!isOnline) {
        // Try offline authentication
        return await _authenticateOffline(username, password);
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/token'),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
        body: jsonEncode(LoginRequest(
          username: username,
          password: password,
        ).toJson()),
      );

      if (response.statusCode == 200) {
        print('DEBUG: Login API Response Body: ${response.body}');
        final responseData = jsonDecode(response.body);
        print('DEBUG: Parsed JSON: $responseData');
        final loginResponse = LoginResponse.fromJson(responseData);
        print('DEBUG: LoginResponse - userId: ${loginResponse.userId}, cognitoId: ${loginResponse.cognitoId}');
        print('DEBUG: LoginResponse - accessToken: ${loginResponse.accessToken?.substring(0, 20)}...');
        print('DEBUG: LoginResponse - idToken: ${loginResponse.idToken?.substring(0, 20)}...');
        print('DEBUG: LoginResponse - refreshToken: ${loginResponse.refreshToken?.substring(0, 20)}...');
        
        if (loginResponse.success && loginResponse.accessToken != null) {
          // Store authentication data for offline use
          await _storeAuthData(loginResponse, username);
        }
        
        return loginResponse;
      } else {
        // If API fails, try offline authentication
        return await _authenticateOffline(username, password);
      }
    } catch (e) {
      // If network error, try offline authentication
      return await _authenticateOffline(username, password);
    }
  }

  // Offline authentication
  Future<LoginResponse> _authenticateOffline(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedAuth = prefs.getString(_offlineAuthKey);
      
      if (storedAuth != null) {
        final authData = jsonDecode(storedAuth);
        final storedUsername = authData['username'] as String;
        final storedPassword = authData['password'] as String;
        
        if (storedUsername == username && storedPassword == password) {
          // Valid offline authentication
          return const LoginResponse(
            success: true,
            message: 'Authenticated offline',
          );
        }
      }
      
      return const LoginResponse(
        success: false,
        message: 'Invalid credentials or no offline authentication available',
      );
    } catch (e) {
      return const LoginResponse(
        success: false,
        message: 'Offline authentication failed',
      );
    }
  }

  // Store authentication data
  Future<void> _storeAuthData(LoginResponse response, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store all tokens
      if (response.accessToken != null) {
        await prefs.setString('access_token', response.accessToken!);
      }
      if (response.idToken != null) {
        await prefs.setString('id_token', response.idToken!);
      }
      if (response.refreshToken != null) {
        await prefs.setString('refresh_token', response.refreshToken!);
      }
      if (response.tokenType != null) {
        await prefs.setString('token_type', response.tokenType!);
      }
      if (response.expiresIn != null) {
        await prefs.setInt('expires_in', response.expiresIn!);
      }
      if (response.userId != null) {
        await prefs.setString('user_id', response.userId!);
      }
      if (response.cognitoId != null) {
        await prefs.setString('cognito_id', response.cognitoId!);
      }
      
      // Store user data with all token information
      final user = User.fromLoginResponse(response, username);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      
      // Store offline authentication data
      await prefs.setString(_offlineAuthKey, jsonEncode({
        'username': username,
        'password': 'stored_for_offline', // In production, you'd hash this
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
      
      print('DEBUG: Auth data stored successfully for user: $username');
    } catch (e) {
      // Handle storage error
      print('ERROR: Failed to store auth data: $e');
    }
  }

  // Get stored access token
  Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      return null;
    }
  }

  // Get stored refresh token
  Future<String?> getStoredRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('refresh_token');
    } catch (e) {
      return null;
    }
  }

  // Get stored ID token
  Future<String?> getStoredIdToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('id_token');
    } catch (e) {
      return null;
    }
  }

  // Get stored user
  Future<User?> getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      
      if (userData != null) {
        return User.fromJson(jsonDecode(userData));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if user is authenticated (online or offline)
  Future<bool> isAuthenticated() async {
    try {
      final token = await getStoredToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('id_token');
      await prefs.remove('refresh_token');
      await prefs.remove('token_type');
      await prefs.remove('expires_in');
      await prefs.remove('user_id');
      await prefs.remove('cognito_id');
      await prefs.remove(_userKey);
      await prefs.remove(_offlineAuthKey);
      print('DEBUG: User logged out successfully');
    } catch (e) {
      print('ERROR: Failed to logout: $e');
    }
  }

  // Validate stored credentials for offline mode
  Future<bool> validateOfflineCredentials(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedAuth = prefs.getString(_offlineAuthKey);
      
      if (storedAuth != null) {
        final authData = jsonDecode(storedAuth);
        final storedUsername = authData['username'] as String;
        final storedPassword = authData['password'] as String;
        
        return storedUsername == username && storedPassword == password;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
