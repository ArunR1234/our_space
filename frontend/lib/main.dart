import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API service (loads saved authentication token)
  await ApiService.instance.init();

  runApp(const OurSpaceApp());
}

class OurSpaceApp extends StatelessWidget {
  const OurSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Our Space',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB5003F), // Romantic crimson red
          primary: const Color(0xFFB5003F),
          background: const Color(0xFFFFF5F7), // Gentle white-pink background
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820)),
          bodyMedium: TextStyle(color: Color(0xFF2C1820)),
        ),
      ),
      home: const AuthGate(),
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

      if (mounted) {
        setState(() {
          if (relationship == null || relationship['user_two_id'] == null) {
            _targetScreen = const PairingScreen();
          } else {
            _targetScreen = const MainNavigationShell();
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
      return const Scaffold(
        backgroundColor: Color(0xFFFFF5F7),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F)),
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const CallPlaceholderScreen(),
    const ProfileScreen(),
    const CustomizationPlaceholderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFB5003F).withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded),
              _buildNavItem(1, Icons.chat_bubble_rounded),
              _buildNavItem(2, Icons.phone_rounded),
              _buildNavItem(3, Icons.person_rounded),
              _buildNavItem(4, Icons.palette_rounded),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFECEF) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFFB5003F) : const Color(0xFF8E717D),
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
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Voice Calls', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF8A003D), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_rounded, size: 64, color: const Color(0xFFB5003F).withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text(
                'Coming Soon',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
              ),
              const SizedBox(height: 8),
              const Text(
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

// Minimal placeholder screen for Customization Tab
class CustomizationPlaceholderScreen extends StatelessWidget {
  const CustomizationPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Themes', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF8A003D), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.palette_rounded, size: 64, color: const Color(0xFFB5003F).withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text(
                'Theme Customization',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Personalize your chat background, bubble colors, and wallpapers to reflect your unique story.',
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

// Profile Screen with Account Details
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _partner;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final status = await ApiService.instance.getUserStatus();
      if (mounted) {
        setState(() {
          _user = status['user'];
          _partner = status['partner'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.instance.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Our Account', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF8A003D), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F))))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // User details
                  _buildProfileCard(
                    title: 'My Profile',
                    name: _user?['name'] ?? 'Me',
                    email: _user?['email'] ?? '',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 20),
                  // Partner details
                  _buildProfileCard(
                    title: 'My Partner',
                    name: _partner?['name'] ?? 'Waiting...',
                    email: _partner?['email'] ?? 'Not paired yet',
                    icon: Icons.favorite_rounded,
                    accentColor: const Color(0xFFB5003F),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB5003F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Logout from Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String name,
    required String email,
    required IconData icon,
    Color accentColor = const Color(0xFF8E717D),
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB5003F).withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFFECEF),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8E717D), letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C1820)),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E717D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
