// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../config/api_config.dart';
// import '../services/auth_service.dart';
// import '../widgets/gradient_background.dart';
// import '../widgets/custom_button.dart';
//
// class DebugScreen extends ConsumerStatefulWidget {
//   const DebugScreen({super.key});
//
//   @override
//   ConsumerState<DebugScreen> createState() => _DebugScreenState();
// }
//
// class _DebugScreenState extends ConsumerState<DebugScreen> {
//   String _testResult = '';
//   bool _isLoading = false;
//
//   Future<void> _testConnection() async {
//     setState(() {
//       _isLoading = true;
//       _testResult = '';
//     });
//
//     try {
//       final authService = AuthService();
//       final isOnline = await authService.isOnline();
//
//       setState(() {
//         _testResult = 'Connection Test Results:\n\n';
//         _testResult += 'Current API URL: ${ApiConfig.getBaseUrl()}\n';
//         _testResult += 'Device Online: $isOnline\n\n';
//
//         if (isOnline) {
//           _testResult += '✅ Device has internet connection\n';
//           _testResult += '⚠️  If API calls still fail, try these solutions:\n\n';
//           _testResult += '1. For Android Emulator:\n';
//           _testResult += '   Use: http://10.0.2.2:8081\n\n';
//           _testResult += '2. For iOS Simulator:\n';
//           _testResult += '   Use: http://localhost:8081\n\n';
//           _testResult += '3. For Physical Device:\n';
//           _testResult += '   Find your computer\'s IP:\n';
//           _testResult += '   - Windows: ipconfig\n';
//           _testResult += '   - Mac/Linux: ifconfig\n';
//           _testResult += '   Use: http://YOUR_IP:8081\n\n';
//           _testResult += '4. Make sure your server is running\n';
//           _testResult += '5. Check firewall settings\n';
//           _testResult += '6. Ensure server accepts connections from all interfaces';
//         } else {
//           _testResult += '❌ No internet connection detected';
//         }
//       });
//     } catch (e) {
//       setState(() {
//         _testResult = 'Error testing connection: $e';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GradientBackground(
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               children: [
//                 // Header
//                 Row(
//                   children: [
//                     IconButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       icon: const Icon(
//                         Icons.arrow_back,
//                         color: Colors.white,
//                         size: 24,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     const Text(
//                       'API Debug',
//                       style: TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 40),
//
//                 // Debug Card
//                 Expanded(
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withValues(alpha: 0.1),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'API Connection Debug',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Color(0xFF2D3748),
//                           ),
//                         ),
//
//                         const SizedBox(height: 16),
//
//                         const Text(
//                           'This screen helps you troubleshoot API connection issues.',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Color(0xFF718096),
//                           ),
//                         ),
//
//                         const SizedBox(height: 24),
//
//                         CustomButton(
//                           text: 'Test Connection',
//                           isLoading: _isLoading,
//                           onPressed: _testConnection,
//                         ),
//
//                         const SizedBox(height: 24),
//
//                         if (_testResult.isNotEmpty)
//                           Expanded(
//                             child: Container(
//                               width: double.infinity,
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFFF7FAFC),
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(
//                                   color: const Color(0xFFE2E8F0),
//                                 ),
//                               ),
//                               child: SingleChildScrollView(
//                                 child: Text(
//                                   _testResult,
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     color: Color(0xFF2D3748),
//                                     fontFamily: 'monospace',
//                                     height: 1.4,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//






