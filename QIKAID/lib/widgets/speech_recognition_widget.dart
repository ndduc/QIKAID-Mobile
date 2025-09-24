import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/speech_provider.dart';
import '../models/speech_models.dart';

class SpeechRecognitionWidget extends ConsumerStatefulWidget {
  final Function(String)? onResult;
  final Function(String)? onError;
  final bool showVisualizer;
  final Color? primaryColor;
  final Color? accentColor;

  const SpeechRecognitionWidget({
    super.key,
    this.onResult,
    this.onError,
    this.showVisualizer = true,
    this.primaryColor,
    this.accentColor,
  });

  @override
  ConsumerState<SpeechRecognitionWidget> createState() => _SpeechRecognitionWidgetState();
}

class _SpeechRecognitionWidgetState extends ConsumerState<SpeechRecognitionWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechNotifierProvider);
    final speechNotifier = ref.read(speechNotifierProvider.notifier);

    // Listen to speech results
    ref.listen<AsyncValue<SpeechRecognitionResult>>(
      speechResultsProvider,
      (previous, next) {
        next.whenData((result) {
          if (widget.onResult != null) {
            widget.onResult!(result.text);
          }
        });
      },
    );

    // Listen to speech state changes
    ref.listen<SpeechRecognitionState>(
      speechNotifierProvider,
      (previous, next) {
        if (next.isListening && !(previous?.isListening ?? false)) {
          _animationController.repeat(reverse: true);
        } else if (!next.isListening && (previous?.isListening ?? false)) {
          _animationController.stop();
          _animationController.reset();
        }

        if (next.error != null && widget.onError != null) {
          widget.onError!(next.error!);
        }
      },
    );

    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final accentColor = widget.accentColor ?? Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speech recognition button
          GestureDetector(
            onTapDown: (_) => _startListening(speechNotifier),
            onTapUp: (_) => _stopListening(speechNotifier),
            onTapCancel: () => _stopListening(speechNotifier),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: speechState.isListening ? _scaleAnimation.value : 1.0,
                  child: Opacity(
                    opacity: speechState.isListening ? _opacityAnimation.value : 1.0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: speechState.isListening 
                            ? accentColor.withValues(alpha: 0.2)
                            : primaryColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: speechState.isListening ? accentColor : primaryColor,
                          width: 3,
                        ),
                        boxShadow: speechState.isListening
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        speechState.isListening ? Icons.mic : Icons.mic_none,
                        size: 48,
                        color: speechState.isListening ? accentColor : primaryColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Status text
          Text(
            _getStatusText(speechState),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: speechState.isListening ? accentColor : primaryColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Current text
          if (speechState.currentText != null && speechState.currentText!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognized Text:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    speechState.currentText!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (speechState.confidence != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Confidence: ${(speechState.confidence! * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Error message
          if (speechState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      speechState.error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Instructions
          Text(
            speechState.isListening 
                ? 'Hold to speak, release to stop'
                : 'Hold the microphone button to start speaking',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getStatusText(SpeechRecognitionState state) {
    if (state.isProcessing) {
      return 'Initializing...';
    } else if (state.isListening) {
      return 'Listening...';
    } else if (!state.isInitialized) {
      return 'Speech recognition not available';
    } else {
      return 'Tap and hold to speak';
    }
  }

  Future<void> _startListening(SpeechNotifier speechNotifier) async {
    await speechNotifier.startListening();
  }

  Future<void> _stopListening(SpeechNotifier speechNotifier) async {
    await speechNotifier.stopListening();
  }
}

// Simple speech recognition button widget
class SpeechButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final bool isListening;
  final Color? color;
  final double size;

  const SpeechButton({
    super.key,
    this.onPressed,
    this.isListening = false,
    this.color,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonColor = color ?? Theme.of(context).primaryColor;

    return GestureDetector(
      onTapDown: (_) => onPressed?.call(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening 
              ? buttonColor.withValues(alpha: 0.2)
              : buttonColor.withValues(alpha: 0.1),
          border: Border.all(
            color: buttonColor,
            width: 2,
          ),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: buttonColor,
          size: size * 0.4,
        ),
      ),
    );
  }
}
