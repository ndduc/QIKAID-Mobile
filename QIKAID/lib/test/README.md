# Test Files Organization

This directory contains all test-related files for the QIKAID Mobile application, organized within the `lib` structure for proper Flutter project organization.

## Directory Structure

```
lib/test/
├── screens/           # Test screens and UI components
│   ├── audio_test_screen.dart      # Audio streaming test screen
│   ├── vad_test_screen.dart        # VAD package test screen
│   └── debug_screen.dart           # Debug utilities (commented out)
├── services/          # Test services and utilities
│   └── audio_test_service.dart     # VAD package testing service
└── widgets/           # Test widgets (empty)
```

## Test Files Description

### Screens (`lib/test/screens/`)

- **`audio_test_screen.dart`**: Comprehensive test screen for dual-lane audio streaming functionality
  - Tests WebSocket connection
  - Tests audio streaming start/stop
  - Provides detailed logging and status monitoring
  - Used for debugging audio capture issues

- **`vad_test_screen.dart`**: Dedicated test screen for VAD (Voice Activity Detection) package
  - Tests VAD package initialization
  - Monitors speech detection events
  - Provides real-time logging of VAD events
  - Used for debugging mobile audio capture issues

- **`debug_screen.dart`**: Debug utilities screen (currently commented out)
  - Contains debugging tools and utilities
  - Can be uncommented when needed for debugging

### Services (`lib/test/services/`)

- **`audio_test_service.dart`**: Service for testing VAD package functionality
  - Provides isolated VAD testing without complex audio processing
  - Tracks speech detection events (starts, ends, frame processing)
  - Provides comprehensive error reporting and logging
  - Used by VAD test screen for debugging

## Usage

These test files are accessible from the main application through the home screen:

1. **Audio Test**: Navigate to "Audio Test" from the home screen to test dual-lane audio streaming
2. **VAD Test**: Navigate to "VAD Test" from the home screen to debug VAD package issues

## Import Paths

When importing these test files from the main application, use the following paths:

```dart
// From lib/screens/home_screen.dart
import '../test/screens/audio_test_screen.dart';
import '../test/screens/vad_test_screen.dart';

// From lib/screens/login_screen.dart
import '../test/screens/debug_screen.dart';
```

## Purpose

These test files are organized within the `lib` directory to:
- Keep test files within the Flutter project structure
- Maintain proper import paths and dependencies
- Allow test files to access production code easily
- Follow Flutter project organization best practices
- Keep test utilities separate from production screens/services

## Maintenance

When adding new test files:
1. Place screen tests in `lib/test/screens/`
2. Place service tests in `lib/test/services/`
3. Place widget tests in `lib/test/widgets/`
4. Update import paths in files that reference the test files
5. Update this README with descriptions of new test files
