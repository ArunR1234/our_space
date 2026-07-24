import 'dart:async';
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
  String? _pendingPartnerEmail;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
    // Start polling to detect if partner registers
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkCurrentStatus(silent: true));
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final status = await ApiService.instance.getUserStatus();
      final relationship = status['relationship'];
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (relationship != null) {
          if (relationship['user_two_id'] != null) {
            // Pairing completed! Go to home.
            _statusPollTimer?.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationShell()),
            );
          } else {
            // Pairing pending
            setState(() {
              _pendingPartnerEmail = relationship['pending_partner_email'];
            });
          }
        }
      }
    } catch (e) {
      print('Error polling pairing status: $e');
    }
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
        
        setState(() {
          _pendingPartnerEmail = partnerEmail;
        });

        if (partner != null) {
          // Partner already exists and is linked!
          _statusPollTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected successfully!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationShell()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection request sent!')),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    _statusPollTimer?.cancel();
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFEAEE), // Soft rose pink
              Color(0xFFFFF5F7), // Gentle white-pink
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFB5003F), size: 18),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Color(0xFFB5003F), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 64,
                    color: Color(0xFFB5003F),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text(
                  'Connect with Your Partner',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                const Text(
                  'Enter your partner\'s email to connect your hearts. Once paired, you can share real-time messages and date plans.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E717D),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                if (_pendingPartnerEmail != null) ...[
                  // Waiting box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for $_pendingPartnerEmail to join...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5003F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ask your partner to register with this email to automatically link your accounts.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E717D),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Input Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF8E717D)),
                            hintText: 'partner@aura.com',
                            hintStyle: const TextStyle(color: Colors.black26),
                            filled: true,
                            fillColor: const Color(0xFFFFF5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFB5003F), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB5003F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Connect Hearts', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(Icons.favorite_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
