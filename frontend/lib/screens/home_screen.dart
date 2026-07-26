import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'date_planner_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _romanticQuote = "Every moment with you is a new favorite memory. Can't wait for what's next.";
  Map<String, dynamic>? _nextDate;
  Map<String, dynamic>? _partner;
  String? _anniversaryDateStr;
  
  Timer? _timer;
  String _timeElapsedStr = "00h : 00m : 00s";
  int _daysTogetherLive = 0;

  int? _currentUserId;
  bool _isResponding = false;
  int? _lastAutoClearedPlanId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupWebSocketListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeWebSocketListeners();
    super.dispose();
  }

  void _setupWebSocketListeners() {
    WebSocketService.instance.addListener('App\\Events\\AnniversaryUpdated', _onAnniversaryUpdatedReceived);
    WebSocketService.instance.addListener('App\\Events\\DatePlanUpdated', _onDatePlanUpdatedReceived);
    WebSocketService.instance.addListener('App\\Events\\DatePlanDeleted', _onDatePlanDeletedReceived);
  }

  void _removeWebSocketListeners() {
    WebSocketService.instance.removeListener('App\\Events\\AnniversaryUpdated', _onAnniversaryUpdatedReceived);
    WebSocketService.instance.removeListener('App\\Events\\DatePlanUpdated', _onDatePlanUpdatedReceived);
    WebSocketService.instance.removeListener('App\\Events\\DatePlanDeleted', _onDatePlanDeletedReceived);
  }

  void _onAnniversaryUpdatedReceived(Map<String, dynamic> data) {
    print('AnniversaryUpdated event received on HomeScreen: $data');
    _loadDashboardData();
  }

  void _onDatePlanUpdatedReceived(Map<String, dynamic> data) {
    print('DatePlanUpdated event received on HomeScreen: $data');
    _loadDashboardData();
  }

  void _onDatePlanDeletedReceived(Map<String, dynamic> data) {
    print('DatePlanDeleted event received on HomeScreen: $data');
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final summary = await ApiService.instance.getDashboardSummary();
      if (mounted) {
        setState(() {
          _romanticQuote = summary['romantic_quote'] ?? "Every moment with you is a new favorite memory. Can't wait for what's next.";
          _nextDate = summary['next_date'];
          _partner = summary['partner'];
          _anniversaryDateStr = summary['anniversary_date'];
          _currentUserId = summary['user_id'];
          _isLoading = false;
        });
        _startTimer();
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

  void _startTimer() {
    _timer?.cancel();
    _updateLiveTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateLiveTime();
      } else {
        timer.cancel();
      }
    });
  }

  void _updateLiveTime() {
    if (_nextDate != null) {
      try {
        final planId = _nextDate!['id'];
        final dateLimit = DateTime.parse(_nextDate!['date']).toLocal();
        if (DateTime.now().isAfter(dateLimit) && planId != _lastAutoClearedPlanId) {
          _lastAutoClearedPlanId = planId;
          setState(() {
            _nextDate = null;
          });
          _loadDashboardData();
        }
      } catch (_) {}
    }

    if (_anniversaryDateStr == null) {
      setState(() {
        _timeElapsedStr = "00h : 00m : 00s";
        _daysTogetherLive = 0;
      });
      return;
    }

    try {
      final anniversary = DateTime.parse(_anniversaryDateStr!).toLocal();
      final now = DateTime.now();
      final difference = now.difference(anniversary);

      if (difference.isNegative) {
        setState(() {
          _timeElapsedStr = "00h : 00m : 00s";
          _daysTogetherLive = 0;
        });
        return;
      }

      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      // Format as two digits (padded with zero)
      final hoursStr = hours.toString().padLeft(2, '0');
      final minutesStr = minutes.toString().padLeft(2, '0');
      final secondsStr = seconds.toString().padLeft(2, '0');

      setState(() {
        _daysTogetherLive = days;
        _timeElapsedStr = "${hoursStr}h : ${minutesStr}m : ${secondsStr}s";
      });
    } catch (e) {
      print('Error parsing anniversary date: $e');
    }
  }

  Future<void> _selectAnniversaryDate() async {
    DateTime initialDate = DateTime.now();
    if (_anniversaryDateStr != null) {
      try {
        initialDate = DateTime.parse(_anniversaryDateStr!).toLocal();
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFB5003F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C1820),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB5003F),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFB5003F),
                onPrimary: Colors.white,
                onSurface: Color(0xFF2C1820),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB5003F),
                ),
              ),
            ),
            child: child!,
          );
        },
      );

      final finalDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        timePicked?.hour ?? 0,
        timePicked?.minute ?? 0,
      );

      setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.instance.updateAnniversaryDate(finalDateTime.toIso8601String());
        await _loadDashboardData();
      } catch (e) {
        print('Error updating anniversary: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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

  Future<void> _respondToDate(String status) async {
    if (_nextDate == null || _isResponding) return;
    
    setState(() {
      _isResponding = true;
    });

    try {
      final int planId = _nextDate!['id'];
      await ApiService.instance.respondToDatePlan(planId, status);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'accepted' 
                ? 'Meet-up proposal accepted! ❤️' 
                : 'Meet-up proposal declined.'),
            backgroundColor: status == 'accepted' ? const Color(0xFFB5003F) : const Color(0xFF8E717D),
          ),
        );
      }
    } catch (e) {
      print('Error responding to date plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to respond. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  Widget _buildStatusBadge() {
    if (_nextDate == null) return const SizedBox.shrink();
    
    final status = _nextDate!['status'] ?? 'pending';
    final isCreator = _nextDate!['creator_id'] == _currentUserId;

    if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 10, color: Color(0xFFB5003F)),
            SizedBox(width: 4),
            Text(
              'Confirmed',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB5003F),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isCreator ? const Color(0xFFFFF3CD) : const Color(0xFFE2E3E5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isCreator ? 'Waiting for response...' : 'Needs Response',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isCreator ? const Color(0xFF856404) : const Color(0xFF383D41),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Future<void> _cancelDatePlan() async {
    if (_nextDate == null || _isResponding) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFF5F7),
          title: const Text('Cancel Meet-up', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to cancel this proposed meet-up?', style: TextStyle(color: Color(0xFF8E717D))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, keep it', style: TextStyle(color: Color(0xFF8E717D))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5003F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Yes, cancel it', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isResponding = true;
      });

      try {
        final int planId = _nextDate!['id'];
        await ApiService.instance.deleteDatePlan(planId);
        await _loadDashboardData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meet-up proposal cancelled.')),
          );
        }
      } catch (e) {
        print('Error deleting date plan: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel meet-up. Please try again.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isResponding = false;
          });
        }
      }
    }
  }

  void _editDatePlan() {
    if (_nextDate == null) return;
    showDialog(
      context: context,
      builder: (context) => DatePlannerDialog(initialDatePlan: _nextDate),
    ).then((value) {
      if (value == true) {
        _loadDashboardData();
      }
    });
  }

  void _showDatePlanner() {
    if (_nextDate != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFFFF5F7),
            title: const Text(
              'Active Meet-up Exists',
              style: TextStyle(
                fontFamily: 'Georgia',
                color: Color(0xFF2C1820),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'You already created a plan. You can only edit or cancel your current plan.',
              style: TextStyle(color: Color(0xFF8E717D)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFFB5003F), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => const DatePlannerDialog(),
    ).then((value) {
      if (value == true) {
        _loadDashboardData();
      }
    });
  }

  void _showDatePlanHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFFFF5F7),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, color: Color(0xFFB5003F), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Our Meet-up History',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1820),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF8E717D), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: ApiService.instance.getDatePlans(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB5003F)),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Failed to load history.',
                            style: TextStyle(color: Color(0xFF8E717D)),
                          ),
                        );
                      }
                      final plans = snapshot.data ?? [];
                      if (plans.isEmpty) {
                        return const Center(
                          child: Text(
                            'No dates planned yet.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF8E717D),
                            ),
                          ),
                        );
                      }

                      final sortedPlans = List.from(plans);
                      sortedPlans.sort((a, b) {
                        final aTime = DateTime.parse(a['created_at'] ?? a['date']);
                        final bTime = DateTime.parse(b['created_at'] ?? b['date']);
                        return bTime.compareTo(aTime);
                      });

                      return ListView.separated(
                        itemCount: sortedPlans.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFFFFECEF)),
                        itemBuilder: (context, index) {
                          final plan = sortedPlans[index];
                          final dateStr = DateFormat('MMM d, y • h:mm a')
                              .format(DateTime.parse(plan['date']).toLocal());
                          final status = plan['status'] ?? 'pending';
                          final isPast = DateTime.parse(plan['date']).toLocal().isBefore(DateTime.now());

                          IconData statusIcon = Icons.help_outline_rounded;
                          Color statusColor = const Color(0xFF8E717D);
                          String statusText = 'Pending';

                          if (status == 'accepted') {
                            statusIcon = isPast ? Icons.check_circle_rounded : Icons.favorite_rounded;
                            statusColor = const Color(0xFFB5003F);
                            statusText = isPast ? 'Met! ❤️' : 'Confirmed';
                          } else if (status == 'declined') {
                            statusIcon = Icons.cancel_rounded;
                            statusColor = const Color(0xFF8E717D);
                            statusText = 'Declined';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plan['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF2C1820),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, size: 10, color: statusColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF8E717D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
                                    ),
                                  ],
                                ),
                                if (plan['location'] != null && plan['location'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF8E717D)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          plan['location'],
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(
          Icons.favorite_border_rounded,
          color: Color(0xFFB5003F),
        ),
        title: const Text(
          'Our Space',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'WELCOME BACK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF8E717D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Hello, My Love',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1820),
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 1),

              // Main Live Counter Card
              Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFB5003F).withOpacity(0.08),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFFFF0F3).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB5003F).withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB5003F).withOpacity(0.1),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 32,
                        color: Color(0xFFB5003F),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'DAYS TOGETHER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF8E717D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_daysTogetherLive',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A003D),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEF).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _timeElapsedStr,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB5003F),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _selectAnniversaryDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFB5003F).withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFFB5003F)),
                            const SizedBox(width: 6),
                            Text(
                              _anniversaryDateStr != null
                                  ? DateFormat('MMM d, y • h:mm a').format(DateTime.parse(_anniversaryDateStr!).toLocal())
                                  : 'Select Proposal Date',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5003F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Next Date Plan Banner
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFB5003F).withOpacity(0.06),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFECEF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 22,
                            color: Color(0xFFB5003F),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'NEXT MEET-UP',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          color: Color(0xFF8E717D),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: _showDatePlanHistory,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.history_rounded,
                                                size: 11,
                                                color: Color(0xFFB5003F),
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'History',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFB5003F),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_nextDate != null)
                                    _buildStatusBadge(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (_nextDate != null) ...[
                                Text(
                                  _nextDate!['title'],
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C1820),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8E717D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, y • h:mm a')
                                          .format(DateTime.parse(_nextDate!['date']).toLocal()),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8E717D),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_nextDate!['location'] != null && _nextDate!['location'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8E717D)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _nextDate!['location'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8E717D),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'No dates planned yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF8E717D),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_nextDate != null && 
                        _nextDate!['status'] == 'pending' && 
                        _nextDate!['creator_id'] != _currentUserId) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFFFECEF), height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        'Your partner proposed this meet-up! Do you want to go?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C1820),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isResponding ? null : () => _respondToDate('declined'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFFCCD5)),
                                foregroundColor: const Color(0xFF8E717D),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isResponding ? null : () => _respondToDate('accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB5003F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isResponding 
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                  : const Icon(Icons.favorite_rounded, size: 14),
                              label: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_nextDate != null && 
                        (_nextDate!['creator_id'] == _currentUserId || _nextDate!['status'] == 'accepted')) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFFFECEF), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isResponding ? null : _cancelDatePlan,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFFCCD5)),
                                foregroundColor: const Color(0xFFB5003F),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Cancel Meet-up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isResponding ? null : _editDatePlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB5003F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('Edit Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 1),

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
                  'Plan Meet-up Tonight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
