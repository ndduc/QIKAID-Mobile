// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  username: json['username'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      userId: json['userId'] as String?,
      cognitoId: json['cognitoId'] as String?,
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String?,
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      message: json['message'] as String?,
      success: json['success'] as bool? ?? true,
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'cognitoId': instance.cognitoId,
      'access_token': instance.accessToken,
      'id_token': instance.idToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'message': instance.message,
      'success': instance.success,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  name: json['name'] as String?,
  avatar: json['avatar'] as String?,
  cognitoId: json['cognitoId'] as String?,
  accessToken: json['accessToken'] as String?,
  idToken: json['idToken'] as String?,
  refreshToken: json['refreshToken'] as String?,
  tokenType: json['tokenType'] as String?,
  expiresIn: (json['expiresIn'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'avatar': instance.avatar,
  'cognitoId': instance.cognitoId,
  'accessToken': instance.accessToken,
  'idToken': instance.idToken,
  'refreshToken': instance.refreshToken,
  'tokenType': instance.tokenType,
  'expiresIn': instance.expiresIn,
};

SignUpRequest _$SignUpRequestFromJson(Map<String, dynamic> json) =>
    SignUpRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$SignUpRequestToJson(SignUpRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

SignUpResponse _$SignUpResponseFromJson(Map<String, dynamic> json) =>
    SignUpResponse(
      message: json['message'] as String?,
      success: json['success'] as bool,
      userId: json['userId'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$SignUpResponseToJson(SignUpResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'success': instance.success,
      'userId': instance.userId,
      'email': instance.email,
    };

ForgotPasswordRequest _$ForgotPasswordRequestFromJson(
  Map<String, dynamic> json,
) => ForgotPasswordRequest(email: json['email'] as String);

Map<String, dynamic> _$ForgotPasswordRequestToJson(
  ForgotPasswordRequest instance,
) => <String, dynamic>{'email': instance.email};

ForgotPasswordResponse _$ForgotPasswordResponseFromJson(
  Map<String, dynamic> json,
) => ForgotPasswordResponse(
  message: json['message'] as String?,
  success: json['success'] as bool,
  email: json['email'] as String?,
);

Map<String, dynamic> _$ForgotPasswordResponseToJson(
  ForgotPasswordResponse instance,
) => <String, dynamic>{
  'message': instance.message,
  'success': instance.success,
  'email': instance.email,
};

ConfirmForgotPasswordRequest _$ConfirmForgotPasswordRequestFromJson(
  Map<String, dynamic> json,
) => ConfirmForgotPasswordRequest(
  email: json['email'] as String,
  confirmationCode: json['confirmationCode'] as String,
  newPassword: json['newPassword'] as String,
);

Map<String, dynamic> _$ConfirmForgotPasswordRequestToJson(
  ConfirmForgotPasswordRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'confirmationCode': instance.confirmationCode,
  'newPassword': instance.newPassword,
};

ConfirmForgotPasswordResponse _$ConfirmForgotPasswordResponseFromJson(
  Map<String, dynamic> json,
) => ConfirmForgotPasswordResponse(
  message: json['message'] as String?,
  success: json['success'] as bool,
);

Map<String, dynamic> _$ConfirmForgotPasswordResponseToJson(
  ConfirmForgotPasswordResponse instance,
) => <String, dynamic>{
  'message': instance.message,
  'success': instance.success,
};

AuthState _$AuthStateFromJson(Map<String, dynamic> json) => AuthState(
  isAuthenticated: json['isAuthenticated'] as bool? ?? false,
  isLoading: json['isLoading'] as bool? ?? false,
  error: json['error'] as String?,
  user: json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>),
  accessToken: json['accessToken'] as String?,
  isOfflineMode: json['isOfflineMode'] as bool? ?? false,
);

Map<String, dynamic> _$AuthStateToJson(AuthState instance) => <String, dynamic>{
  'isAuthenticated': instance.isAuthenticated,
  'isLoading': instance.isLoading,
  'error': instance.error,
  'user': instance.user,
  'accessToken': instance.accessToken,
  'isOfflineMode': instance.isOfflineMode,
};
