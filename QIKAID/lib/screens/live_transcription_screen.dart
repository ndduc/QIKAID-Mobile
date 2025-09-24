import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_session_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/language_selector.dart';

class LiveTranscriptionScreen extends ConsumerStatefulWidget {
  const LiveTranscriptionScreen({super.key});

  @override
  ConsumerState<LiveTranscriptionScreen> createState() => _LiveTranscriptionScreenState();
}

class _LiveTranscriptionScreenState extends ConsumerState<LiveTranscriptionScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<TranscriptMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStoredTranscripts();
    // Delay the connection to avoid modifying provider during widget lifecycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToLiveSession();
    });
  }

  @override
  void dispose() {
    // Disconnect from live session when leaving the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveSessionNotifierProvider.notifier).disconnect();
    });
    
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _loadStoredTranscripts() {
    // Add a welcome message
    _messages.add(
      TranscriptMessage(
        id: '1',
        text: 'Welcome to Live Session! Tap the microphone to test audio recording. In offline mode, audio will be captured but not sent to a server.',
        timestamp: DateTime.now(),
        isSystemMessage: true,
      ),
    );
  }

  void _connectToLiveSession() async {
    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      
      if (user?.cognitoId != null && user?.accessToken != null) {
        final liveSessionNotifier = ref.read(liveSessionNotifierProvider.notifier);
        
        await liveSessionNotifier.connect(
          cognitoId: user!.cognitoId!,
          accessToken: user.accessToken!,
          sessionId: 'mobile-session-${DateTime.now().millisecondsSinceEpoch}',
          meetingTitle: 'Mobile Live Session',
        );
      } else {
        print('❌ LIVE SESSION: Missing user credentials for connection');
      }
    } catch (e) {
      print('❌ LIVE SESSION CONNECT ERROR: $e');
    }
  }

  void _manualConnect() {
    _connectToLiveSession();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMessage(String text, {bool isFinal = false}) {
    if (text.trim().isEmpty) return;

    setState(() {
      // If it's a partial result, update the last message
      if (!isFinal && _messages.isNotEmpty && !_messages.last.isFinal) {
        _messages.last = _messages.last.copyWith(text: text);
      } else {
        // Add new message
        _messages.add(
          TranscriptMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text,
            timestamp: DateTime.now(),
            isFinal: isFinal,
          ),
        );
      }
    });

    _scrollToBottom();
  }

  void _toggleListening() async {
    final liveSessionNotifier = ref.read(liveSessionNotifierProvider.notifier);
    final liveSessionState = ref.read(liveSessionNotifierProvider);

    if (liveSessionState.isRecording) {
      await liveSessionNotifier.stopSession();
    } else {
      await liveSessionNotifier.startSession();
    }
  }

  void _sendTextMessage() async {
    if (_textController.text.trim().isEmpty) return;
    
    final liveSessionNotifier = ref.read(liveSessionNotifierProvider.notifier);
    await liveSessionNotifier.sendTextMessage(_textController.text.trim());
    
    _textController.clear();
  }

  /// Handle when transcript session ends
  /// This method will be used for future implementation of:
  /// - Saving transcripts to local storage
  /// - Session management
  /// - Data persistence
  void _onTranscriptSessionEnded() {
    // TODO: Implement transcript session end handling
    // This could include:
    // - Saving current session to local storage
    // - Cleaning up temporary data
    // - Updating session statistics
    // - Preparing for next session
    print('DEBUG: Transcript session ended');
  }

  @override
  Widget build(BuildContext context) {
    final liveSessionState = ref.watch(liveSessionNotifierProvider);

    // Listen to live session state changes
    ref.listen<LiveSessionState>(
      liveSessionNotifierProvider,
      (previous, next) {
        // Handle new transcribed text
        if (next.currentText != null && next.currentText != previous?.currentText) {
          _addMessage(next.currentText!, isFinal: true);
        }

        // Handle errors
        if (next.error != null && next.error != previous?.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Live Transcription',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const LanguageSelector(showAsDialog: true),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _showSettings,
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white70,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),

              // Connection status banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: liveSessionState.isConnected 
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: liveSessionState.isConnected 
                        ? Colors.green.withValues(alpha: 0.4)
                        : Colors.red.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      liveSessionState.isConnected ? Icons.wifi : Icons.wifi_off,
                      color: liveSessionState.isConnected ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        liveSessionState.isConnected 
                            ? 'Connected to Live Session (WebSocket)'
                            : 'Offline Mode - Testing Microphone Only',
                        style: TextStyle(
                          fontSize: 12,
                          color: liveSessionState.isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!liveSessionState.isConnected)
                      TextButton(
                        onPressed: _manualConnect,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Connect',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Messages area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Action bar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFC),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: _copyTranscript,
                                icon: const Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: Color(0xFF3182CE),
                                ),
                                label: const Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: Color(0xFF3182CE),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _selectConversation,
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: Color(0xFF3182CE),
                                ),
                                label: const Text(
                                  'Select conversation',
                                  style: TextStyle(
                                    color: Color(0xFF3182CE),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Messages list
                        Expanded(
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No transcripts yet. Start speaking to see your conversation here.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    return _buildMessageBubble(message);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Text input and controls
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                  children: [
                    // Text input field
                    TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type a message to send...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _sendTextMessage,
                          icon: const Icon(Icons.send),
                          color: const Color(0xFF3182CE),
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Controls row
                    Row(
                      children: [
                        // Microphone button
                        GestureDetector(
                          onTap: _toggleListening,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: liveSessionState.isRecording
                                  ? const Color(0xFFE53E3E).withValues(alpha: 0.2)
                                  : const Color(0xFF3182CE).withValues(alpha: 0.1),
                              border: Border.all(
                                color: liveSessionState.isRecording
                                    ? const Color(0xFFE53E3E)
                                    : const Color(0xFF3182CE),
                                width: 2,
                              ),
                              boxShadow: liveSessionState.isRecording
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              liveSessionState.isRecording ? Icons.mic : Icons.mic_none,
                              color: liveSessionState.isRecording
                                  ? const Color(0xFFE53E3E)
                                  : const Color(0xFF3182CE),
                              size: 26,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Status text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                liveSessionState.isRecording ? 'Recording...' : 'Tap to start recording',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: liveSessionState.isRecording
                                      ? const Color(0xFFE53E3E)
                                      : const Color(0xFF2D3748),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                liveSessionState.isRecording
                                    ? liveSessionState.isConnected 
                                        ? 'Sending audio to server for transcription'
                                        : 'Recording audio (offline mode)'
                                    : 'Start recording to test microphone',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF718096),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Language indicator
                        const LanguageIndicator(),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(TranscriptMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: message.isSystemMessage
                  ? Colors.grey.withValues(alpha: 0.2)
                  : const Color(0xFF3182CE).withValues(alpha: 0.2),
            ),
            child: Icon(
              message.isSystemMessage
                  ? Icons.info_outline
                  : Icons.person,
              size: 16,
              color: message.isSystemMessage
                  ? Colors.grey[600]
                  : const Color(0xFF3182CE),
            ),
          ),

          const SizedBox(width: 12),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isSystemMessage
                        ? Colors.grey.withValues(alpha: 0.1)
                        : const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.isSystemMessage
                          ? Colors.grey.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: message.isSystemMessage
                          ? Colors.grey[700]
                          : const Color(0xFF2D3748),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcription Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language Settings
              const Text(
                'Language',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const LanguageSelector(showAsDialog: false),
              const SizedBox(height: 16),
              
              
              // Additional Settings
              const Text(
                'Additional Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Enable Partial Results'),
                subtitle: const Text('Show text as you speak'),
                value: true, // TODO: Connect to actual setting
                onChanged: (value) {
                  // TODO: Implement partial results toggle
                },
              ),
              SwitchListTile(
                title: const Text('Auto-scroll'),
                subtitle: const Text('Automatically scroll to new messages'),
                value: true, // TODO: Connect to actual setting
                onChanged: (value) {
                  // TODO: Implement auto-scroll toggle
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _copyTranscript() {
    final transcript = _messages
        .where((msg) => !msg.isSystemMessage)
        .map((msg) => msg.text)
        .join('\n');

    if (transcript.isNotEmpty) {
      // TODO: Implement actual clipboard functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcript to copy'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  void _selectConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a conversation to load:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Sample conversations
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Current Session'),
              subtitle: Text('${_messages.length} messages'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loaded current session'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Previous Session 1'),
              subtitle: const Text('15 messages • 2 hours ago'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loaded previous session 1'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Previous Session 2'),
              subtitle: const Text('8 messages • Yesterday'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loaded previous session 2'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Start New Conversation'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _messages.clear();
                  _messages.add(
                    TranscriptMessage(
                      id: 'welcome',
                      text: 'Welcome to Live Transcription! Tap the microphone to start speaking.',
                      timestamp: DateTime.now(),
                      isSystemMessage: true,
                    ),
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Started new conversation'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class TranscriptMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFinal;
  final bool isSystemMessage;

  const TranscriptMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    this.isFinal = true,
    this.isSystemMessage = false,
  });

  TranscriptMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isFinal,
    bool? isSystemMessage,
  }) {
    return TranscriptMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
    );
  }
}
