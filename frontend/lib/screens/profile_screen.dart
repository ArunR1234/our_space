import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

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
        if (mounted) {
          setState(() {
            _anniversaryDate = formattedDate;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anniversary date updated!')),
          );
        }
      } catch (e) {
        print('Error saving anniversary: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update anniversary date.')),
          );
        }
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return Padding(
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
          : SingleChildScrollView(
              child: Padding(
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
                      avatar: _user?['avatar'] ?? '💖',
                      icon: Icons.person_rounded,
                      isMe: true,
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 10),
                          Text(
                            '${_calculateDaysTogether(_anniversaryDate)} Days',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C1820),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'OF TOGETHERNESS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8E717D),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), thickness: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ANNIVERSARY DATE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8E717D),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatAnniversaryDate(_anniversaryDate),
                                      style: const TextStyle(
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
                                icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                                label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  backgroundColor: const Color(0xFFFFECEF),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
