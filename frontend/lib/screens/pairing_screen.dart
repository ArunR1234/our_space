import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'login_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await ApiService.instance.getUserStatus();
      final relationship = status['relationship'];
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (relationship != null && relationship['user_two_id'] != null) {
          // Pairing completed! Redirect to home.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationShell()),
          );
        }
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final partnerEmail = _emailController.text.trim();

    if (partnerEmail.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter your partner\'s email.';
      });
      return;
    }

    final result = await ApiService.instance.pairPartner(partnerEmail);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        final data = result['data'];
        final partner = data['partner'];

        if (partner != null) {
          // Partner already exists and is linked!
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected successfully!')),
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationShell()),
            );
          }
        } else {
          // Partner does not exist yet! Show pending popup dialog.
          _showPartnerPendingDialog(partnerEmail);
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    }
  }

  void _showPartnerPendingDialog(String partnerEmail) {
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
                // Heart Icon
                Center(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFECEF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Title
                Text(
                  'Connected Pending',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                
                // Content
                Text(
                  'Your partner ($partnerEmail) has not created an account yet. '
                  'When they create an account, they will connect with you immediately.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E717D),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                
                // Proceed / Enter Button
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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
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
                      'Enter to Explore',
                      style: TextStyle(
                        fontSize: 15,
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _emailController.text.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFEAEE), // Soft rose pink
              Theme.of(context).colorScheme.surface, // Gentle white-pink
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: _handleLogout,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFECEF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.primary, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Icon Header
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFEAEE),
                              Color(0xFFFFCCD5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 44,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  Text(
                    'Connect Hearts',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1820),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 12),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'Enter your partner\'s email to link your accounts. Once connected, you can share messages and plan dates in your private space.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E717D),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: 36),
                  
                  // Input Form
                  Container(
                    padding: EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFECEF).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: Color(0xFF8E717D)),
                            hintText: 'partner@ourspace.com',
                            hintStyle: TextStyle(color: Colors.black26),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        SizedBox(height: 20),
                        
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                        ],
                        
                        Opacity(
                          opacity: _isLoading ? 0.6 : 1.0,
                          child: DecoratedBox(
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
                              onPressed: _isLoading ? null : _handleConnect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Connect Hearts',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.favorite_rounded, size: 16),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 50),
                  
                  // Decorative bottom quote
                  Opacity(
                    opacity: 0.7,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 40, height: 1, color: Color(0xFFFFCCD5)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              child: Icon(
                                Icons.favorite_border_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Container(width: 40, height: 1, color: Color(0xFFFFCCD5)),
                          ],
                        ),
                        SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            '"Two hearts, one shared space. A private sanctuary built exclusively for the two of you to write your own love story."',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF8E717D),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
