import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_background.dart';
import 'live_transcription_screen.dart';
import 'audio_test_screen.dart';
import 'vad_test_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with user info and logout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to QikAid',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hello, ${user?.email ?? 'User'}!',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white70,
                        size: 24,
                      ),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Main content card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // User info section
                        // Container(
                        //   padding: const EdgeInsets.all(16),
                        //   decoration: BoxDecoration(
                        //     color: const Color(0xFFF7FAFC),
                        //     borderRadius: BorderRadius.circular(12),
                        //     border: Border.all(
                        //       color: const Color(0xFFE2E8F0),
                        //     ),
                        //   ),
                        //   child: Column(
                        //     crossAxisAlignment: CrossAxisAlignment.start,
                        //     children: [
                        //       const Text(
                        //         'Account Information',
                        //         style: TextStyle(
                        //           fontSize: 16,
                        //           fontWeight: FontWeight.w600,
                        //           color: Color(0xFF2D3748),
                        //         ),
                        //       ),
                        //       const SizedBox(height: 12),
                        //       _buildInfoRow('Email', user?.email ?? 'N/A'),
                        //       _buildInfoRow('User ID', user?.id ?? 'N/A'),
                        //       if (user?.cognitoId != null)
                        //         _buildInfoRow('Cognito ID', user!.cognitoId!),
                        //       if (user?.tokenType != null)
                        //         _buildInfoRow('Token Type', user!.tokenType!),
                        //       if (user?.expiresIn != null)
                        //         _buildInfoRow('Expires In', '${user!.expiresIn!} seconds'),
                        //     ],
                        //   ),
                        // ),
                        
                        const SizedBox(height: 24),
                        
                        // Features section
                        const Text(
                          'Features',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Feature cards
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate responsive grid based on screen width
                              final screenWidth = constraints.maxWidth;
                              final crossAxisCount = screenWidth > 600 ? 3 : 2; // 3 columns for larger screens, 2 for mobile
                              final spacing = screenWidth > 400 ? 12.0 : 8.0;
                              
                              return GridView.count(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: 1.1, // Make cards slightly taller
                                children: [
                                  _buildFeatureCard(
                                    icon: Icons.mic,
                                    title: 'Live',
                                    subtitle: 'Transcription\nReal-time notes',
                                    color: const Color(0xFF3182CE),
                                    onTap: () => _navigateToLiveTranscription(context),
                                  ),
                                  _buildFeatureCard(
                                    icon: Icons.translate,
                                    title: 'Hold to Translate',
                                    subtitle: 'Tap & Talk\nSpeak & Transcribe',
                                    color: const Color(0xFF38A169),
                                    onTap: () => _showComingSoon(context, 'Hold to Translate'),
                                  ),
                                  _buildFeatureCard(
                                    icon: Icons.sync,
                                    title: 'Synced',
                                    subtitle: 'Transcription\nMirror to Plugin',
                                    color: const Color(0xFFD69E2E),
                                    onTap: () => _showComingSoon(context, 'Synced Transcription'),
                                  ),
                                  _buildFeatureCard(
                                    icon: Icons.settings,
                                    title: 'Settings',
                                    subtitle: 'Preferences',
                                    color: const Color(0xFF805AD5),
                                    onTap: () => _showComingSoon(context, 'Settings'),
                                  ),
                                  _buildFeatureCard(
                                    icon: Icons.science,
                                    title: 'Audio Test',
                                    subtitle: 'Test Dual-Lane\nAudio Streaming',
                                    color: const Color(0xFFE53E3E),
                                    onTap: () => _navigateToAudioTest(context),
                                  ),
                                  _buildFeatureCard(
                                    icon: Icons.bug_report,
                                    title: 'VAD Test',
                                    subtitle: 'Debug VAD\nPackage Issues',
                                    color: const Color(0xFF9F7AEA),
                                    onTap: () => _navigateToVADTest(context),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Footer
                const Text(
                  '© 2024 QikAid. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLiveTranscription(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LiveTranscriptionScreen(),
      ),
    );
  }

  void _navigateToAudioTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AudioTestScreen(),
      ),
    );
  }

  void _navigateToVADTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VADTestScreen(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature Coming Soon'),
        content: Text('$feature feature is currently under development and will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}