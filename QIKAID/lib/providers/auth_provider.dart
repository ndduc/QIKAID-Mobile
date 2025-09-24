import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkInitialAuthState();
  }

  // Check initial authentication state on app start
  Future<void> _checkInitialAuthState() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final isAuthenticated = await _authService.isAuthenticated();
      final user = await _authService.getStoredUser();
      final token = await _authService.getStoredToken();
      final isOnline = await _authService.isOnline();
      
      state = state.copyWith(
        isAuthenticated: isAuthenticated,
        user: user,
        accessToken: token,
        isLoading: false,
        isOfflineMode: !isOnline,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check authentication state: $e',
      );
    }
  }

  // Sign up method
  Future<void> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.signUp(email, password);
      
      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Sign up failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign up error: $e',
      );
    }
  }

  // Forgot password method
  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.forgotPassword(email);
      print('DEBUG: Forgot password response: success=${response.success}, message=${response.message}');
      
      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        print('DEBUG: Forgot password state updated to success');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Forgot password request failed',
        );
        print('DEBUG: Forgot password state updated to error: ${response.message}');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Forgot password error: $e',
      );
      print('DEBUG: Forgot password exception: $e');
    }
  }

  // Confirm forgot password method
  Future<void> confirmForgotPassword(
    String email,
    String confirmationCode,
    String newPassword,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.confirmForgotPassword(
        email,
        confirmationCode,
        newPassword,
      );
      
      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Confirm forgot password failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Confirm forgot password error: $e',
      );
    }
  }

  // Login method
  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.login(username, password);
      
      if (response.success) {
        final user = await _authService.getStoredUser();
        final token = await _authService.getStoredToken();
        final isOnline = await _authService.isOnline();
        
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          accessToken: token,
          isLoading: false,
          isOfflineMode: !isOnline,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message ?? 'Login failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login error: $e',
      );
    }
  }

  // Logout method
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.logout();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Logout error: $e',
      );
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Refresh authentication state
  Future<void> refreshAuthState() async {
    await _checkInitialAuthState();
  }
}

// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});

final isOfflineModeProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isOfflineMode;
});
