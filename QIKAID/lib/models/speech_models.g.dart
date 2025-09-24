// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpeechRecognitionResult _$SpeechRecognitionResultFromJson(
  Map<String, dynamic> json,
) => SpeechRecognitionResult(
  text: json['text'] as String,
  confidence: (json['confidence'] as num).toDouble(),
  isFinal: json['isFinal'] as bool,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$SpeechRecognitionResultToJson(
  SpeechRecognitionResult instance,
) => <String, dynamic>{
  'text': instance.text,
  'confidence': instance.confidence,
  'isFinal': instance.isFinal,
  'timestamp': instance.timestamp.toIso8601String(),
};

SpeechRecognitionState _$SpeechRecognitionStateFromJson(
  Map<String, dynamic> json,
) => SpeechRecognitionState(
  isListening: json['isListening'] as bool? ?? false,
  isInitialized: json['isInitialized'] as bool? ?? false,
  currentText: json['currentText'] as String?,
  confidence: (json['confidence'] as num?)?.toDouble(),
  error: json['error'] as String?,
  isProcessing: json['isProcessing'] as bool? ?? false,
);

Map<String, dynamic> _$SpeechRecognitionStateToJson(
  SpeechRecognitionState instance,
) => <String, dynamic>{
  'isListening': instance.isListening,
  'isInitialized': instance.isInitialized,
  'currentText': instance.currentText,
  'confidence': instance.confidence,
  'error': instance.error,
  'isProcessing': instance.isProcessing,
};

SpeechConfig _$SpeechConfigFromJson(Map<String, dynamic> json) => SpeechConfig(
  language: json['language'] as String? ?? 'en-US',
  sampleRate: (json['sampleRate'] as num?)?.toDouble() ?? 16000.0,
  bufferSize: (json['bufferSize'] as num?)?.toInt() ?? 4096,
  enablePartialResults: json['enablePartialResults'] as bool? ?? true,
  confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.7,
  selectedLanguage:
      $enumDecodeNullable(
        _$SupportedLanguageEnumMap,
        json['selectedLanguage'],
      ) ??
      SupportedLanguage.english,
);

Map<String, dynamic> _$SpeechConfigToJson(
  SpeechConfig instance,
) => <String, dynamic>{
  'language': instance.language,
  'sampleRate': instance.sampleRate,
  'bufferSize': instance.bufferSize,
  'enablePartialResults': instance.enablePartialResults,
  'confidenceThreshold': instance.confidenceThreshold,
  'selectedLanguage': _$SupportedLanguageEnumMap[instance.selectedLanguage]!,
};

const _$SupportedLanguageEnumMap = {
  SupportedLanguage.english: 'english',
  SupportedLanguage.japanese: 'japanese',
  SupportedLanguage.vietnamese: 'vietnamese',
};
