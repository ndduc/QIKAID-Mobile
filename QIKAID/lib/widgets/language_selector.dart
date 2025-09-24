import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speech_models.dart';
import '../providers/speech_provider.dart';

class LanguageSelector extends ConsumerWidget {
  final bool showAsDialog;

  const LanguageSelector({super.key, this.showAsDialog = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speechConfig = ref.watch(speechConfigProvider);
    final speechNotifier = ref.read(speechNotifierProvider.notifier);

    Widget buildLanguageContent() {
      return DropdownButton<SupportedLanguage>(
        value: speechConfig.selectedLanguage,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.language, color: Colors.white70),
        underline: const SizedBox(),
        onChanged: (SupportedLanguage? newValue) {
          if (newValue != null) {
            final newConfig = speechConfig.copyWith(
              selectedLanguage: newValue,
              language: newValue.code,
            );
            speechNotifier.updateConfig(newConfig);
            if (showAsDialog) {
              Navigator.of(context).pop();
            }
          }
        },
        items: SupportedLanguage.values.map<DropdownMenuItem<SupportedLanguage>>((SupportedLanguage value) {
          return DropdownMenuItem<SupportedLanguage>(
            value: value,
            child: Row(
              children: [
                Text(
                  _getLanguageFlag(value),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  value.displayName,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (showAsDialog) {
      return IconButton(
        icon: const Icon(Icons.language, color: Colors.white70),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Select Language'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: SupportedLanguage.values.map((language) {
                    return RadioListTile<SupportedLanguage>(
                      title: Row(
                        children: [
                          Text(
                            _getLanguageFlag(language),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(language.displayName),
                        ],
                      ),
                      subtitle: Text(language.code),
                      value: language,
                      groupValue: speechConfig.selectedLanguage,
                      onChanged: (SupportedLanguage? newValue) {
                        if (newValue != null) {
                          final newConfig = speechConfig.copyWith(
                            selectedLanguage: newValue,
                            language: newValue.code,
                          );
                          speechNotifier.updateConfig(newConfig);
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  }).toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      return buildLanguageContent();
    }
  }

  String _getLanguageFlag(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.english:
        return '🇺🇸';
      case SupportedLanguage.japanese:
        return '🇯🇵';
      case SupportedLanguage.vietnamese:
        return '🇻🇳';
    }
  }
}

class LanguageIndicator extends ConsumerWidget {
  const LanguageIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speechConfig = ref.watch(speechConfigProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getLanguageFlag(speechConfig.selectedLanguage),
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 3),
          Text(
            speechConfig.selectedLanguage.displayName,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageFlag(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.english:
        return '🇺🇸';
      case SupportedLanguage.japanese:
        return '🇯🇵';
      case SupportedLanguage.vietnamese:
        return '🇻🇳';
    }
  }
}
