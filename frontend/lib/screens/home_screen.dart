import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'date_planner_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  int _daysTogether = 420;
  String _romanticQuote = "Every moment with you is a new favorite memory. Can't wait for what's next.";
  Map<String, dynamic>? _nextDate;
  Map<String, dynamic>? _partner;
  int _carouselIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await ApiService.instance.getDashboardSummary();
      if (mounted) {
        setState(() {
          _daysTogether = summary['days_together'] ?? 420;
          _romanticQuote = summary['romantic_quote'] ?? "Every moment with you is a new favorite memory. Can't wait for what's next.";
          _nextDate = summary['next_date'];
          _partner = summary['partner'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _showDatePlanner() {
    showDialog(
      context: context,
      builder: (context) => const DatePlannerDialog(),
    ).then((value) {
      if (value == true) {
        _loadDashboardData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF5F7),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(
          Icons.favorite_border_rounded,
          color: Color(0xFFB5003F),
        ),
        title: const Text(
          'Aura',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8A003D),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFFB5003F)),
            onPressed: () {
              // Show logout option
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFFFFECEF),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Color(0xFFB5003F)),
                        title: const Text('Logout from Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          _handleLogout();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFF8E717D),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Hello, My Love',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1820),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Carousel card widget
              SizedBox(
                height: 280,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _carouselIndex = index;
                    });
                  },
                  children: [
                    // Slide 1: Days Together
                    _buildCarouselCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB5003F).withOpacity(0.1),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 40,
                              color: Color(0xFFB5003F),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'DAYS TOGETHER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFF8E717D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_daysTogether',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8A003D),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Slide 2: Next Date
                    _buildCarouselCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFECEF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 32,
                              color: Color(0xFFB5003F),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'NEXT DATE PLAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFF8E717D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_nextDate != null) ...[
                            Text(
                              _nextDate!['title'],
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C1820),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('EEEE, MMMM d, y • h:mm a')
                                  .format(DateTime.parse(_nextDate!['date'])),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E717D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_nextDate!['location'] != null && _nextDate!['location'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '@ ${_nextDate!['location']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFB5003F),
                                ),
                              ),
                            ],
                          ] else ...[
                            const Text(
                              'No dates planned yet.',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF8E717D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Propose something special tonight!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E717D),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Slide 3: Connected Partner
                    _buildCarouselCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              backgroundColor: Color(0xFFFFECEF),
                              child: Icon(Icons.person_rounded, size: 36, color: Color(0xFFB5003F)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'MY SOULMATE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFF8E717D),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _partner != null ? _partner!['name'] : 'My Love',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C1820),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Connected & Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _carouselIndex == index
                          ? const Color(0xFFB5003F)
                          : const Color(0xFFFFB3C6).withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Quote Card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEF).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '"$_romanticQuote"',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E717D),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              // Plan Date Button
              ElevatedButton.icon(
                onPressed: _showDatePlanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB5003F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: const Color(0xFFB5003F).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text(
                  'Plan Date Tonight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: const Color(0xFFB5003F).withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFFFF0F3).withOpacity(0.5),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
