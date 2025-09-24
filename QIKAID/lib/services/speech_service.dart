import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/speech_models.dart';

class SpeechToTextService {
  SpeechToText? _speechToText;
  
  final StreamController<SpeechRecognitionResult> _resultController = 
      StreamController<SpeechRecognitionResult>.broadcast();
  final StreamController<SpeechRecognitionState> _stateController = 
      StreamController<SpeechRecognitionState>.broadcast();
  
  SpeechRecognitionState _currentState = const SpeechRecognitionState();
  SpeechConfig _config = const SpeechConfig();
  
  // Getters
  Stream<SpeechRecognitionResult> get resultStream => _resultController.stream;

  Stream<SpeechRecognitionState> get stateStream => _stateController.stream;

  SpeechRecognitionState get currentState => _currentState;

  bool get isInitialized => _currentState.isInitialized;

  bool get isListening => _currentState.isListening;

  /// Initialize the speech recognition service
  Future<bool> initialize({SpeechConfig? config}) async {
    try {
      print('🎤 SPEECH INIT: Starting speech service initialization...');
      
      _updateState(_currentState.copyWith(
        isProcessing: true,
        error: null,
      ));

      if (config != null) {
        _config = config;
        print('🎤 SPEECH INIT: Config updated - Language: ${_config.selectedLanguage.code}');
      }

      // Initialize speech to text
      _speechToText = SpeechToText();
      print('🎤 SPEECH INIT: SpeechToText instance created');

      // Check if speech recognition is available
      print('🎤 SPEECH INIT: Checking speech recognition availability...');
      final available = await _speechToText!.initialize(
        onError: (errorNotification) {
          print('❌ SPEECH ERROR: ${errorNotification.errorMsg}');
          _updateState(_currentState.copyWith(
            error: 'Speech recognition error: ${errorNotification.errorMsg}',
          ));
        },
        onStatus: (status) {
          print('📊 SPEECH STATUS: $status');
        },
      );

      if (!available) {
        print('❌ SPEECH INIT: Speech recognition NOT available on this device');
        _updateState(_currentState.copyWith(
          isProcessing: false,
          error: 'Speech recognition not available on this device',
        ));
        return false;
      }

      print('✅ SPEECH INIT: Speech recognition is available');
      
      // Check available locales
      final locales = await _speechToText!.locales();
      print('🌍 SPEECH INIT: Available locales: ${locales.length}');
      for (var locale in locales.take(5)) {
        print('   - ${locale.localeId}: ${locale.name}');
      }
      
      // Check microphone permission
      final hasPermission = await _speechToText!.hasPermission;
      print('🎤 SPEECH INIT: Microphone permission: $hasPermission');

      _updateState(_currentState.copyWith(
        isInitialized: true,
        isProcessing: false,
        error: null,
      ));

      print('✅ SPEECH INIT: Speech service initialized successfully');
      return true;
    } catch (e) {
      print('❌ SPEECH INIT ERROR: $e');
      _updateState(_currentState.copyWith(
        isProcessing: false,
        error: 'Failed to initialize speech service: $e',
      ));
      return false;
    }
  }

