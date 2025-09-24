import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speech_models.dart';
import '../services/speech_service.dart';

// Speech service provider
final speechServiceProvider = Provider<SpeechToTextService>((ref) {
  final service = SpeechToTextService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Speech recognition state provider
final speechStateProvider = StreamProvider<SpeechRecognitionState>((ref) {
  final speechService = ref.watch(speechServiceProvider);
  return speechService.stateStream;
});

// Speech recognition results provider
final speechResultsProvider = StreamProvider<SpeechRecognitionResult>((ref) {
  final speechService = ref.watch(speechServiceProvider);
  return speechService.resultStream;
});

// Speech recognition notifier
class SpeechNotifier extends StateNotifier<SpeechRecognitionState> {
  final SpeechToTextService _speechService;

  SpeechNotifier(this._speechService) : super(const SpeechRecognitionState()) {
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      state = state.copyWith(isProcessing: true, error: null);
      
      final initialized = await _speechService.initialize();
      
      if (initialized) {
        state = state.copyWith(
          isInitialized: true,
          isProcessing: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isInitialized: false,
          isProcessing: false,
          error: 'Failed to initialize speech service',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        isProcessing: false,
        error: 'Speech service initialization error: $e',
      );
    }
  }

  Future<void> startListening() async {
    try {
      print('🎤 PROVIDER START: Starting speech recognition...');
      state = state.copyWith(isProcessing: true, error: null);
      
      final started = await _speechService.startListening();
      
      if (started) {
        print('✅ PROVIDER START: Speech recognition started successfully');
        state = state.copyWith(
          isListening: true,
          isProcessing: false,
          error: null,
        );
      } else {
        print('❌ PROVIDER START: Failed to start speech recognition');
        state = state.copyWith(
          isListening: false,
          isProcessing: false,
          error: 'Failed to start listening',
        );
      }
    } catch (e) {
      print('❌ PROVIDER START ERROR: $e');
      state = state.copyWith(
        isListening: false,
        isProcessing: false,
        error: 'Start listening error: $e',
      );
    }
  }

  Future<void> stopListening() async {
    try {
      print('🛑 PROVIDER STOP: Stopping speech recognition...');
      state = state.copyWith(isProcessing: true);
      
      await _speechService.stopListening();
      
      print('✅ PROVIDER STOP: Speech recognition stopped successfully');
      state = state.copyWith(
        isListening: false,
        isProcessing: false,
      );
    } catch (e) {
      print('❌ PROVIDER STOP ERROR: $e');
      state = state.copyWith(
        isListening: false,
        isProcessing: false,
        error: 'Stop listening error: $e',
      );
    }
  }

  Future<void> cancel() async {
    try {
      await _speechService.cancel();
      
      state = state.copyWith(
        isListening: false,
        isProcessing: false,
        currentText: '',
        confidence: null,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Cancel error: $e',
      );
    }
  }

  void updateConfig(SpeechConfig config) {
    _speechService.updateConfig(config);
  }

  Future<bool> isSupported() async {
    return await _speechService.isSupported();
  }

  Future<List<String>> getAvailableLanguages() async {
    return await _speechService.getAvailableLanguages();
  }
}

// Speech notifier provider
final speechNotifierProvider = StateNotifierProvider<SpeechNotifier, SpeechRecognitionState>((ref) {
  final speechService = ref.watch(speechServiceProvider);
  return SpeechNotifier(speechService);
});

// Speech configuration provider
final speechConfigProvider = StateProvider<SpeechConfig>((ref) {
  return const SpeechConfig();
});

// Speech permission status provider
final speechPermissionProvider = FutureProvider<SpeechPermissionStatus>((ref) async {
  final speechService = ref.watch(speechServiceProvider);
  return await speechService.isSupported() 
      ? SpeechPermissionStatus.granted 
      : SpeechPermissionStatus.denied;
});

