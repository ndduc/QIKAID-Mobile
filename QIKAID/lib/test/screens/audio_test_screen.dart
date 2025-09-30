import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_background.dart';

class AudioTestScreen extends ConsumerStatefulWidget {
  const AudioTestScreen({super.key});

  @override
  ConsumerState<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends ConsumerState<AudioTestScreen> {
  final List<String> _logs = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _addLog('🎯 Audio Test Screen initialized');
    _addLog('📱 Testing dual-lane audio streaming implementation');
  }

  @override
  void dispose() {
    // Clean up when leaving the test screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveSessionNotifierProvider.notifier).disconnect();
    });
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
  }

  Future<void> _connectToWebSocket() async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated || authState.user == null) {
        _addLog('❌ Not authenticated');
        return;
      }

      _addLog('🔌 Connecting to WebSocket...');
      final connected = await ref.read(liveSessionNotifierProvider.notifier).connect(
        cognitoId: authState.user!.cognitoId!,
        accessToken: authState.user!.accessToken!,
        sessionId: 'test-session-${DateTime.now().millisecondsSinceEpoch}',
        meetingTitle: 'Audio Test Session',
      );

      if (connected) {
        _addLog('✅ WebSocket connected successfully');
        _isConnected = true;
      } else {
        _addLog('❌ WebSocket connection failed');
      }
    } catch (e) {
      _addLog('❌ Connection error: $e');
    }
  }

  Future<void> _startAudioStreaming() async {
    try {
      if (!_isConnected) {
        _addLog('❌ Not connected to WebSocket');
        return;
      }

      _addLog('🎤 Starting dual-lane audio streaming...');
      final started = await ref.read(liveSessionNotifierProvider.notifier).startSession();
      
      if (started) {
        _addLog('✅ Audio streaming started');
        _addLog('📡 Lane 1: Live frames (20ms) for real-time captions');
        _addLog('📡 Lane 2: VAD utterances for complete sentences');
        _addLog('🎯 Speak normally to test speech detection');
      } else {
        _addLog('❌ Failed to start audio streaming');
      }
    } catch (e) {
      _addLog('❌ Start streaming error: $e');
    }
  }

  Future<void> _stopAudioStreaming() async {
    try {
      _addLog('🛑 Stopping audio streaming...');
      await ref.read(liveSessionNotifierProvider.notifier).stopSession();
      _addLog('✅ Audio streaming stopped');
    } catch (e) {
      _addLog('❌ Stop streaming error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      _addLog('🔌 Disconnecting from WebSocket...');
      await ref.read(liveSessionNotifierProvider.notifier).disconnect();
      _addLog('✅ Disconnected');
      _isConnected = false;
    } catch (e) {
      _addLog('❌ Disconnect error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveSessionState = ref.watch(liveSessionNotifierProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Audio Test - Dual-Lane Streaming',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow('WebSocket', liveSessionState.isConnected),
                      _buildStatusRow('Recording', liveSessionState.isRecording),
                      _buildStatusRow('Initialized', liveSessionState.isInitialized),
                      if (liveSessionState.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${liveSessionState.error}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConnected ? null : _connectToWebSocket,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3182CE),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Connect'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isConnected || liveSessionState.isRecording ? null : _startAudioStreaming,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38A169),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Audio'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !liveSessionState.isRecording ? null : _stopAudioStreaming,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD69E2E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Audio'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isConnected ? null : _disconnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53E3E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Logs
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Logs',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  _logs[index],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: status ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ${status ? 'Connected' : 'Disconnected'}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }
}
