import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
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
      // If token expired or network failed, fallback to WelcomeScreen
      await ApiService.instance.logout();
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
          _checkingAuth = false;
        });
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

// ─────────────────── PIN LOCK SCREEN ───────────────────
class PinLockScreen extends StatefulWidget {
  final String correctPin;
  final Widget destination;
  const PinLockScreen({super.key, required this.correctPin, required this.destination});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitEntered(String val, int index) {
    if (val.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-check when 4th digit entered
    if (index == 3 && val.isNotEmpty) {
      final entered = _controllers.map((c) => c.text).join();
      if (entered.length == 4) _checkPin(entered);
    }
  }

  void _checkPin(String entered) {
    if (entered == widget.correctPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.destination),
      );
    } else {
      _shakeController.forward(from: 0);
      setState(() => _hasError = true);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _hasError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 40, color: primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Our Space',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.bold, color: primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your 4-digit PIN to continue',
                  style: TextStyle(color: const Color(0xFF8E717D), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // PIN boxes with shake animation
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final dx = _shakeController.isAnimating
                        ? 12.0 * (0.5 - _shakeAnimation.value).abs() * (_shakeAnimation.value < 0.5 ? 1 : -1)
                        : 0.0;
                    return Transform.translate(offset: Offset(dx * 4, 0), child: child);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (i) => _buildPinBox(i, primary)),
                  ),
                ),
                const SizedBox(height: 16),
                // Error message
                AnimatedOpacity(
                  opacity: _hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '❌ Incorrect PIN. Try again.',
                    style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(int index, Color primary) {
    return Container(
      width: 56, height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _hasError ? Colors.red.shade300 : primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
        decoration: const InputDecoration(counterText: '', border: InputBorder.none),
        onChanged: (val) => _onDigitEntered(val, index),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _setupPendingPartnerListener();
    _requestNotificationPermission();
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
      _fcmMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && _currentIndex != 1) {
          _showLocalNotification(
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

  Future<void> _showLocalNotification(String title, String body) async {
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
      0,
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
          await ApiService.instance.updateFcmToken(newToken);
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

  void _onGlobalMessageSentReceived(Map<String, dynamic> data) {
    if (_globalUserId == null) return;
    final int senderId = data['sender_id'] ?? 0;
    
    // Only notify if the message is from our partner and we are not currently on the chat tab
    if (senderId != _globalUserId && _currentIndex != 1) {
      final String senderName = data['sender']?['name'] ?? 'Your Partner';
      final String content = data['content'] ?? 'Sent a message';
      
      _showLocalNotification(senderName, content);
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
      body: _screens[_currentIndex],
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _chatSoundsEnabled = true;
  bool _showPreviews = true;
  bool _appLockEnabled = false;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _chatSoundsEnabled = prefs.getBool('play_chat_sounds') ?? true;
        _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      });
    }
  }

  Future<void> _toggleChatSounds(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('play_chat_sounds', val);
    if (mounted) {
      setState(() {
        _chatSoundsEnabled = val;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final status = await ApiService.instance.getUserStatus();
      if (mounted) {
        setState(() {
          _user = status['user'];
          _showPreviews = _user?['show_previews'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleShowPreviews(bool val) async {
    setState(() {
      _showPreviews = val;
    });
    try {
      await ApiService.instance.updatePreferences(val);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  Future<void> _showAppPasswordDialog({bool isChanging = false}) async {
    final primary = Theme.of(context).colorScheme.primary;
    final pinControllers = List.generate(4, (_) => TextEditingController());
    final confirmControllers = List.generate(4, (_) => TextEditingController());
    final pinFocusNodes = List.generate(4, (_) => FocusNode());
    final confirmFocusNodes = List.generate(4, (_) => FocusNode());
    String enteredPin = '';
    String confirmedPin = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onPinChanged(String val, int index, List<TextEditingController> ctrls, List<FocusNode> nodes, bool isConfirm) {
            if (val.length == 1) {
              if (index < 3) nodes[index + 1].requestFocus();
              if (!isConfirm) enteredPin = ctrls.map((c) => c.text).join();
              if (isConfirm) confirmedPin = ctrls.map((c) => c.text).join();
            }
          }

          Widget buildPinBox(int index, List<TextEditingController> ctrls, List<FocusNode> nodes, bool isConfirm) {
            return Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: TextField(
                controller: ctrls[index],
                focusNode: nodes[index],
                keyboardType: TextInputType.number,
                maxLength: 1,
                obscureText: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (val) => onPinChanged(val, index, ctrls, nodes, isConfirm),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isChanging ? 'Change App Password' : 'Set App Password',
              style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: primary),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter a 4-digit PIN to lock this app.',
                    style: TextStyle(color: const Color(0xFF8E717D), fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Text('New PIN', style: TextStyle(fontWeight: FontWeight.w600, color: primary, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (i) => buildPinBox(i, pinControllers, pinFocusNodes, false)),
                ),
                const SizedBox(height: 16),
                Text('Confirm PIN', style: TextStyle(fontWeight: FontWeight.w600, color: primary, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (i) => buildPinBox(i, confirmControllers, confirmFocusNodes, true)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: const Color(0xFF8E717D))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  enteredPin = pinControllers.map((c) => c.text).join();
                  confirmedPin = confirmControllers.map((c) => c.text).join();
                  if (enteredPin.length == 4 && enteredPin == confirmedPin) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_pin', enteredPin);
                    await prefs.setBool('app_lock_enabled', true);
                    if (mounted) setState(() { _appLockEnabled = true; });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('App password set! 🔒'), backgroundColor: primary),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('PINs do not match or incomplete.')),
                    );
                  }
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );

    for (final c in [...pinControllers, ...confirmControllers]) {
      c.dispose();
    }
    for (final f in [...pinFocusNodes, ...confirmFocusNodes]) {
      f.dispose();
    }
  }

  Future<void> _toggleAppLock(bool val) async {
    if (val) {
      await _showAppPasswordDialog();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_lock_enabled', false);
      await prefs.remove('app_pin');
      if (mounted) setState(() { _appLockEnabled = false; });
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.instance.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Widget _buildThemeCircle(String themeName, Color color) {
    final isSelected = OurSpaceApp.themeNotifier.value == themeName;
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_theme', themeName);
        OurSpaceApp.themeNotifier.value = themeName;
        setState(() {});
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isSelected
            ? Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            )
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // Profile summary card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF0F3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _user?['avatar'] ?? '🐱',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?['name'] ?? 'Guest User',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C1820),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _user?['email'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E717D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Preferences section
                Text(
                  'PREFERENCES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Notifications switch
                      SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() {
                            _notificationsEnabled = val;
                          });
                        },
                        title: Text('Push Notifications'),
                        subtitle: Text('Receive notifications for new messages'),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        secondary: Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      Divider(height: 1),
                      // Show Previews Switch
                      SwitchListTile(
                        value: _showPreviews,
                        onChanged: _toggleShowPreviews,
                        title: Text('Show Message Previews'),
                        subtitle: Text('Show message content in notification banners'),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        secondary: Icon(
                          Icons.visibility_rounded,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      Divider(height: 1),
                      // Message Sounds Switch
                      SwitchListTile(
                        value: _chatSoundsEnabled,
                        onChanged: _toggleChatSounds,
                        title: Text('Message Sounds'),
                        subtitle: Text('Play sound on sending and receiving messages'),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        secondary: Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      Divider(height: 1),
                      // App Password
                      SwitchListTile(
                        value: _appLockEnabled,
                        onChanged: _toggleAppLock,
                        title: Text('App Password'),
                        subtitle: Text(_appLockEnabled ? 'PIN lock is active • tap to change' : 'Lock app with a 4-digit PIN'),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        secondary: Icon(
                          Icons.lock_rounded,
                          color: const Color(0xFF8E717D),
                        ),
                      ),
                      // Change PIN shortcut when enabled
                      if (_appLockEnabled) ...[
                        Divider(height: 1),
                        ListTile(
                          onTap: () => _showAppPasswordDialog(isChanging: true),
                          leading: Icon(Icons.edit_rounded, color: const Color(0xFF8E717D)),
                          title: Text('Change App Password'),
                          subtitle: Text('Update your 4-digit PIN'),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: const Color(0xFF8E717D)),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Theme selection section
                Text(
                  'THEME COLOR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildThemeCircle('crimson', Theme.of(context).colorScheme.primary),
                      _buildThemeCircle('rose', Color(0xFFD85A7F)),
                      _buildThemeCircle('purple', Color(0xFF6B2D5C)),
                      _buildThemeCircle('blue', Color(0xFF1A365D)),
                      _buildThemeCircle('green', Color(0xFF1B4332)),
                      _buildThemeCircle('amber', Color(0xFFB57C1E)),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // Account section
                Text(
                  'ACCOUNT CONTROLS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                // Logout Button Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListTile(
                    onTap: _handleLogout,
                    leading: Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Sign out from this device'),
                  ),
                ),
                SizedBox(height: 40),

                // Version display
                Center(
                  child: Text(
                    'Our Space v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E717D),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Profile Screen with Account Details
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _partner;
  String? _anniversaryDate;
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = '💖';
  final List<String> _avatars = [
    // Hearts
    '💖', '❤️', '💜', '💙', '💚', '💝', '💘', '💕',
    // Flowers
    '🌸', '🌹', '🌷', '🌺',
    // Chocolates & Sweets
    '🍫', '🍩', '🧁', '🍭',
    // Animals (No Yellow/Orange/Brown faces)
    '🐰', '🐼', '🐨', '🐙', '🦄', '🐸', '🐳', '🦋'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final status = await ApiService.instance.getUserStatus();
      if (mounted) {
        setState(() {
          _user = status['user'];
          _partner = status['partner'];
          _anniversaryDate = status['relationship']?['anniversary_date'];
          _nameController.text = _user?['name'] ?? '';
          _selectedAvatar = _user?['avatar'] ?? '💖';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _handleLogout() async {
    WebSocketService.instance.disconnect();
    await ApiService.instance.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  int _calculateDaysTogether(String? anniversaryStr) {
    if (anniversaryStr == null) return 0;
    try {
      final anniversary = DateTime.parse(anniversaryStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final annivDate = DateTime(anniversary.year, anniversary.month, anniversary.day);
      return today.difference(annivDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  String _formatAnniversaryDate(String? dateStr) {
    if (dateStr == null) return 'Not set yet';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _selectAnniversaryDate() async {
    final initialDate = _anniversaryDate != null
        ? DateTime.tryParse(_anniversaryDate!) ?? DateTime.now()
        : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C1820),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _isLoading = true;
      });
      try {
        await ApiService.instance.updateAnniversaryDate(formattedDate);
        setState(() {
          _anniversaryDate = formattedDate;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anniversary date updated!')),
        );
      } catch (e) {
        print('Error saving anniversary: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update anniversary date.')),
        );
      }
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Your Avatar',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  height: 280,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _avatars.length,
                    itemBuilder: (context, index) {
                      final avatar = _avatars[index];
                      final isSelected = _selectedAvatar == avatar;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _updateAvatar(avatar);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Color(0xFFFFECEF) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatar,
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateAvatar(String avatar) async {
    setState(() {
      _selectedAvatar = avatar;
      _isLoading = true;
    });

    try {
      final name = _user?['name'] ?? '';
      final res = await ApiService.instance.updateProfile(name, avatar);
      if (mounted) {
        setState(() {
          _user = res['user'];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar updated successfully!')),
        );
      }
    } catch (e) {
      print('Error updating avatar: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar')),
        );
      }
    }
  }

  void _showRenameDialog() {
    _nameController.text = _user?['name'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,   // lets the sheet resize above the keyboard
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return Padding(
          // This is the key: adds padding equal to keyboard height
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFECEF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E717D).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Edit Display Name',
                  style: TextStyle(fontFamily: 'Georgia', color: const Color(0xFF2C1820), fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter your name...',
                    hintStyle: TextStyle(color: const Color(0xFF8E717D).withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF2C1820), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8E717D),
                          side: const BorderSide(color: Color(0xFF8E717D)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _saveProfile();
                        },
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService.instance.updateProfile(name, _selectedAvatar);
      if (mounted) {
        setState(() {
          _user = res['user'];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name updated successfully!')),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Our Account', style: TextStyle(fontFamily: 'Georgia', color: primary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: primary),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))
          : Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  // User details
                  _buildProfileCard(
                    title: 'My Profile',
                    name: _user?['name'] ?? 'Me',
                    email: _user?['email'] ?? '',
                    avatar: _user?['avatar'] ?? '💖',
                    icon: Icons.person_rounded,
                    isMe: true,
                  ),
                  SizedBox(height: 20),
                  // Partner details
                  _buildProfileCard(
                    title: 'My Partner',
                    name: _partner?['name'] ?? 'Waiting...',
                    email: _partner?['email'] ?? 'Not paired yet',
                    avatar: _partner?['avatar'],
                    icon: Icons.favorite_rounded,
                    accentColor: Theme.of(context).colorScheme.primary,
                    isMe: false,
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 36,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '${_calculateDaysTogether(_anniversaryDate)} Days',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1820),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'OF TOGETHERNESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8E717D),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 14),
                        Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), thickness: 1),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ANNIVERSARY DATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8E717D),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatAnniversaryDate(_anniversaryDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C1820),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _selectAnniversaryDate,
                              icon: Icon(Icons.edit_calendar_rounded, size: 14),
                              label: Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                backgroundColor: Color(0xFFFFECEF),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Logout from Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String name,
    required String email,
    IconData? icon,
    String? avatar,
    Color accentColor = const Color(0xFF8E717D),
    bool isMe = false,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          isMe
              ? GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFFFECEF),
                        child: avatar != null && avatar.isNotEmpty
                            ? Text(avatar, style: TextStyle(fontSize: 28))
                            : Icon(icon, color: accentColor, size: 28),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFFFECEF),
                  child: avatar != null && avatar.isNotEmpty
                      ? Text(avatar, style: TextStyle(fontSize: 28))
                      : Icon(icon, color: accentColor, size: 28),
                ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8E717D), letterSpacing: 1.0),
                ),
                SizedBox(height: 4),
                isMe
                    ? GestureDetector(
                        onTap: _showRenameDialog,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C1820),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        name,
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
                      ),
                SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E717D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
