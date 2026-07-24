import 'dart:async';
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
  final _messageFocusNode = FocusNode();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isTextEmpty = true;
  int? _relationshipId;
  Map<String, dynamic>? _partner;
  int? _currentUserId;
  DateTime? _lastSendTime;
  Message? _replyingToMessage;
  Message? _editingMessage;
  bool _isPartnerOnline = false;
  bool _isPartnerTyping = false;
  Timer? _localTypingTimer;
  Timer? _partnerTypingTimeoutTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastPartnerHeartbeat;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _messageFocusNode.addListener(_onFocusChange);
    _loadInitialData();
  }

  @override
  void dispose() {
    if (_relationshipId != null && _currentUserId != null) {
      WebSocketService.instance.triggerClientEvent(
        'client-status', 
        _relationshipId!, 
        {'status': 'offline', 'user_id': _currentUserId}
      );
    }
    _disconnectWebSocket();
    _localTypingTimer?.cancel();
    _partnerTypingTimeoutTimer?.cancel();
    _heartbeatTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageFocusNode.removeListener(_onFocusChange);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final isEmpty = text.trim().isEmpty;
    if (isEmpty != _isTextEmpty) {
      setState(() {
        _isTextEmpty = isEmpty;
      });
    }

    if (_relationshipId != null && _currentUserId != null) {
      if (text.isNotEmpty) {
        if (_localTypingTimer == null) {
          WebSocketService.instance.triggerClientEvent(
            'client-typing', 
            _relationshipId!, 
            {'typing': true, 'user_id': _currentUserId}
          );
        }
        
        _localTypingTimer?.cancel();
        _localTypingTimer = Timer(const Duration(seconds: 4), () {
          if (mounted && _relationshipId != null && _currentUserId != null) {
            WebSocketService.instance.triggerClientEvent(
              'client-typing', 
              _relationshipId!, 
              {'typing': false, 'user_id': _currentUserId}
            );
          }
          _localTypingTimer = null;
        });
      } else {
        if (_localTypingTimer != null) {
          _localTypingTimer?.cancel();
          _localTypingTimer = null;
          WebSocketService.instance.triggerClientEvent(
            'client-typing', 
            _relationshipId!, 
            {'typing': false, 'user_id': _currentUserId}
          );
        }
      }
    }
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
    WebSocketService.instance.addListener('App\\Events\\MessageUpdated', _onMessageUpdatedReceived);
    WebSocketService.instance.addListener('App\\Events\\MessageDeleted', _onMessageDeletedReceived);

    // Whispering / client events
    WebSocketService.instance.addListener('client-typing', _onClientTypingReceived);
    WebSocketService.instance.addListener('client-status', _onClientStatusReceived);
    WebSocketService.instance.addListener('client-status-request', _onClientStatusRequestReceived);

    // Notify online status and request partner's status
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _relationshipId != null && _currentUserId != null) {
        WebSocketService.instance.triggerClientEvent(
          'client-status', 
          _relationshipId!, 
          {'status': 'online', 'user_id': _currentUserId}
        );
        WebSocketService.instance.triggerClientEvent(
          'client-status-request', 
          _relationshipId!, 
          {'user_id': _currentUserId}
        );
      }
    });

    // Start periodic heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && _relationshipId != null && _currentUserId != null) {
        WebSocketService.instance.triggerClientEvent(
          'client-status', 
          _relationshipId!, 
          {'status': 'online', 'user_id': _currentUserId}
        );
      }

      // Offline threshold check
      if (_isPartnerOnline && _lastPartnerHeartbeat != null) {
        final diff = DateTime.now().difference(_lastPartnerHeartbeat!);
        if (diff.inSeconds > 20) {
          setState(() {
            _isPartnerOnline = false;
            _isPartnerTyping = false;
          });
        }
      }
    });
  }

  void _disconnectWebSocket() {
    WebSocketService.instance.removeListener('App\\Events\\MessageSent', _onMessageSentReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageRead', _onMessageReadReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageReacted', _onMessageReactedReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageUpdated', _onMessageUpdatedReceived);
    WebSocketService.instance.removeListener('App\\Events\\MessageDeleted', _onMessageDeletedReceived);
    WebSocketService.instance.removeListener('client-typing', _onClientTypingReceived);
    WebSocketService.instance.removeListener('client-status', _onClientStatusReceived);
    WebSocketService.instance.removeListener('client-status-request', _onClientStatusRequestReceived);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WebSocketService.instance.disconnect();
  }

  void _onClientTypingReceived(Map<String, dynamic> data) {
    final int senderId = data['user_id'] ?? 0;
    if (senderId != _currentUserId) {
      final bool typing = data['typing'] ?? false;
      setState(() {
        _isPartnerTyping = typing;
      });

      _partnerTypingTimeoutTimer?.cancel();
      if (typing) {
        _partnerTypingTimeoutTimer = Timer(const Duration(seconds: 6), () {
          setState(() {
            _isPartnerTyping = false;
          });
        });
      }
    }
  }

  void _onClientStatusReceived(Map<String, dynamic> data) {
    final int senderId = data['user_id'] ?? 0;
    if (senderId != _currentUserId) {
      final String status = data['status'] ?? 'offline';
      setState(() {
        _isPartnerOnline = status == 'online';
        if (status == 'online') {
          _lastPartnerHeartbeat = DateTime.now();
        } else {
          _isPartnerTyping = false;
        }
      });
    }
  }

  void _onClientStatusRequestReceived(Map<String, dynamic> data) {
    final int senderId = data['user_id'] ?? 0;
    if (senderId != _currentUserId && _relationshipId != null && _currentUserId != null) {
      WebSocketService.instance.triggerClientEvent(
        'client-status', 
        _relationshipId!, 
        {'status': 'online', 'user_id': _currentUserId}
      );
    }
  }

  // Handle incoming message sent by partner
  void _onMessageSentReceived(Map<String, dynamic> data) {
    if (mounted) {
      final newMessage = Message.fromJson(data);
      
      // If we already have this message ID, ignore it to prevent duplicates
      if (_messages.any((msg) => msg.id == newMessage.id)) {
        return;
      }
      
      // If we are not the sender, mark it as read and add to list
      if (newMessage.senderId != _currentUserId) {
        ApiService.instance.markMessageAsRead(newMessage.id);
        setState(() {
          _messages.add(newMessage.copyWith(isRead: true));
        });
      } else {
        // If we are the sender, check if we still have a temp message to replace
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == -1 && msg.content == newMessage.content);
          if (index != -1) {
            _messages[index] = newMessage;
          } else {
            _messages.add(newMessage);
          }
        });
      }
      _scrollToBottom();
    }
  }

  void _onMessageUpdatedReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      final newContent = data['content'] ?? '';
      setState(() {
        _messages = _messages.map((msg) {
          if (msg.id == messageId) {
            return msg.copyWith(content: newContent);
          }
          return msg;
        }).toList();
      });
    }
  }

  void _onMessageDeletedReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      setState(() {
        _messages.removeWhere((msg) => msg.id == messageId);
      });
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

  void _onMessageReactedReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      final senderReaction = data['sender_reaction'];
      final receiverReaction = data['receiver_reaction'];
      setState(() {
        _messages = _messages.map((msg) {
          if (msg.id == messageId) {
            return msg.copyWith(
              senderReaction: senderReaction,
              receiverReaction: receiverReaction,
              clearSenderReaction: senderReaction == null,
              clearReceiverReaction: receiverReaction == null,
            );
          }
          return msg;
        }).toList();
      });
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastSendTime = now;

    // Clear input field, and retain keyboard focus instantly
    _messageController.clear();
    _messageFocusNode.requestFocus();

    if (_editingMessage != null) {
      final targetMsg = _editingMessage!;
      setState(() {
        _editingMessage = null;
      });

      final originalContent = targetMsg.content;

      // Optimistic update
      setState(() {
        _messages = _messages.map((msg) {
          if (msg.id == targetMsg.id) {
            return msg.copyWith(content: text);
          }
          return msg;
        }).toList();
      });

      try {
        await ApiService.instance.editMessage(targetMsg.id, text);
      } catch (e) {
        print('Error editing message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to edit message.')),
        );
        if (mounted) {
          setState(() {
            _messages = _messages.map((msg) {
              if (msg.id == targetMsg.id) {
                return msg.copyWith(content: originalContent);
              }
              return msg;
            }).toList();
          });
        }
      }
      return;
    }

    final replyId = _replyingToMessage?.id;
    final replyMsg = _replyingToMessage;

    setState(() {
      _replyingToMessage = null;
    });

    // Create a temporary message for instant UI updates (optimistic update)
    final tempMessage = Message(
      id: -1, // Temporary negative ID
      relationshipId: _relationshipId ?? 0,
      senderId: _currentUserId ?? 0,
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
      replyToId: replyId,
      replyTo: replyMsg,
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      final response = await ApiService.instance.sendMessage(text, replyToId: replyId);
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
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg.id == -1 && msg.content == text);
        });
      }
    }
  }

  void _showReactionSheet(Message message) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🙏', '🔥', '🎉'];
    final bool isMe = message.senderId == _currentUserId;
    final String? myCurrentReaction = isMe ? message.senderReaction : message.receiverReaction;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFECEF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: emojis.length + 1,
              itemBuilder: (context, index) {
                if (index == emojis.length) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showFullEmojiPicker(message);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFB5003F).withOpacity(0.2), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Color(0xFFB5003F),
                          size: 18,
                        ),
                      ),
                    ),
                  );
                }
                final emoji = emojis[index];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    
                    final isRemoving = myCurrentReaction == emoji;
                    // Optimistic update
                    setState(() {
                      _messages = _messages.map((msg) {
                        if (msg.id == message.id) {
                          if (isMe) {
                            return msg.copyWith(
                              senderReaction: isRemoving ? null : emoji,
                              clearSenderReaction: isRemoving,
                            );
                          } else {
                            return msg.copyWith(
                              receiverReaction: isRemoving ? null : emoji,
                              clearReceiverReaction: isRemoving,
                            );
                          }
                        }
                        return msg;
                      }).toList();
                    });

                    try {
                      await ApiService.instance.reactToMessage(message.id, isRemoving ? null : emoji);
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
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (myCurrentReaction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _messages = _messages.map((msg) {
                      if (msg.id == message.id) {
                        if (isMe) {
                          return msg.copyWith(clearSenderReaction: true);
                        } else {
                          return msg.copyWith(clearReceiverReaction: true);
                        }
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
            if (message.senderId == _currentUserId) ...[
              const Divider(color: Color(0xFFF1D6DB), height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _startEditingMessage(message);
                    },
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFFB5003F), size: 18),
                    label: const Text('Edit', style: TextStyle(color: Color(0xFF2C1820), fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmUnsendMessage(message);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDE1B5D), size: 18),
                    label: const Text('Unsend', style: TextStyle(color: Color(0xFFDE1B5D), fontWeight: FontWeight.bold)),
                  ),
                ],
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
          0.0,
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
                  _isPartnerTyping
                      ? const Text(
                          'typing...',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB5003F),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _isPartnerOnline ? const Color(0xFF10B981) : const Color(0xFF8E717D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isPartnerOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 10,
                                color: _isPartnerOnline ? const Color(0xFF10B981) : const Color(0xFF8E717D),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
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
                    reverse: true,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
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
    final isSending = message.id == -1;

    return SwipeToReply(
      onReply: () {
        setState(() {
          _replyingToMessage = message;
        });
      },
      child: Opacity(
        opacity: isSending ? 0.6 : 1.0,
        child: Padding(
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
                    onLongPress: isSending ? null : () => _showReactionSheet(message),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 12,
                            bottom: (message.senderReaction != null || message.receiverReaction != null) ? 22 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFB5003F) : const Color(0xFFFFE3E8),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.replyTo != null) ...[
                                _buildBubbleReplyPreview(message.replyTo!, isMe),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                message.content,
                                textAlign: isMe ? TextAlign.end : TextAlign.start,
                                style: TextStyle(
                                  color: isMe ? Colors.white : const Color(0xFF2C1820),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Message reaction overlay
                        if (message.senderReaction != null || message.receiverReaction != null)
                          Positioned(
                            bottom: -10,
                            right: isMe ? null : 12,
                            left: isMe ? 12 : null,
                            child: GestureDetector(
                              onTap: () => _showReactionDetailsSheet(message),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF1D6DB), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (message.senderReaction != null)
                                      Text(
                                        message.senderReaction!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    if (message.senderReaction != null && message.receiverReaction != null)
                                      const SizedBox(width: 4),
                                    if (message.receiverReaction != null)
                                      Text(
                                        message.receiverReaction!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                  ],
                                ),
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
                        isSending
                            ? Icons.access_time_rounded
                            : (message.isRead ? Icons.done_all_rounded : Icons.done_rounded),
                        size: 11,
                        color: isSending
                            ? const Color(0xFF8E717D)
                            : (message.isRead ? const Color(0xFFB5003F) : const Color(0xFF8E717D)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingToMessage != null) _buildReplyPreviewBanner(),
        if (_editingMessage != null) _buildEditPreviewBanner(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
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
                    onSubmitted: _isTextEmpty ? null : (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isTextEmpty ? null : _handleSendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB5003F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB5003F),
                    disabledForegroundColor: Colors.white,
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
        ),
      ],
    );
  }

  Widget _buildReplyPreviewBanner() {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    
    final isMe = _replyingToMessage!.senderId == _currentUserId;
    final senderName = isMe ? 'You' : (_partner != null ? _partner!['name'] : 'My Love');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F3),
        border: Border(
          top: BorderSide(color: const Color(0xFFB5003F).withOpacity(0.08)),
          bottom: BorderSide(color: const Color(0xFFB5003F).withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFB5003F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB5003F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _replyingToMessage!.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E717D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E717D)),
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreviewBanner() {
    if (_editingMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F3),
        border: Border(
          top: BorderSide(color: const Color(0xFFB5003F).withOpacity(0.08)),
          bottom: BorderSide(color: const Color(0xFFB5003F).withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFB5003F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB5003F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _editingMessage!.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E717D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E717D)),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleReplyPreview(Message replyTo, bool isMeBubble) {
    final isReplyMe = replyTo.senderId == _currentUserId;
    final senderName = isReplyMe ? 'You' : (_partner != null ? _partner!['name'] : 'My Love');
    
    final barColor = isMeBubble ? Colors.white70 : const Color(0xFFB5003F);
    final titleColor = isMeBubble ? Colors.white.withOpacity(0.9) : const Color(0xFFB5003F);
    final contentColor = isMeBubble ? Colors.white70 : const Color(0xFF8E717D);
    final bgColor = isMeBubble ? Colors.white.withOpacity(0.12) : const Color(0xFFFFF0F3);

    return Container(
      width: double.infinity, // Expand to fill bubble width
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyTo.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: contentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditingMessage(Message message) {
    setState(() {
      _editingMessage = message;
      _replyingToMessage = null;
      _messageController.text = message.content;
    });
    _messageFocusNode.requestFocus();
  }

  void _confirmUnsendMessage(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Unsend message?',
            style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will permanently delete this message for everyone in the chat.',
            style: TextStyle(color: Color(0xFF2C1820)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E717D))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unsendMessage(message);
              },
              child: const Text('Unsend', style: TextStyle(color: Color(0xFFDE1B5D), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unsendMessage(Message message) async {
    final originalMessages = List<Message>.from(_messages);
    
    setState(() {
      _messages.removeWhere((msg) => msg.id == message.id);
    });

    try {
      await ApiService.instance.deleteMessage(message.id);
    } catch (e) {
      print('Error unsending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unsend message.')),
      );
      if (mounted) {
        setState(() {
          _messages = originalMessages;
        });
      }
    }
  }

  void _showFullEmojiPicker(Message message) {
    final bool isMe = message.senderId == _currentUserId;
    final String? myCurrentReaction = isMe ? message.senderReaction : message.receiverReaction;
    const Map<String, List<String>> categories = {
      'Smileys': [
        '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
        '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🫣', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬',
        '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '🥸',
        '😎', '🤓', '🧐', '😕', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱'
      ],
      'Love': [
        '❤️', '🩷', '🧡', '💛', '💚', '💙', '🩵', '💜', '🖤', '🩶', '🤍', '🤎', '💔', '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗',
        '💖', '💘', '💝', '💟'
      ],
      'Gestures': [
        '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '✊',
        '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾'
      ],
      'Fun': [
        '🎉', '🎊', '🎈', '🎂', '🎁', '🎀', '🪄', '🎭', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎮', '🎲', '🎯', '🎳', '🛹'
      ]
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFECEF),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5003F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'React with any emoji',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: categories.entries.map((entry) {
                      final categoryName = entry.key;
                      final emojiList = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5003F),
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: emojiList.length,
                            itemBuilder: (context, index) {
                              final emoji = emojiList[index];
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context);
                                  
                                  final isRemoving = myCurrentReaction == emoji;
                                  // Optimistic update
                                  setState(() {
                                    _messages = _messages.map((msg) {
                                      if (msg.id == message.id) {
                                        if (isMe) {
                                          return msg.copyWith(
                                            senderReaction: isRemoving ? null : emoji,
                                            clearSenderReaction: isRemoving,
                                          );
                                        } else {
                                          return msg.copyWith(
                                            receiverReaction: isRemoving ? null : emoji,
                                            clearReceiverReaction: isRemoving,
                                          );
                                        }
                                      }
                                      return msg;
                                    }).toList();
                                  });

                                  try {
                                    await ApiService.instance.reactToMessage(message.id, isRemoving ? null : emoji);
                                  } catch (e) {
                                    print('Error reacting: $e');
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReactionDetailsSheet(Message message) {
    final bool isMe = message.senderId == _currentUserId;
    final String? myReaction = isMe ? message.senderReaction : message.receiverReaction;
    final String? partnerReaction = isMe ? message.receiverReaction : message.senderReaction;
    final String partnerName = _partner != null ? _partner!['name'] : 'My Love';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFECEF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reactions',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1820),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Partner's Reaction Item
              if (partnerReaction != null) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      partnerReaction,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  title: Text(
                    partnerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
                  ),
                  subtitle: const Text('Partner', style: TextStyle(fontSize: 11, color: Color(0xFF8E717D))),
                ),
                const Divider(color: Color(0xFFF1D6DB), height: 16),
              ],

              // User's Reaction Item
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    myReaction ?? '➕',
                    style: TextStyle(fontSize: myReaction != null ? 22 : 18, color: myReaction == null ? const Color(0xFFB5003F) : null),
                  ),
                ),
                title: Text(
                  myReaction != null ? 'You' : 'React to message',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: myReaction != null ? const Color(0xFF2C1820) : const Color(0xFFB5003F),
                  ),
                ),
                subtitle: Text(
                  myReaction != null ? 'Tap to remove' : 'Choose an emoji',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
                ),
                trailing: myReaction != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDE1B5D)),
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          // Optimistic update
                          setState(() {
                            _messages = _messages.map((msg) {
                              if (msg.id == message.id) {
                                if (isMe) {
                                  return msg.copyWith(clearSenderReaction: true);
                                } else {
                                  return msg.copyWith(clearReceiverReaction: true);
                                }
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
                      )
                    : null,
                onTap: myReaction == null
                    ? () {
                        Navigator.pop(context);
                        _showReactionSheet(message);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}


class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({
    key,
    required this.child,
    required this.onReply,
  }) : super(key: key);

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {
          _dragOffset = _dragOffset * (1 - _controller.value);
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset += details.primaryDelta!;
        if (_dragOffset > 90.0) _dragOffset = 90.0;
        
        if (_dragOffset >= 60.0 && !_thresholdReached) {
          _thresholdReached = true;
        } else if (_dragOffset < 60.0 && _thresholdReached) {
          _thresholdReached = false;
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
    }
    _thresholdReached = false;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 0)
            Positioned(
              left: 12,
              child: Opacity(
                opacity: (_dragOffset / 60.0).clamp(0.0, 1.0),
                child: AnimatedScale(
                  scale: _thresholdReached ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECEF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: Color(0xFFDE1B5D),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

enum MediaType { image, video, audio, file }

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
