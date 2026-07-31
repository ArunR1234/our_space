import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../main.dart';

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
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _chatSoundsEnabled = prefs.getBool('play_chat_sounds') ?? true;
        _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      });
    }
  }

  Future<void> _toggleNotifications(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', val);
    if (mounted) {
      setState(() {
        _notificationsEnabled = val;
      });
    }
    try {
      if (val) {
        final messaging = FirebaseMessaging.instance;
        final String? token = await messaging.getToken();
        if (token != null) {
          await ApiService.instance.updateFcmToken(token);
        }
      } else {
        await ApiService.instance.updateFcmToken(null);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling notifications: $e');
      }
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

  void _showDevicesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFECEF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: FutureBuilder<List<dynamic>>(
                future: ApiService.instance.getDevices(),
                builder: (context, snapshot) {
                  Widget body;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    body = const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    body = Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Failed to load devices: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    body = const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('No active devices found.'),
                      ),
                    );
                  } else {
                    final devices = snapshot.data!;
                    final currentDevice = devices.firstWhere((d) => d['is_current'] == true, orElse: () => null);
                    final otherDevices = devices.where((d) => d['is_current'] != true).toList();

                    body = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentDevice != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            child: Text(
                              'CURRENT SESSION',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8E717D), letterSpacing: 0.8),
                            ),
                          ),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Color(0xFFFFECEF), shape: BoxShape.circle),
                                child: Icon(Icons.phone_android_rounded, color: Theme.of(context).colorScheme.primary),
                              ),
                              title: Text(currentDevice['name'] ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Active now', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'OTHER ACTIVE SESSIONS (${otherDevices.length})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8E717D), letterSpacing: 0.8),
                              ),
                              if (otherDevices.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(0xFFFFECEF),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Log out from others?', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
                                        content: const Text('This will log you out from all other devices.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E717D)))),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await ApiService.instance.logoutOtherDevices();
                                        setStateSheet(() {});
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error logging out: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Text(
                                    'Log out all others',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (otherDevices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                'No other active devices',
                                style: TextStyle(color: Color(0xFF8E717D), fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.4,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: otherDevices.length,
                              itemBuilder: (ctx, index) {
                                final device = otherDevices[index];
                                final lastActive = device['last_used_at'] != null
                                    ? DateTime.parse(device['last_used_at']).toLocal()
                                    : null;
                                final lastActiveStr = lastActive != null
                                    ? 'Active: ${DateFormat('MMM d, h:mm a').format(lastActive)}'
                                    : 'Active time unknown';

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(color: Color(0xFFFFECEF), shape: BoxShape.circle),
                                      child: const Icon(Icons.devices_other_rounded, color: Color(0xFF8E717D)),
                                    ),
                                    title: Text(device['name'] ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(lastActiveStr, style: const TextStyle(fontSize: 11, color: Color(0xFF8E717D))),
                                    trailing: IconButton(
                                      icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.primary),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(0xFFFFECEF),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text('Log out device?', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
                                            content: Text('Are you sure you want to log out from ${device['name'] ?? 'this device'}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E717D)))),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await ApiService.instance.logoutDevice(device['id']);
                                            setStateSheet(() {});
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error logging out: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const Text(
                        'Logged-in Devices',
                        style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'These are the phones, tablets, or computers currently logged into your account. You can log out of any device to protect your account security.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8E717D), height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      body,
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out from journey?', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from Our Space?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E717D))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                    children: [
                      // Notifications switch
                      SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
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
                      Divider(height: 1),
                      ListTile(
                        onTap: _showDevicesBottomSheet,
                        leading: const Icon(Icons.devices_rounded, color: Color(0xFF8E717D)),
                        title: const Text('Logged-in Devices'),
                        subtitle: const Text('Manage your active sessions'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF8E717D)),
                      ),
                    ],
                  ),
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
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
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
