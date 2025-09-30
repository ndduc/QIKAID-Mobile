import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_test_service.dart';
import '../widgets/gradient_background.dart';

class VADTestScreen extends ConsumerStatefulWidget {
  const VADTestScreen({super.key});

  @override
  ConsumerState<VADTestScreen> createState() => _VADTestScreenState();
}

class _VADTestScreenState extends ConsumerState<VADTestScreen> {
  final AudioTestService _audioTestService = AudioTestService();
  bool _isInitialized = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _audioTestService.dispose();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    setState(() {});
    final success = await _audioTestService.initialize();
    setState(() {
      _isInitialized = success;
    });
  }

  Future<void> _startRecording() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize first', isError: true);
      return;
    }

    setState(() {});
    final success = await _audioTestService.startRecording();
    setState(() {
      _isRecording = success;
    });
    
    if (success) {
      _showSnackBar('Recording started - speak to test');
    } else {
      _showSnackBar('Failed to start recording', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    await _audioTestService.stopRecording();
    setState(() {
      _isRecording = false;
    });
    _showSnackBar('Recording stopped');
  }

  void _clearLogs() {
    _audioTestService.clearTestData();
    setState(() {});
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _audioTestService.getTestSummary();
    final logs = _audioTestService.testLogs;

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
                        'VAD Package Test',
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
                        'Test Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow('Initialized', _isInitialized),
                      _buildStatusRow('Recording', _isRecording),
                      const Divider(),
                      Text('Speech Starts: ${summary['speechStartCount']}'),
                      Text('Speech Ends: ${summary['speechEndCount']}'),
                      Text('Frames Processed: ${summary['frameProcessedCount']}'),
                      Text('Errors: ${summary['errorCount']}'),
                      Text('Total Logs: ${summary['totalLogs']}'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isInitialized ? null : _initializeTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3182CE),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Initialize'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isInitialized || _isRecording ? null : _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38A169),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Test'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isRecording ? null : _stopRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD69E2E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Test'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _clearLogs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF718096),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear Logs'),
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
                        Row(
                          children: [
                            const Text(
                              'Test Logs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${logs.length} entries',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: logs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No logs yet. Initialize and start recording to see test results.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    final log = logs[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        log,
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
            '$label: ${status ? 'Yes' : 'No'}',
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
