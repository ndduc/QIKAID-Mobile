import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/auth_models.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'verification_code_dialog.dart';

class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  ConsumerState<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      print('DEBUG: Starting forgot password for email: ${_emailController.text.trim()}');
      await ref.read(authProvider.notifier).forgotPassword(_emailController.text.trim());
      
      // Add a small delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check if we should show verification dialog
      final currentState = ref.read(authProvider);
      if (!currentState.isLoading && currentState.error == null) {
        print('DEBUG: Manually triggering verification dialog');
        _showVerificationDialog(_emailController.text.trim());
      }
    }
  }

  void _closeDialog() {
    Navigator.of(context).pop();
  }

  void _showVerificationDialog(String email) {
    Navigator.of(context).pop(); // Close forgot password dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VerificationCodeDialog(email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen to auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (previous?.isLoading == true && !next.isLoading && next.error == null) {
        // Forgot password successful - show verification dialog
        print('DEBUG: Forgot password successful, showing verification dialog');
        _showVerificationDialog(_emailController.text.trim());
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  IconButton(
                    onPressed: _closeDialog,
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF718096),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Description text
              const Text(
                'Enter your email address and we\'ll send you a verification code to reset your password.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Email field
              CustomTextField(
                controller: _emailController,
                label: 'Email Address',
                hintText: 'Enter your email address',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _closeDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Send Code',
                      isLoading: authState.isLoading,
                      onPressed: _handleForgotPassword,
                      width: null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
