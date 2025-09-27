import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_session_provider.dart';

class LiveSessionWidget extends ConsumerStatefulWidget {
  final String cognitoId;
  final String accessToken;
  final String? sessionId;
  final String? meetingTitle;
  
  const LiveSessionWidget({
    Key? key,
    required this.cognitoId,
    required this.accessToken,
    this.sessionId,
    this.meetingTitle,
  }) : super(key: key);
  
  @override
  ConsumerState<LiveSessionWidget> createState() => _LiveSessionWidgetState();
}

class _LiveSessionWidgetState extends ConsumerState<LiveSessionWidget> {
  @override
  Widget build(BuildContext context) {
    final liveSessionState = ref.watch(liveSessionNotifierProvider);
    final liveSessionNotifier = ref.read(liveSessionNotifierProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Session'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            _buildConnectionStatus(liveSessionState),
            
            const SizedBox(height: 20),
            
            // Session Controls
            _buildSessionControls(liveSessionState, liveSessionNotifier),
            
            const SizedBox(height: 20),
            
            // Current Text Display
            _buildTextDisplay(liveSessionState),
            
            const SizedBox(height: 20),
            
            // Error Display
            if (liveSessionState.error != null)
              _buildErrorDisplay(liveSessionState.error!, liveSessionNotifier),
            
            const SizedBox(height: 20),
            
            // Manual Text Input
            _buildManualTextInput(liveSessionNotifier),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionStatus(LiveSessionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  state.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: state.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: state.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (state.sessionId != null) ...[
              const SizedBox(height: 4),
              Text('Session ID: ${state.sessionId}'),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSessionControls(LiveSessionState state, LiveSessionNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Controls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.isConnected 
                        ? null 
                        : () => _connectToSession(notifier),
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.isConnected && !state.isRecording
                        ? () => _startSession(notifier)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.isRecording
                        ? () => _stopSession(notifier)
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: state.isConnected
                        ? () => _disconnectFromSession(notifier)
                        : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextDisplay(LiveSessionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transcribed Text',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.currentText ?? 'No text received yet...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorDisplay(String error, LiveSessionNotifier notifier) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => notifier.clearError(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildManualTextInput(LiveSessionNotifier notifier) {
    final textController = TextEditingController();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Text Input',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Type a message to send...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  notifier.sendTextMessage(textController.text);
                  textController.clear();
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Send Text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _connectToSession(LiveSessionNotifier notifier) async {
    try {
      await notifier.connect(
        cognitoId: widget.cognitoId,
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
        meetingTitle: widget.meetingTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }
  
  Future<void> _startSession(LiveSessionNotifier notifier) async {
    try {
      await notifier.startSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }
  
  Future<void> _stopSession(LiveSessionNotifier notifier) async {
    try {
      await notifier.stopSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop session: $e')),
        );
      }
    }
  }
  
  Future<void> _disconnectFromSession(LiveSessionNotifier notifier) async {
    try {
      await notifier.disconnect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }
}





