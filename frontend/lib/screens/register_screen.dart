import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pairing_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.instance.register(name, email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Direct to Pairing screen since it's a new registration and unpaired
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PairingScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Title
                const Text(
                  'Aura',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8A003D),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Begin your story of connection',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8E717D),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Form Card
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEF).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB5003F).withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1820),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'LUXURY SOCIAL EXPERIENCE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF8E717D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Full Name
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF8E717D)),
                          hintText: 'Evelyn Rose',
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
                      
                      // Email
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF8E717D)),
                          hintText: 'evelyn@aura.com',
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
                      
                      // Password
                      const Text(
                        'Create Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E717D)),
                          hintText: '••••••••',
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
                      
                      // Confirm Password
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E717D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFF8E717D)),
                          hintText: '••••••••',
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
                      
                      const SizedBox(height: 20),
                      
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB5003F),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB5003F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Create Your Journey',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.favorite_border_rounded, size: 16),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Login navigation link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E717D),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB5003F),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Privacy statement
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'BY JOINING AURA, YOU AGREE TO OUR\nTERMS OF ELEGANCE & PRIVACY PROMISE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      height: 1.4,
                      color: Color(0xFF8E717D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
