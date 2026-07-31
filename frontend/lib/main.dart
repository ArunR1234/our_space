import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'screens/welcome_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/offline_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  // Initialize API service (loads saved authentication token)
  await ApiService.instance.init();
  await OfflineService.instance.init();

  runApp(const OurSpaceApp());
}

class OurSpaceApp extends StatefulWidget {
  const OurSpaceApp({super.key});

  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('crimson');

  @override
  State<OurSpaceApp> createState() => _OurSpaceAppState();
}

class _OurSpaceAppState extends State<OurSpaceApp> {
  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('app_theme') ?? 'crimson';
      OurSpaceApp.themeNotifier.value = savedTheme;
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  ThemeData _getThemeDataForName(String name) {
    Color seedColor;
    Color backgroundColor;
    switch (name) {
      case 'purple':
        seedColor = Color(0xFF6B2D5C);
        backgroundColor = Color(0xFFF9F0F6);
        break;
      case 'blue':
        seedColor = Color(0xFF1A365D);
        backgroundColor = Color(0xFFF0F4F8);
        break;
      case 'green':
        seedColor = Color(0xFF1B4332);
        backgroundColor = Color(0xFFF0F5F2);
        break;
      case 'rose':
        seedColor = Color(0xFFD85A7F);
        backgroundColor = Color(0xFFFFF0F3);
        break;
      case 'amber':
        seedColor = Color(0xFFB57C1E);
        backgroundColor = Color(0xFFFCF8F0);
        break;
      case 'crimson':
      default:
        seedColor = Theme.of(context).colorScheme.primary;
        backgroundColor = Theme.of(context).colorScheme.surface;
        break;
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        primary: seedColor,
        surface: backgroundColor,
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820)),
        bodyMedium: TextStyle(color: Color(0xFF2C1820)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: OurSpaceApp.themeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: 'Our Space',
          debugShowCheckedModeBanner: false,
          theme: _getThemeDataForName(currentTheme),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingAuth = true;
  Widget _targetScreen = const WelcomeScreen();

  @override
  void initState() {
    super.initState();
    _evaluateGate();
  }

  Future<void> _evaluateGate() async {
    if (!ApiService.instance.isAuthenticated) {
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
          _checkingAuth = false;
        });
      }
      return;
    }

    try {
      final status = await ApiService.instance.getUserStatus();
      final relationship = status['relationship'];
      final prefs = await SharedPreferences.getInstance();
      final lockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      final pin = prefs.getString('app_pin');

      if (mounted) {
        setState(() {
          Widget destination;
          if (relationship == null || relationship['user_two_id'] == null) {
            destination = const PairingScreen();
          } else {
            destination = const MainNavigationShell();
          }

          // Wrap with PIN lock if enabled and PIN is set
          if (lockEnabled && pin != null && pin.isNotEmpty) {
            _targetScreen = PinLockScreen(correctPin: pin, destination: destination);
          } else {
            _targetScreen = destination;
          }
          _checkingAuth = false;
        });
      }
    } catch (e) {
      // If network failed but we have a token, do NOT log out automatically.
      final hasToken = ApiService.instance.token != null;
      if (hasToken) {
        final cached = await OfflineService.instance.loadCachedUserStatus();
        if (mounted) {
          setState(() {
            _targetScreen = cached != null && cached['relationship'] != null
                ? const MainNavigationShell()
                : const WelcomeScreen();
            _checkingAuth = false;
          });
        }
      } else {
        await ApiService.instance.logout();
        if (mounted) {
          setState(() {
            _targetScreen = const WelcomeScreen();
            _checkingAuth = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }
    return _targetScreen;
  }
}

// Shell holding the bottom navigation bar and page switching
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  bool _hasShownCongrats = false;
  Timer? _globalHeartbeatTimer;
  int? _globalRelationshipId;
  int? _globalUserId;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _fcmMessageSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;

  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _setupPendingPartnerListener();
    _requestNotificationPermission();
    // Listen for connectivity changes to show/hide banner and flush drafts
    _isOnline = OfflineService.instance.isOnline;
    OfflineService.instance.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final online = OfflineService.instance.isOnline;
    if (online != _isOnline) {
      setState(() => _isOnline = online);
      if (online) {
        // Back online — flush queued drafts
        _flushDraftQueue();
      }
    }
  }

  Future<void> _flushDraftQueue() async {
    final drafts = await OfflineService.instance.getDrafts();
    if (drafts.isEmpty) return;
    
    final List<Map<String, dynamic>> failedDrafts = [];
    for (final draft in drafts) {
      try {
        await ApiService.instance.sendMessage(
          draft['content'] as String,
          replyToId: draft['reply_to_id'] as int?,
        );
      } catch (e) {
        debugPrint('OfflineService: Failed to flush draft: $e');
        failedDrafts.add(draft);
      }
    }
    
    if (failedDrafts.isEmpty) {
      await OfflineService.instance.clearDrafts();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_draft_queue', jsonEncode(failedDrafts));
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (mounted) {
          setState(() {
            _currentIndex = 1; // Switch to Chat tab
          });
        }
      },
    );

    // Listen to foreground FCM push notifications and show local notification banners
    try {
      _fcmMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notification = message.notification;
        if (notification != null && _currentIndex != 1) {
          final prefs = await SharedPreferences.getInstance();
          final bool enabled = prefs.getBool('notifications_enabled') ?? true;
          if (!enabled) return;

          final messageIdStr = message.data['message_id'];
          final messageId = messageIdStr != null ? int.tryParse(messageIdStr) : null;
          final notificationId = messageId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
          _showLocalNotification(
            notificationId,
            notification.title ?? 'New Message',
            notification.body ?? '',
          );
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('FCM foreground listener ignored: $e');
      }
    }
  }

  Future<void> _showLocalNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'relationship_chats',
      'Relationship Chats',
      channelDescription: 'Notifications for new chat messages between partners',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permission: $e');
      }
    }
  }

  @override
  void dispose() {
    _globalHeartbeatTimer?.cancel();
    _globalHeartbeatTimer = null;
    _fcmMessageSubscription?.cancel();
    _fcmTokenRefreshSubscription?.cancel();
    OfflineService.instance.removeListener(_onConnectivityChanged);
    WebSocketService.instance.removeListener('App\\Events\\PartnerConnected', _onPartnerConnected);
    WebSocketService.instance.removeListener('App\\Events\\MessageSent', _onGlobalMessageSentReceived);
    super.dispose();
  }

  Future<void> _setupPendingPartnerListener() async {
    try {
      final status = await ApiService.instance.getUserStatus();
      final relationship = status['relationship'];
      if (relationship != null) {
        final int relationshipId = relationship['id'];
        
        // Always connect to the WebSocket service to support real-time features on all screens
        await WebSocketService.instance.connect(relationshipId);

        // Listen for new messages globally to trigger notifications
        WebSocketService.instance.addListener('App\\Events\\MessageSent', _onGlobalMessageSentReceived);

        // Setup Firebase push token registration
        _setupFcmTokenRegistration();

        // Broadcast online status immediately when user enters the app
        _globalRelationshipId = relationshipId;
        _globalUserId = status['user']?['id']; // Optimized: reuse user status loaded above

        if (_globalUserId != null) {
          // Send initial online ping
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && _globalRelationshipId != null && _globalUserId != null) {
              WebSocketService.instance.triggerClientEvent(
                'client-status',
                _globalRelationshipId!,
                {'status': 'online', 'user_id': _globalUserId},
              );
            }
          });

          // Keep broadcasting online every 15 seconds while app is open
          _globalHeartbeatTimer?.cancel();
          _globalHeartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
            if (mounted && _globalRelationshipId != null && _globalUserId != null) {
              WebSocketService.instance.triggerClientEvent(
                'client-status',
                _globalRelationshipId!,
                {'status': 'online', 'user_id': _globalUserId},
              );
            }
          });
        }

        // If partner is not connected yet, listen for connection
        if (relationship['user_two_id'] == null) {
          WebSocketService.instance.addListener('App\\Events\\PartnerConnected', _onPartnerConnected);
        } else {
          // If partner is already connected, check if we showed the congrats popup yet
          final prefs = await SharedPreferences.getInstance();
          final key = 'seen_pairing_congrats_$relationshipId';
          final seen = prefs.getBool(key) ?? false;
          
          if (!seen && !_hasShownCongrats) {
            final partnerData = status['partner'] ?? {
              'name': 'My Love',
              'email': '',
            };
            _onPartnerConnected({
              'relationship_id': relationshipId,
              'partner': partnerData,
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up pending partner listener: $e');
      }
    }
  }

  Future<void> _setupFcmTokenRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) {
        await ApiService.instance.updateFcmToken(null);
        return;
      }

      final messaging = FirebaseMessaging.instance;
      final String? token = await messaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('FCM Token: $token');
        }
        await ApiService.instance.updateFcmToken(token);
      }

      _fcmTokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) async {
        try {
          final prefsInner = await SharedPreferences.getInstance();
          final bool enabled = prefsInner.getBool('notifications_enabled') ?? true;
          if (enabled) {
            await ApiService.instance.updateFcmToken(newToken);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error updating refreshed FCM token: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('FCM token setup ignored (probably missing Firebase config): $e');
      }
    }
  }

  void _onGlobalMessageSentReceived(Map<String, dynamic> data) async {
    if (_globalUserId == null) return;
    final int senderId = data['sender_id'] ?? 0;
    
    // Only notify if the message is from our partner and we are not currently on the chat tab
    if (senderId != _globalUserId && _currentIndex != 1) {
      final prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) return;

      final String senderName = data['sender']?['name'] ?? 'Your Partner';
      final String content = data['content'] ?? 'Sent a message';
      final int? messageId = data['id'];
      final notificationId = messageId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      _showLocalNotification(notificationId, senderName, content);
    }
  }

  void _onPartnerConnected(Map<String, dynamic> data) async {
    if (!mounted || _hasShownCongrats) return;
    _hasShownCongrats = true;

    final int relationshipId = data['relationship_id'] ?? 0;
    if (relationshipId > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_pairing_congrats_$relationshipId', true);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Heart Stack
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFECEF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.favorite_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Title
                Text(
                  'Hearts Connected!',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                
                // Content
                Text(
                  '${data['partner']['name']} (${data['partner']['email']}) has successfully registered and connected with you!\n\nYour shared sanctuary is now fully active.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E717D),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                
                // Gradient Confirm Button
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      WebSocketService.instance.removeListener('App\\Events\\PartnerConnected', _onPartnerConnected);
                      
                      // Refresh navigation shell state by reloading it
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const CallPlaceholderScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _screens[_currentIndex],
          // ── Offline Banner ──────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            top: _isOnline ? -60 : MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? const Color(0xFF10B981)  // green (back online)
                      : const Color(0xFF374151), // dark grey (offline)
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Back online' : 'No internet connection',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isOnline) ...
                      [
                        const SizedBox(width: 8),
                        const Text(
                          '• Showing cached data',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded),
                    _buildNavItem(1, Icons.chat_bubble_rounded),
                    _buildNavItem(2, Icons.phone_rounded),
                    _buildNavItem(3, Icons.person_rounded),
                    _buildNavItem(4, Icons.settings_rounded),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFFFECEF) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : Color(0xFF8E717D),
          size: 24,
        ),
      ),
    );
  }
}

// Minimal placeholder screen for Calling Tab
class CallPlaceholderScreen extends StatelessWidget {
  const CallPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Voice Calls', style: TextStyle(fontFamily: 'Georgia', color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
              ),
              SizedBox(height: 8),
              Text(
                'Direct voice calls to keep you connected with your love at all times.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E717D), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
