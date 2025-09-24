import 'package:json_annotation/json_annotation.dart';

part 'speech_models.g.dart';

/// Supported languages for speech recognition
enum SupportedLanguage {
  english('en-US', 'English'),
  japanese('ja-JP', '日本語'),
  vietnamese('vi-VN', 'Tiếng Việt');

  const SupportedLanguage(this.code, this.displayName);
  final String code;
  final String displayName;
}

@JsonSerializable()
class SpeechRecognitionResult {
  final String text;
  final double confidence;
  final bool isFinal;
  final DateTime timestamp;

  const SpeechRecognitionResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
    required this.timestamp,
  });

  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionResultFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechRecognitionResultToJson(this);
}

@JsonSerializable()
class SpeechRecognitionState {
  final bool isListening;
  final bool isInitialized;
  final String? currentText;
  final double? confidence;
  final String? error;
  final bool isProcessing;

  const SpeechRecognitionState({
    this.isListening = false,
    this.isInitialized = false,
    this.currentText,
    this.confidence,
    this.error,
    this.isProcessing = false,
  });

  SpeechRecognitionState copyWith({
    bool? isListening,
    bool? isInitialized,
    String? currentText,
    double? confidence,
    String? error,
    bool? isProcessing,
  }) {
    return SpeechRecognitionState(
      isListening: isListening ?? this.isListening,
      isInitialized: isInitialized ?? this.isInitialized,
      currentText: currentText ?? this.currentText,
      confidence: confidence ?? this.confidence,
      error: error ?? this.error,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  factory SpeechRecognitionState.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionStateFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechRecognitionStateToJson(this);
}

@JsonSerializable()
class SpeechConfig {
  final String language;
  final double sampleRate;
  final int bufferSize;
  final bool enablePartialResults;
  final double confidenceThreshold;
  final SupportedLanguage selectedLanguage;

  const SpeechConfig({
    this.language = 'en-US',
    this.sampleRate = 16000.0,
    this.bufferSize = 4096,
    this.enablePartialResults = true,
    this.confidenceThreshold = 0.7,
    this.selectedLanguage = SupportedLanguage.english,
  });

  SpeechConfig copyWith({
    String? language,
    double? sampleRate,
    int? bufferSize,
    bool? enablePartialResults,
    double? confidenceThreshold,
    SupportedLanguage? selectedLanguage,
  }) {
    return SpeechConfig(
      language: language ?? this.language,
      sampleRate: sampleRate ?? this.sampleRate,
      bufferSize: bufferSize ?? this.bufferSize,
      enablePartialResults: enablePartialResults ?? this.enablePartialResults,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
    );
  }

  factory SpeechConfig.fromJson(Map<String, dynamic> json) =>
      _$SpeechConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechConfigToJson(this);
}

enum SpeechRecognitionStatus {
  idle,
  initializing,
  listening,
  processing,
  error,
  completed,
}

enum SpeechPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
  unknown,
}
