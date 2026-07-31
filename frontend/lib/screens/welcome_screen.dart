import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            
            // Main content
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Spacer(),
                    
                    // Romantic logo placeholder / graphics
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pink heart background
                        Opacity(
                          opacity: 0.0,
                          child: Icon(
                            Icons.favorite_outline_rounded,
                            size: 180,
                            color: Color(0xFFFFB3C6).withValues(alpha: 0.5),
                          ),
                        ),
                        // Square elegant border container matching the design
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Color(0xFFFAF7F2), // Off-white
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite_border_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 28,
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFFF9EAF),
                                      size: 28,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'A  V',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B6B78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Title
                    Text(
                      'Our Space',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary, // Elegant dark magenta
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'A place for us.',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8E717D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    Spacer(),
                    
                    // Button "Tap to begin"
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary, // Deep crimson
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        elevation: 4,
                        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tap to begin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Exclusive Luxury pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFECEF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'EXCLUSIVE LUXURY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Spacer(),
                    
                    // Bottom-left outline heart
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Opacity(
                          opacity: 0.0,
                          child: Icon(
                            Icons.favorite_border_rounded,
                            size: 32,
                            color: Color(0xFFFFB3C6).withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class IconSparkles extends StatelessWidget {
  const IconSparkles({super.key});
  @override
  Widget build(BuildContext context) => Icon(Icons.star, size: 12);
}
