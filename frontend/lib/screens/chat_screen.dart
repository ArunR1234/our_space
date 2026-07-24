import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int? _relationshipId;
  Map<String, dynamic>? _partner;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _disconnectWebSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Fetch user status to get relationship ID and current user ID
      final status = await ApiService.instance.getUserStatus();
      _currentUserId = status['user']['id'];
      _partner = status['partner'];
      final relationship = status['relationship'];

      if (relationship != null) {
        _relationshipId = relationship['id'];
        
        // 2. Load message history
        await _loadMessages();

        // 3. Connect to WebSockets for real-time updates
        _connectWebSocket();
      }
    } catch (e) {
      print('Error initializing chat: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesJson = await ApiService.instance.getMessages();
      if (mounted) {
        setState(() {
          _messages = messagesJson.map((json) => Message.fromJson(json)).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _connectWebSocket() {
    if (_relationshipId == null) return;

    // Listen to real-time events via Reverb WebSocket
    WebSocketService.instance.connect(_relationshipId!);

    // Listener for new messages
    WebSocketService.instance.addListener('App\\Events\\MessageSent', _onMessageSentReceived);

    // Listener for read receipts
    WebSocketService.instance.addListener('App\\Events\\MessageRead', _onMessageReadReceived);

    // Listener for reactions
    WebSocketService.instance.addListener('App\\Events\\MessageReacted', _onMessageReactedReceived);
  }

  void _disconnectWebSocket() {
    WebSocketService.instance.removeListener('App\\Events\\MessageSent', _onMessageSentReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageRead', _onMessageReadReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageReacted', _onMessageReactedReceived);
    WebSocketService.instance.disconnect();
  }

  // Handle incoming message sent by partner
  void _onMessageSentReceived(Map<String, dynamic> data) {
    if (mounted) {
      final newMessage = Message.fromJson(data);
      
      // If we are not the sender, mark it as read and add to list
      if (newMessage.senderId != _currentUserId) {
        ApiService.instance.markMessageAsRead(newMessage.id);
        setState(() {
          _messages.add(newMessage.copyWith(isRead: true));
        });
      } else {
        setState(() {
          _messages.add(newMessage);
        });
      }
      _scrollToBottom();
    }
  }

  // Handle read receipt event
  void _onMessageReadReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      setState(() {
        _messages = _messages.map((msg) {
          if (msg.id == messageId) {
            return msg.copyWith(isRead: true);
          }
          return msg;
        }).toList();
      });
    }
  }

  // Handle reaction event
  void _onMessageReactedReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      final reaction = data['reaction'];
      setState(() {
        _messages = _messages.map((msg) {
          if (msg.id == messageId) {
            return msg.copyWith(reaction: reaction);
          }
          return msg;
        }).toList();
      });
    }
  }

  Future<void> _handleSendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    // Create a temporary message for instant UI updates (optimistic update)
    final tempMessage = Message(
      id: -1, // Temporary negative ID
      relationshipId: _relationshipId ?? 0,
      senderId: _currentUserId ?? 0,
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      final response = await ApiService.instance.sendMessage(text);
      final sentMessage = Message.fromJson(response);

      if (mounted) {
        setState(() {
          // Replace optimistic message with actual db message
          final index = _messages.indexWhere((msg) => msg.id == -1 && msg.content == text);
          if (index != -1) {
            _messages[index] = sentMessage;
          }
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showReactionSheet(Message message) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🙏', '🔥', '🎉'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFECEF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'React to message',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1820),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    
                    // Optimistic update
                    setState(() {
                      _messages = _messages.map((msg) {
                        if (msg.id == message.id) {
                          return msg.copyWith(reaction: emoji);
                        }
                        return msg;
                      }).toList();
                    });

                    try {
                      await ApiService.instance.reactToMessage(message.id, emoji);
                    } catch (e) {
                      print('Error reacting: $e');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (message.reaction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _messages = _messages.map((msg) {
                      if (msg.id == message.id) {
                        return msg.copyWith(reaction: null);
                      }
                      return msg;
                    }).toList();
                  });

                  try {
                    await ApiService.instance.reactToMessage(message.id, null);
                  } catch (e) {
                    print('Error removing reaction: $e');
                  }
                },
                child: const Text(
                  'Remove Reaction',
                  style: TextStyle(color: Color(0xFFB5003F), fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const Icon(
          Icons.favorite_border_rounded,
          color: Color(0xFFB5003F),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFECEF),
              child: Icon(Icons.person_rounded, color: Color(0xFFB5003F), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _partner != null ? _partner!['name'] : 'My Love',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1820),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(fontSize: 10, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.settings_outlined, color: Color(0xFFB5003F)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(0xFFFFECEF),
                  child: Icon(Icons.person_rounded, size: 14, color: Color(0xFFB5003F)),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onLongPress: () => _showReactionSheet(message),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFFB5003F) : const Color(0xFFFFE3E8),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMe ? Colors.white : const Color(0xFF2C1820),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    // Message reaction overlay
                    if (message.reaction != null)
                      Positioned(
                        bottom: -10,
                        right: isMe ? null : 12,
                        left: isMe ? 12 : null,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            message.reaction!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Timestamp & read checkmarks
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 32.0,
              right: isMe ? 8.0 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF8E717D)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 11,
                    color: message.isRead ? const Color(0xFFB5003F) : const Color(0xFF8E717D),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Color(0xFFB5003F)),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your heart...',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: const Color(0xFFFFF5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _isSending ? null : (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSending ? null : _handleSendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5003F),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Text('Send Love', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.auto_awesome_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