  /// Start listening for speech
  Future<bool> startListening() async {
    try {
      print('🎤 START LISTENING: Attempting to start speech recognition...');
      
      if (!_currentState.isInitialized) {
        print('🎤 START LISTENING: Service not initialized, initializing...');
        final initialized = await initialize();
        if (!initialized) {
          print('❌ START LISTENING: Failed to initialize service');
          return false;
        }
      }

      if (_currentState.isListening) {
        print('⚠️ START LISTENING: Already listening, returning true');
        return true;
      }

      print('🎤 START LISTENING: Checking microphone permission...');
      final hasPermission = await _speechToText!.hasPermission;
      if (!hasPermission) {
        print('❌ START LISTENING: No microphone permission');
        _updateState(_currentState.copyWith(
          error: 'Microphone permission required',
        ));
        return false;
      }
      print('✅ START LISTENING: Microphone permission granted');

      print('🎤 START LISTENING: Starting speech recognition with locale: ${_config.selectedLanguage.code}');
      
      _updateState(_currentState.copyWith(
        isListening: true,
        isProcessing: true,
        error: null,
        currentText: '',
      ));

      // Start listening for speech
      await _speechToText!.listen(
        onResult: (result) {
          print('🎤 SPEECH RESULT: "${result.recognizedWords}" (confidence: ${result.confidence}, final: ${result.finalResult})');
          
          final speechResult = SpeechRecognitionResult(
            text: result.recognizedWords,
            confidence: result.confidence,
            isFinal: result.finalResult,
            timestamp: DateTime.now(),
          );

          _resultController.add(speechResult);

          _updateState(_currentState.copyWith(
            currentText: speechResult.text,
            confidence: speechResult.confidence,
          ));
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        localeId: _config.selectedLanguage.code,
        onSoundLevelChange: (level) {
          print('🔊 SOUND LEVEL: $level');
        },
        listenOptions: SpeechListenOptions(
          partialResults: _config.enablePartialResults,
        ),
      );

      _updateState(_currentState.copyWith(
        isProcessing: false,
      ));

      print('✅ START LISTENING: Successfully started listening for speech');
      return true;
    } catch (e) {
      print('❌ START LISTENING ERROR: $e');
      _updateState(_currentState.copyWith(
        isListening: false,
        isProcessing: false,
        error: 'Failed to start listening: $e',
      ));
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    try {
      print('🛑 STOP LISTENING: Attempting to stop speech recognition...');
      
      if (!_currentState.isListening) {
        print('⚠️ STOP LISTENING: Not currently listening');
        return;
      }

      _updateState(_currentState.copyWith(
        isProcessing: true,
      ));

      // Stop speech recognition
      await _speechToText?.stop();

      _updateState(_currentState.copyWith(
        isListening: false,
        isProcessing: false,
      ));

      print('✅ STOP LISTENING: Successfully stopped listening for speech');
    } catch (e) {
      print('❌ STOP LISTENING ERROR: $e');
      _updateState(_currentState.copyWith(
        isListening: false,
        isProcessing: false,
        error: 'Failed to stop listening: $e',
      ));
    }
  }

  /// Cancel current recognition session
  Future<void> cancel() async {
    try {
      await stopListening();
      _updateState(_currentState.copyWith(
        currentText: '',
        confidence: null,
        error: null,
      ));
      print('DEBUG: Speech recognition cancelled');
    } catch (e) {
      print('ERROR: Failed to cancel speech recognition: $e');
    }
  }



  /// Update the current state and notify listeners
  void _updateState(SpeechRecognitionState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopListening();
      await _resultController.close();
      await _stateController.close();
      print('DEBUG: Speech service disposed');
    } catch (e) {
      print('ERROR: Failed to dispose speech service: $e');
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    if (_speechToText == null) return [];

    final locales = await _speechToText!.locales();
    final availableLocales = locales.map((locale) => locale.localeId).toList();
    
    // Filter to only show our supported languages
    final supportedCodes = SupportedLanguage.values.map((lang) => lang.code).toList();
    return availableLocales.where((locale) => supportedCodes.contains(locale)).toList();
  }

  /// Check if speech recognition is supported on this device
  Future<bool> isSupported() async {
    try {
      _speechToText ??= SpeechToText();
      
      return await _speechToText!.hasPermission;
    } catch (e) {
      print('ERROR: Failed to check speech recognition support: $e');
      return false;
    }
  }

  /// Get current configuration
  SpeechConfig get config => _config;

  /// Request microphone permission
  Future<SpeechPermissionStatus> requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        return SpeechPermissionStatus.granted;
      } else if (status.isDenied) {
        return SpeechPermissionStatus.denied;
      } else if (status.isPermanentlyDenied) {
        return SpeechPermissionStatus.permanentlyDenied;
      }
      return SpeechPermissionStatus.unknown;
    } catch (e) {
      print('ERROR: Failed to request microphone permission: $e');
      return SpeechPermissionStatus.unknown;
    }
  }

  /// Check microphone permission status
  Future<SpeechPermissionStatus> checkMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        return SpeechPermissionStatus.granted;
      } else if (status.isDenied) {
        return SpeechPermissionStatus.denied;
      } else if (status.isPermanentlyDenied) {
        return SpeechPermissionStatus.permanentlyDenied;
      }
      return SpeechPermissionStatus.unknown;
    } catch (e) {
      print('ERROR: Failed to check microphone permission: $e');
      return SpeechPermissionStatus.unknown;
    }
  }

  /// Update configuration
  void updateConfig(SpeechConfig newConfig) {
    _config = newConfig;
    print('DEBUG: Speech configuration updated');
  }
}
