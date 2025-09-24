# QikAid Mobile App

A Flutter mobile application for QikAid - Your AI-powered meeting assistant.

## Features

- **Authentication System**: Secure login and sign-up with email and password
- **User Registration**: Create new accounts with email validation
- **Password Recovery**: Forgot password functionality with email verification
- **Offline Support**: Continue using the app even when offline (if previously authenticated)
- **Modern UI**: Mobile-optimized design matching the QikAid brand theme
- **State Management**: Built with Riverpod for efficient state management
- **Error Handling**: Comprehensive error handling and user feedback
- **Form Validation**: Real-time validation for email and password fields

## Architecture

### State Management
- **Riverpod**: Used for state management throughout the app
- **AuthProvider**: Manages authentication state and user session
- **AuthService**: Handles API calls and local storage

### Key Components

#### Models (`lib/models/`)
- `LoginRequest`: Request model for authentication
- `LoginResponse`: Response model from authentication API
- `SignUpRequest`: Request model for user registration
- `SignUpResponse`: Response model from sign-up API
- `ForgotPasswordRequest`: Request model for password recovery
- `ForgotPasswordResponse`: Response model from forgot password API
- `ConfirmForgotPasswordRequest`: Request model for password confirmation
- `ConfirmForgotPasswordResponse`: Response model from confirm forgot password API
- `User`: User data model
- `AuthState`: Application authentication state

#### Services (`lib/services/`)
- `AuthService`: Handles authentication logic, API calls, and offline storage

#### Providers (`lib/providers/`)
- `AuthProvider`: Riverpod provider for authentication state management

#### Screens (`lib/screens/`)
- `LoginScreen`: Mobile-optimized login interface
- `SignUpScreen`: User registration interface
- `HomeScreen`: Main dashboard after authentication

#### Widgets (`lib/widgets/`)
- `GradientBackground`: Reusable gradient background component
- `CustomTextField`: Styled text input field
- `CustomButton`: Styled button component
- `ForgotPasswordDialog`: Modal dialog for password recovery
- `VerificationCodeDialog`: Modal dialog for verification code and new password

## Authentication Flow

1. **User Registration**: 
   - User creates account with email and password
   - App calls `localhost:8081/auth/v1/users/create` API
   - On success, user is redirected to login screen

2. **Password Recovery**:
   - User clicks "Forgot your password?" on login screen
   - Modal dialog opens for email input
   - App calls `localhost:8081/auth/v1/users/forgot-password` API
   - On success, verification code dialog opens
   - User enters verification code and new password
   - App calls `localhost:8081/auth/v1/users/confirm-forgot-password` API
   - On success, password is reset and user can login

3. **Online Authentication**: 
   - User enters credentials
   - App calls `localhost:8081/auth/token` API
   - On success, stores token and user data locally

4. **Offline Authentication**:
   - If device is offline or API fails
   - App checks stored credentials
   - Allows access if valid offline credentials exist

5. **Session Management**:
   - Tokens and user data stored in SharedPreferences
   - Automatic session restoration on app restart
   - Secure logout clears all stored data

## API Integration

The app integrates with the QikAid authentication APIs:

### Sign Up API
```bash
curl --location 'localhost:8081/auth/v1/users/create' \
--header 'Content-Type: application/json' \
--data-raw '{
  "email": "ndduc06@gmail.com",
  "password": "BigD1995*"
}'
```

### Forgot Password API
```bash
curl --location 'localhost:8081/auth/v1/users/forgot-password' \
--header 'Content-Type: application/json' \
--header 'Origin: http://localhost:3000' \
--header 'Access-Control-Request-Method: POST' \
--header 'Access-Control-Request-Headers: content-type' \
--data-raw '{
  "email": "ndduc01@gmail.com"
}'
```

### Confirm Forgot Password API
```bash
curl --location 'localhost:8081/auth/v1/users/confirm-forgot-password' \
--header 'Content-Type: application/json' \
--header 'Origin: http://localhost:3000' \
--header 'Access-Control-Request-Method: POST' \
--header 'Access-Control-Request-Headers: content-type' \
--data-raw '{
  "email": "ndduc01@gmail.com",
  "confirmationCode": "427263",
  "newPassword": "BigD1995!"
}'
```

### Login API
```bash
curl --location 'localhost:8081/auth/token' \
--header 'Content-Type: application/json' \
--header 'Origin: http://localhost:3000' \
--header 'Access-Control-Request-Method: POST' \
--header 'Access-Control-Request-Headers: content-type' \
--data-raw '{
  "username": "ndduc01@gmail.com",
  "password": "BigD1995*"
}'
```

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- QikAid backend server running on port 8081

### API Connection Setup
**Important**: Mobile devices cannot access `localhost`. You need to configure the correct IP address:

1. **For Android Emulator**: Use `http://10.0.2.2:8081`
2. **For iOS Simulator**: Use `http://localhost:8081`
3. **For Physical Device**: Use your computer's IP address (e.g., `http://192.168.1.100:8081`)

Edit `lib/config/api_config.dart` and change the `baseUrl`:
```dart
static const String baseUrl = 'http://10.0.2.2:8081'; // Change this
```

Use the Debug Screen (🐛 icon on login screen) to test your connection.

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Generate JSON serialization code:
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```
5. Run the app:
   ```bash
   flutter run
   ```

### Dependencies

- `flutter_riverpod`: State management
- `http`: HTTP requests
- `shared_preferences`: Local storage
- `connectivity_plus`: Network connectivity checking
- `json_annotation`: JSON serialization

## UI Design

The app features a mobile-optimized design that matches the QikAid brand:

- **Color Scheme**: Orange to red gradient background
- **Typography**: Clean, modern sans-serif fonts
- **Layout**: Single-column mobile-first design
- **Components**: Custom-styled buttons, text fields, and cards
- **Responsive**: Optimized for various mobile screen sizes

## Offline Functionality

The app supports offline usage through:

1. **Credential Caching**: Stores user credentials securely
2. **Connectivity Detection**: Automatically detects online/offline status
3. **Fallback Authentication**: Uses cached credentials when offline
4. **Visual Indicators**: Shows offline mode status to users

## Security Considerations

- Passwords are not stored in plain text (production implementation should use proper hashing)
- Tokens are stored securely in SharedPreferences
- API calls include proper headers for CORS
- Error messages don't expose sensitive information

## Future Enhancements

- [ ] Implement proper password hashing for offline storage
- [ ] Add biometric authentication
- [ ] Implement refresh token mechanism
- [ ] Add user registration flow
- [ ] Implement forgot password functionality
- [ ] Add push notifications
- [ ] Implement meeting features

## Testing

Run tests with:
```bash
flutter test
```

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

## License

This project is part of the QikAid ecosystem. All rights reserved.