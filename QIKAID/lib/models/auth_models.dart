import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class LoginResponse {
  @JsonKey(name: 'userId')
  final String? userId;
  
  @JsonKey(name: 'cognitoId')
  final String? cognitoId;
  
  @JsonKey(name: 'access_token')
  final String? accessToken;
  
  @JsonKey(name: 'id_token')
  final String? idToken;
  
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  
  @JsonKey(name: 'token_type')
  final String? tokenType;
  
  @JsonKey(name: 'expires_in')
  final int? expiresIn;
  
  final String? message;
  final bool success;

  const LoginResponse({
    this.userId,
    this.cognitoId,
    this.accessToken,
    this.idToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
    this.message,
    this.success = true, // Default to true if not provided
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

@JsonSerializable()
class User {
  final String id;
  final String email;
  final String? name;
  final String? avatar;
  final String? cognitoId;
  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
    this.cognitoId,
    this.accessToken,
    this.idToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Create User from LoginResponse
  factory User.fromLoginResponse(LoginResponse response, String email) {
    return User(
      id: response.userId ?? '',
      email: email,
      cognitoId: response.cognitoId,
      accessToken: response.accessToken,
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      tokenType: response.tokenType,
      expiresIn: response.expiresIn,
    );
  }
}

@JsonSerializable()
class SignUpRequest {
  final String email;
  final String password;

  const SignUpRequest({
    required this.email,
    required this.password,
  });

  factory SignUpRequest.fromJson(Map<String, dynamic> json) =>
      _$SignUpRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SignUpRequestToJson(this);
}

@JsonSerializable()
class SignUpResponse {
  final String? message;
  final bool success;
  final String? userId;
  final String? email;

  const SignUpResponse({
    this.message,
    required this.success,
    this.userId,
    this.email,
  });

  factory SignUpResponse.fromJson(Map<String, dynamic> json) =>
      _$SignUpResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SignUpResponseToJson(this);
}

@JsonSerializable()
class ForgotPasswordRequest {
  final String email;

  const ForgotPasswordRequest({
    required this.email,
  });

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}

@JsonSerializable()
class ForgotPasswordResponse {
  final String? message;
  final bool success;
  final String? email;

  const ForgotPasswordResponse({
    this.message,
    required this.success,
    this.email,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ForgotPasswordResponseToJson(this);
}

@JsonSerializable()
class ConfirmForgotPasswordRequest {
  final String email;
  final String confirmationCode;
  final String newPassword;

  const ConfirmForgotPasswordRequest({
    required this.email,
    required this.confirmationCode,
    required this.newPassword,
  });

  factory ConfirmForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ConfirmForgotPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ConfirmForgotPasswordRequestToJson(this);
}

@JsonSerializable()
class ConfirmForgotPasswordResponse {
  final String? message;
  final bool success;

  const ConfirmForgotPasswordResponse({
    this.message,
    required this.success,
  });

  factory ConfirmForgotPasswordResponse.fromJson(Map<String, dynamic> json) =>
      _$ConfirmForgotPasswordResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ConfirmForgotPasswordResponseToJson(this);
}

@JsonSerializable()
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final User? user;
  final String? accessToken;
  final bool isOfflineMode;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
    this.accessToken,
    this.isOfflineMode = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    User? user,
    String? accessToken,
    bool? isOfflineMode,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
    );
  }

  factory AuthState.fromJson(Map<String, dynamic> json) =>
      _$AuthStateFromJson(json);

  Map<String, dynamic> toJson() => _$AuthStateToJson(this);
}
