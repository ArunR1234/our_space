import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
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
  bool _isUserNearBottom = true;
  int _unreadCount = 0;
  int? _firstUnreadChronoIndex;
  bool _playSounds = true;
  Message? _activeReactionMessage;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  int? _highlightedMessageId;
  List<int> _searchResultIndices = [];
  int _currentSearchResultIndex = -1;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _messageFocusNode.addListener(_onFocusChange);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
    _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _playSounds = prefs.getBool('play_chat_sounds') ?? true;
        });
      }
    } catch (e) {
      print('Error loading sound preference: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final nearBottom = _scrollController.offset <= 120.0;
      // Update without setState — _isUserNearBottom is not rendered directly
      if (nearBottom != _isUserNearBottom) {
        _isUserNearBottom = nearBottom;
        // Only rebuild when we need to hide the banner
        if (nearBottom && _unreadCount > 0) {
          setState(() {
            _unreadCount = 0;
          });
        }
      }
    }
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
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Preserves scroll position when keyboard opens/closes
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
        _scrollToBottomForced();
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesJson = await ApiService.instance.getMessages();
      if (mounted) {
        final loadedMessages = messagesJson.map((json) => Message.fromJson(json)).toList();
        
        int? firstUnread;
        for (int i = 0; i < loadedMessages.length; i++) {
          final msg = loadedMessages[i];
          if (!msg.isRead && msg.senderId != _currentUserId) {
            firstUnread = i;
            break;
          }
        }
        
        setState(() {
          _messages = loadedMessages;
          _firstUnreadChronoIndex = firstUnread;
        });
        _scrollToBottomForced();
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
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      // Offline threshold check
      if (_isPartnerOnline && _lastPartnerHeartbeat != null) {
        final diff = DateTime.now().difference(_lastPartnerHeartbeat!);
        if (diff.inSeconds > 35) {
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
        
        // Play receive sound
        if (_playSounds) {
          try {
            _audioPlayer.play(AssetSource('sounds/msgsound.mp3'));
          } catch (e) {
            print('Error playing receive sound: $e');
          }
        }

        setState(() {
          _messages.add(newMessage.copyWith(isRead: true));
          // Count unread when user is scrolled away
          if (!_isUserNearBottom) {
            _unreadCount++;
          }
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
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWith(content: newContent);
        });
      }
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
      final updatedAtStr = data['updated_at'];
      final updatedAt = updatedAtStr != null ? DateTime.parse(updatedAtStr) : DateTime.now();
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWith(
            isRead: true,
            updatedAt: updatedAt,
          );
        });
      }
    }
  }

  void _onMessageReactedReceived(Map<String, dynamic> data) {
    if (mounted) {
      final messageId = data['id'];
      final senderReaction = data['sender_reaction'];
      final receiverReaction = data['receiver_reaction'];
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWith(
            senderReaction: senderReaction,
            receiverReaction: receiverReaction,
            clearSenderReaction: senderReaction == null,
            clearReceiverReaction: receiverReaction == null,
          );
        });
      }
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
          SnackBar(content: Text('Failed to edit message.')),
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
    _scrollToBottomForced();

    // Play send sound
    if (_playSounds) {
      try {
        _audioPlayer.play(AssetSource('sounds/msgsound.mp3'));
      } catch (e) {
        print('Error playing send sound: $e');
      }
    }

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
        SnackBar(content: Text('Failed to send message.')),
      );
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg.id == -1 && msg.content == text);
        });
      }
    }
  }

  void _showReactionSheet(Message message) {
    setState(() {
      _activeReactionMessage = message;
    });
  }

  Widget _buildReactionOverlay() {
    final message = _activeReactionMessage!;
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🙏', '🔥', '🎉'];
    final bool isMe = message.senderId == _currentUserId;
    final String? myCurrentReaction = isMe ? message.senderReaction : message.receiverReaction;

    return Stack(
      children: [
        // Backdrop tap area to dismiss
        GestureDetector(
          onTap: () {
            setState(() {
              _activeReactionMessage = null;
            });
          },
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
        ),
        // Floating menu card
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEF).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
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
                const SizedBox(height: 16),
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
                          setState(() {
                            _activeReactionMessage = null;
                          });
                          _showFullEmojiPicker(message);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      );
                    }
                    final emoji = emojis[index];
                    return GestureDetector(
                      onTap: () async {
                        setState(() {
                          _activeReactionMessage = null;
                        });
                        
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
                              color: Colors.black.withValues(alpha: 0.04),
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
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _activeReactionMessage = null;
                      });
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
                    child: Text(
                      'Remove Reaction',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (message.senderId == _currentUserId) ...[
                  const Divider(color: Color(0xFFF1D6DB), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _startEditingMessage(message);
                        },
                        icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                        label: const Text('Edit', style: TextStyle(color: Color(0xFF2C1820), fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _confirmUnsendMessage(message);
                        },
                        icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                        label: Text('Unsend', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Scroll to bottom only if user is currently near the bottom.
  /// Used for new incoming messages — respects user's scroll position.
  void _scrollToBottom() {
    if (!_isUserNearBottom) return;
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

  /// Always scroll to bottom regardless of position.
  /// Used only for initial load and when user sends a message.
  void _scrollToBottomForced() {
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

  bool _shouldShowHeader(int index) {
    if (_isSearching && _searchQuery.isNotEmpty) return false;
    if (index == 0) {
      return true;
    }
    final currentMsg = _messages[index];
    final prevMsg = _messages[index - 1];
    
    final currentLocal = currentMsg.createdAt.toLocal();
    final prevLocal = prevMsg.createdAt.toLocal();
    if (currentLocal.year != prevLocal.year ||
        currentLocal.month != prevLocal.month ||
        currentLocal.day != prevLocal.day) {
      return true;
    }
    
    if (currentMsg.createdAt.difference(prevMsg.createdAt).inMinutes.abs() > 30) {
      return true;
    }
    return false;
  }

  String _formatMessageHeaderDate(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(localDateTime.year, localDateTime.month, localDateTime.day);

    final timeStr = DateFormat('h:mm a').format(localDateTime);

    if (targetDate == today) {
      return 'TODAY, $timeStr';
    } else if (targetDate == yesterday) {
      return 'YESTERDAY, $timeStr';
    } else if (now.difference(localDateTime).inDays < 7) {
      final dayName = DateFormat('EEE').format(localDateTime).toUpperCase();
      return '$dayName, $timeStr';
    } else {
      final dateStr = DateFormat('MMM d').format(localDateTime).toUpperCase();
      return '$dateStr, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _isSearching
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                    _searchResultIndices = [];
                    _currentSearchResultIndex = -1;
                    _highlightedMessageId = null;
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: Color(0xFF2C1820)),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Color(0xFF8E717D)),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) {
                  _performSearch(val);
                },
                onChanged: (val) {
                  if (_searchResultIndices.isNotEmpty) {
                    setState(() {
                      _searchResultIndices = [];
                      _currentSearchResultIndex = -1;
                      _highlightedMessageId = null;
                    });
                  }
                },
              ),
              actions: [
                if (_searchResultIndices.isNotEmpty) ...[
                  Center(
                    child: Text(
                      '${_currentSearchResultIndex + 1}/${_searchResultIndices.length}',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_up_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: _searchPrev,
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: _searchNext,
                  ),
                ],
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _searchResultIndices = [];
                      _currentSearchResultIndex = -1;
                      _highlightedMessageId = null;
                    });
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFFFECEF),
                    child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _partner != null ? _partner!['name'] : 'My Love',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1820),
                          ),
                        ),
                        _isPartnerTyping
                            ? Text(
                                'typing...',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.primary,
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
                                      color: _isPartnerOnline ? Color(0xFF10B981) : Color(0xFF9CA3AF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _isPartnerOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _isPartnerOnline ? Color(0xFF10B981) : Color(0xFF8E717D),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Color(0xFFFFECEF),
                  onSelected: (value) {
                    if (value == 'clear_chat') {
                      _confirmClearChatHistory();
                    } else if (value == 'search_chat') {
                      setState(() {
                        _isSearching = true;
                      });
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'search_chat',
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Search Messages', style: TextStyle(color: Color(0xFF2C1820), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'clear_chat',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Clear Chat History', style: TextStyle(color: Color(0xFF2C1820), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.only(
                          left: 16, right: 16, top: 16, bottom: 8),
                        itemCount: _messages.length,
                        // ValueKey prevents layout jerk when new messages arrive
                        itemBuilder: (context, index) {
                          final chronoIndex = _messages.length - 1 - index;
                          final message = _messages[chronoIndex];
                          final isMe = message.senderId == _currentUserId;
                          final showHeader = _shouldShowHeader(chronoIndex);
                          final showUnreadDivider = !_isSearching && (chronoIndex == _firstUnreadChronoIndex);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showHeader) ...[
                                SizedBox(height: 24),
                                Center(
                                  child: Text(
                                    _formatMessageHeaderDate(message.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8E717D).withValues(alpha: 0.5),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              if (showUnreadDivider) ...[
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                        thickness: 1,
                                        indent: 16,
                                        endIndent: 8,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFFF0F3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Color(0xFFFFD1DC),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'UNREAD MESSAGES',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context).colorScheme.primary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                        thickness: 1,
                                        indent: 8,
                                        endIndent: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                              ],
                              KeyedSubtree(
                                key: ValueKey(message.id),
                                child: _buildMessageBubble(message, isMe),
                              ),
                            ],
                          );
                        },
                      ),
                      // ─── New message floating banner ───────────────────
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                          child: _unreadCount > 0
                              ? GestureDetector(
                                  key: const ValueKey('banner'),
                                  onTap: () {
                                    setState(() => _unreadCount = 0);
                                    _scrollToBottomForced();
                                  },
                                  child: Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.primary
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.arrow_downward,
                                              color: Colors.white, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            _unreadCount == 1
                                                ? '1 new message'
                                                : '$_unreadCount new messages',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMessageInput(),
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom,
                ),
              ],
            ),
            if (_activeReactionMessage != null)
              _buildReactionOverlay(),
          ],
        ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final isSending = message.id == -1;

    final IconData statusIcon;
    final Color statusColor;
    final String statusText;

    if (isSending) {
      statusIcon = Icons.access_time_rounded;
      statusColor = const Color(0xFF8E717D);
      statusText = 'Sending';
    } else if (message.isRead) {
      statusIcon = Icons.done_all_rounded;
      statusColor = Theme.of(context).colorScheme.primary;
      if (message.updatedAt != null) {
        final seenTimeStr = DateFormat('h:mm a').format(message.updatedAt!.toLocal());
        statusText = 'Seen $seenTimeStr';
      } else {
        statusText = 'Seen';
      }
    } else if (_isPartnerOnline) {
      statusIcon = Icons.done_all_rounded;
      statusColor = const Color(0xFF8E717D);
      statusText = 'Received';
    } else {
      statusIcon = Icons.done_rounded;
      statusColor = const Color(0xFF8E717D);
      statusText = 'Sent';
    }

    return SwipeToReply(
      onReply: () {
        setState(() {
          _replyingToMessage = message;
        });
      },
      child: Opacity(
        opacity: isSending ? 0.6 : 1.0,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(0xFFFFECEF),
                      child: Icon(Icons.person_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                    ),
                    SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onLongPress: isSending
                        ? null
                        : () {
                            _showReactionSheet(message);
                          },
                    onDoubleTap: isSending
                        ? null
                        : () async {
                            final String? myReaction = isMe ? message.senderReaction : message.receiverReaction;
                            final isRemoving = myReaction == '❤️';
                            
                            // Optimistic update
                            setState(() {
                              _messages = _messages.map((msg) {
                                if (msg.id == message.id) {
                                  if (isMe) {
                                    return msg.copyWith(
                                      senderReaction: isRemoving ? null : '❤️',
                                      clearSenderReaction: isRemoving,
                                    );
                                  } else {
                                    return msg.copyWith(
                                      receiverReaction: isRemoving ? null : '❤️',
                                      clearReceiverReaction: isRemoving,
                                    );
                                  }
                                }
                                return msg;
                              }).toList();
                            });

                            try {
                              await ApiService.instance.reactToMessage(message.id, isRemoving ? null : '❤️');
                            } catch (e) {
                              print('Error reacting: $e');
                            }
                          },
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
                            color: isMe ? Theme.of(context).colorScheme.primary : Color(0xFFFFE3E8),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: message.id == _highlightedMessageId
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.replyTo != null) ...[
                                _buildBubbleReplyPreview(message.replyTo!, isMe),
                                SizedBox(height: 8),
                              ],
                              Text(
                                message.content,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Color(0xFF2C1820),
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
                              onTap: () {
                                _messageFocusNode.unfocus();
                                _showReactionDetailsSheet(message);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFFF1D6DB), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
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
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    if (message.senderReaction != null && message.receiverReaction != null)
                                      SizedBox(width: 4),
                                    if (message.receiverReaction != null)
                                      Text(
                                        message.receiverReaction!,
                                        style: TextStyle(fontSize: 14),
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
              SizedBox(height: 4),
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
                      style: TextStyle(fontSize: 9, color: Color(0xFF8E717D)),
                    ),
                    if (isMe) ...[
                      SizedBox(width: 4),
                      Icon(
                        statusIcon,
                        size: 11,
                        color: statusColor,
                      ),
                      SizedBox(width: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Type your heart...',
                      hintStyle: TextStyle(color: Colors.black26),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: ElevatedButton(
                    onPressed: _isTextEmpty ? null : _handleSendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('Send Love', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(width: 4),
                      Icon(Icons.auto_awesome_rounded, size: 12),
                    ],
                  ),
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
    if (_replyingToMessage == null) return SizedBox.shrink();
    
    final isMe = _replyingToMessage!.senderId == _currentUserId;
    final senderName = isMe ? 'You' : (_partner != null ? _partner!['name'] : 'My Love');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFFFF0F3),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _replyingToMessage!.content,
                  style: TextStyle(
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
            icon: Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E717D)),
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
    if (_editingMessage == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFFFF0F3),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _editingMessage!.content,
                  style: TextStyle(
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
            icon: Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E717D)),
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
    
    final barColor = isMeBubble ? Colors.white70 : Theme.of(context).colorScheme.primary;
    final titleColor = isMeBubble ? Colors.white.withValues(alpha: 0.9) : Theme.of(context).colorScheme.primary;
    final contentColor = isMeBubble ? Colors.white70 : Color(0xFF8E717D);
    final bgColor = isMeBubble ? Colors.white.withValues(alpha: 0.12) : Color(0xFFFFF0F3);

    return Container(
      width: double.infinity, // Expand to fill bubble width
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            SizedBox(width: 8),
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
                  SizedBox(height: 2),
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
      _activeReactionMessage = null;
      _editingMessage = message;
      _replyingToMessage = null;
      _messageController.text = message.content;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final matches = <int>[];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].content.toLowerCase().contains(query.toLowerCase())) {
        matches.add(i); // stores chronoIndex (0 is oldest, length-1 is newest)
      }
    }

    setState(() {
      _searchResultIndices = matches;
      if (matches.isNotEmpty) {
        // Start with the most recent match (which is the last element in matches)
        _currentSearchResultIndex = matches.length - 1;
        _navigateToSearchResult();
      } else {
        _currentSearchResultIndex = -1;
        _highlightedMessageId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching messages found.'), duration: Duration(seconds: 1)),
        );
      }
    });
  }

  void _navigateToSearchResult() {
    if (_currentSearchResultIndex < 0 || _currentSearchResultIndex >= _searchResultIndices.length) return;
    final chronoIndex = _searchResultIndices[_currentSearchResultIndex];
    final listViewIndex = _messages.length - 1 - chronoIndex;
    
    // Estimate 90 pixels per message
    final targetOffset = listViewIndex * 90.0;
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }

    final matchedMessageId = _messages[chronoIndex].id;
    setState(() {
      _highlightedMessageId = matchedMessageId;
    });

    // Fade out highlight after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedMessageId == matchedMessageId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _searchPrev() {
    if (_searchResultIndices.isEmpty) return;
    setState(() {
      // Go to older messages (lower chronoIndex, which is earlier in the matches array)
      if (_currentSearchResultIndex > 0) {
        _currentSearchResultIndex--;
      } else {
        _currentSearchResultIndex = _searchResultIndices.length - 1; // Wrap around to newest
      }
      _navigateToSearchResult();
    });
  }

  void _searchNext() {
    if (_searchResultIndices.isEmpty) return;
    setState(() {
      // Go to newer messages (higher chronoIndex, which is later in the matches array)
      if (_currentSearchResultIndex < _searchResultIndices.length - 1) {
        _currentSearchResultIndex++;
      } else {
        _currentSearchResultIndex = 0; // Wrap around to oldest
      }
      _navigateToSearchResult();
    });
  }

  void _confirmUnsendMessage(Message message) {
    setState(() {
      _activeReactionMessage = null;
    });
    _messageFocusNode.unfocus();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFFECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unsend message?',
            style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will permanently delete this message for everyone in the chat.',
            style: TextStyle(color: Color(0xFF2C1820)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF8E717D))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unsendMessage(message);
              },
              child: Text('Unsend', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
        SnackBar(content: Text('Failed to unsend message.')),
      );
      if (mounted) {
        setState(() {
          _messages = originalMessages;
        });
      }
    }
  }

  void _confirmClearChatHistory() {
    _messageFocusNode.unfocus();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFFECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Clear chat history?',
            style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will clear your chat history on this device. Your partner will still be able to see it.',
            style: TextStyle(color: Color(0xFF2C1820)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF8E717D))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearChatHistory();
              },
              child: Text('Clear', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearChatHistory() async {
    final originalMessages = List<Message>.from(_messages);
    setState(() {
      _messages.clear();
    });
    try {
      await ApiService.instance.clearChatHistory();
    } catch (e) {
      print('Error clearing chat history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear chat history.')),
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
      backgroundColor: Color(0xFFFFECEF),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
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
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'React with any emoji',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    children: categories.entries.map((entry) {
                      final categoryName = entry.key;
                      final emojiList = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: TextStyle(fontSize: 18),
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
    _messageFocusNode.unfocus();
    final bool isMe = message.senderId == _currentUserId;
    final String? myReaction = isMe ? message.senderReaction : message.receiverReaction;
    final String? partnerReaction = isMe ? message.receiverReaction : message.senderReaction;
    final String partnerName = _partner != null ? _partner!['name'] : 'My Love';

    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFFFFECEF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reactions',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1820),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              
              // Partner's Reaction Item
              if (partnerReaction != null) ...[
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      partnerReaction,
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                  title: Text(
                    partnerName,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
                  ),
                  subtitle: Text('Partner', style: TextStyle(fontSize: 11, color: Color(0xFF8E717D))),
                ),
                Divider(color: Color(0xFFF1D6DB), height: 16),
              ],

              // User's Reaction Item
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    myReaction ?? '➕',
                    style: TextStyle(fontSize: myReaction != null ? 22 : 18, color: myReaction == null ? Theme.of(context).colorScheme.primary : null),
                  ),
                ),
                title: Text(
                  myReaction != null ? 'You' : 'React to message',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: myReaction != null ? Color(0xFF2C1820) : Theme.of(context).colorScheme.primary,
                  ),
                ),
                subtitle: Text(
                  myReaction != null ? 'Tap to remove' : 'Choose an emoji',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
                ),
                trailing: myReaction != null
                    ? IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.primary),
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
              SizedBox(height: 12),
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
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<double> _offsetNotifier = ValueNotifier<double>(0.0);
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        _offsetNotifier.value = _offsetNotifier.value * (1 - _controller.value);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _offsetNotifier.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 0 || _offsetNotifier.value > 0) {
      final double newOffset = (_offsetNotifier.value + details.primaryDelta!).clamp(0.0, 90.0);
      _offsetNotifier.value = newOffset;
      
      final bool reached = newOffset >= 60.0;
      if (reached != _thresholdReached) {
        setState(() {
          _thresholdReached = reached;
        });
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
    }
    setState(() {
      _thresholdReached = false;
    });
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
          ValueListenableBuilder<double>(
            valueListenable: _offsetNotifier,
            builder: (context, dragOffset, child) {
              if (dragOffset <= 0) return const SizedBox.shrink();
              return Positioned(
                left: 12,
                child: Opacity(
                  opacity: (dragOffset / 60.0).clamp(0.0, 1.0),
                  child: AnimatedScale(
                    scale: _thresholdReached ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFECEF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<double>(
            valueListenable: _offsetNotifier,
            builder: (context, dragOffset, child) {
              return Transform.translate(
                offset: Offset(dragOffset, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
