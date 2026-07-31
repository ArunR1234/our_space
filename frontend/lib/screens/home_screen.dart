import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/offline_service.dart';
import 'date_planner_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _nextDate;
  String? _anniversaryDateStr;
  
  Timer? _timer;
  final ValueNotifier<String> _timeElapsedNotifier = ValueNotifier<String>("00h : 00m : 00s");
  final ValueNotifier<int> _daysTogetherNotifier = ValueNotifier<int>(0);

  int? _currentUserId;
  bool _isResponding = false;
  int? _lastAutoClearedPlanId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupWebSocketListeners();
    OfflineService.instance.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeElapsedNotifier.dispose();
    _daysTogetherNotifier.dispose();
    _removeWebSocketListeners();
    OfflineService.instance.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted && OfflineService.instance.isOnline) {
      _loadDashboardData();
    }
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
    if (OfflineService.instance.isOffline) {
      final cached = await OfflineService.instance.loadCachedDashboard();
      if (cached != null && mounted) {
        setState(() {
          _nextDate = cached['next_date'];
          _anniversaryDateStr = cached['anniversary_date'];
          _currentUserId = cached['user_id'];
          _isLoading = false;
        });
        _startTimer();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final summary = await ApiService.instance.getDashboardSummary();
      if (mounted) {
        setState(() {
          _nextDate = summary['next_date'];
          _anniversaryDateStr = summary['anniversary_date'];
          _currentUserId = summary['user_id'];
          _isLoading = false;
        });
        _startTimer();
        
        // Cache the dashboard summary for offline use
        OfflineService.instance.cacheDashboard(summary);
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      // Try to fallback to cached dashboard on error
      final cached = await OfflineService.instance.loadCachedDashboard();
      if (cached != null && mounted) {
        setState(() {
          _nextDate = cached['next_date'];
          _anniversaryDateStr = cached['anniversary_date'];
          _currentUserId = cached['user_id'];
          _isLoading = false;
        });
        _startTimer();
      } else if (mounted) {
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
      _timeElapsedNotifier.value = "00h : 00m : 00s";
      _daysTogetherNotifier.value = 0;
      return;
    }

    try {
      final anniversary = DateTime.parse(_anniversaryDateStr!).toLocal();
      final now = DateTime.now();
      final difference = now.difference(anniversary);

      if (difference.isNegative) {
        _timeElapsedNotifier.value = "00h : 00m : 00s";
        _daysTogetherNotifier.value = 0;
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

      _daysTogetherNotifier.value = days;
      _timeElapsedNotifier.value = "${hoursStr}h : ${minutesStr}m : ${secondsStr}s";
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
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C1820),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
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
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: Colors.white,
                onSurface: Color(0xFF2C1820),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
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
            backgroundColor: status == 'accepted' ? Theme.of(context).colorScheme.primary : Color(0xFF8E717D),
          ),
        );
      }
    } catch (e) {
      print('Error responding to date plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond. Please try again.')),
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
    if (_nextDate == null) return SizedBox.shrink();
    
    final status = _nextDate!['status'] ?? 'pending';
    final isCreator = _nextDate!['creator_id'] == _currentUserId;

    if (status == 'accepted') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Color(0xFFFFECEF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 10, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 4),
            Text(
              'Confirmed',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'pending') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isCreator ? Color(0xFFFFF3CD) : Color(0xFFE2E3E5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isCreator ? 'Waiting for response...' : 'Needs Response',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isCreator ? Color(0xFF856404) : Color(0xFF383D41),
          ),
        ),
      );
    }
    
    return SizedBox.shrink();
  }

  Future<void> _cancelDatePlan() async {
    if (_nextDate == null || _isResponding) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Cancel Meet-up', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFF2C1820), fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to cancel this proposed meet-up?', style: TextStyle(color: Color(0xFF8E717D))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No, keep it', style: TextStyle(color: Color(0xFF8E717D))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('Yes, cancel it', style: TextStyle(fontWeight: FontWeight.bold)),
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
            SnackBar(content: Text('Meet-up proposal cancelled.')),
          );
        }
      } catch (e) {
        print('Error deleting date plan: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel meet-up. Please try again.')),
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
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Active Meet-up Exists',
              style: TextStyle(
                fontFamily: 'Georgia',
                color: Color(0xFF2C1820),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You already created a plan. You can only edit or cancel your current plan.',
              style: TextStyle(color: Color(0xFF8E717D)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
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
    final Future<List<dynamic>> datePlansFuture = ApiService.instance.getDatePlans();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Our Meet-up History',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C1820),
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
                    future: datePlansFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load history.',
                            style: TextStyle(color: Color(0xFF8E717D)),
                          ),
                        );
                      }
                      final plans = snapshot.data ?? [];
                      if (plans.isEmpty) {
                        return Center(
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
                        separatorBuilder: (context, index) => Divider(color: Color(0xFFFFECEF)),
                        itemBuilder: (context, index) {
                          final plan = sortedPlans[index];
                          final dateStr = DateFormat('MMM d, y • h:mm a')
                              .format(DateTime.parse(plan['date']).toLocal());
                          final status = plan['status'] ?? 'pending';
                          final isPast = DateTime.parse(plan['date']).toLocal().isBefore(DateTime.now());

                          IconData statusIcon = Icons.help_outline_rounded;
                          Color statusColor = Color(0xFF8E717D);
                          String statusText = 'Pending';

                          if (status == 'accepted') {
                            statusIcon = isPast ? Icons.check_circle_rounded : Icons.favorite_rounded;
                            statusColor = Theme.of(context).colorScheme.primary;
                            statusText = isPast ? 'Met! ❤️' : 'Confirmed';
                          } else if (status == 'declined') {
                            statusIcon = Icons.cancel_rounded;
                            statusColor = Color(0xFF8E717D);
                            statusText = 'Declined';
                          }

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plan['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF2C1820),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, size: 10, color: statusColor),
                                          SizedBox(width: 4),
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
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF8E717D)),
                                    SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
                                    ),
                                  ],
                                ),
                                if (plan['location'] != null && plan['location'].toString().trim().isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF8E717D)),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          plan['location'],
                                          style: TextStyle(fontSize: 11, color: Color(0xFF8E717D)),
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Icon(
          Icons.favorite_border_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Our Space',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Color(0xFFFFECEF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.primary),
                        title: Text('Logout from Journey', style: TextStyle(fontWeight: FontWeight.bold)),
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
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WELCOME BACK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF8E717D),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'Hello, My Love',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1820),
                ),
                textAlign: TextAlign.center,
              ),
              
              Spacer(flex: 1),

              // Main Live Counter Card
              Container(
                padding: EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFFFF0F3).withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFECEF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'DAYS TOGETHER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF8E717D),
                      ),
                    ),
                    SizedBox(height: 6),
                    ValueListenableBuilder<int>(
                      valueListenable: _daysTogetherNotifier,
                      builder: (context, days, _) {
                        return Text(
                          '$days',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            height: 1.1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEF).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ValueListenableBuilder<String>(
                        valueListenable: _timeElapsedNotifier,
                        builder: (context, timeElapsed, _) {
                          return Text(
                            timeElapsed,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.0,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 14),
                    GestureDetector(
                      onTap: _selectAnniversaryDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                            SizedBox(width: 6),
                            Text(
                              _anniversaryDateStr != null
                                  ? DateFormat('MMM d, y • h:mm a').format(DateTime.parse(_anniversaryDateStr!).toLocal())
                                  : 'Select Proposal Date',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Spacer(flex: 1),

              // Next Date Plan Banner
              Container(
                padding: EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
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
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFECEF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 22,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'NEXT MEET-UP',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          color: Color(0xFF8E717D),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      InkWell(
                                        onTap: _showDatePlanHistory,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.history_rounded,
                                                size: 11,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'History',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.primary,
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
                              SizedBox(height: 4),
                              if (_nextDate != null) ...[
                                Text(
                                  _nextDate!['title'],
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C1820),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8E717D)),
                                    SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, y • h:mm a')
                                          .format(DateTime.parse(_nextDate!['date']).toLocal()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8E717D),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_nextDate!['location'] != null && _nextDate!['location'].toString().trim().isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8E717D)),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _nextDate!['location'],
                                          style: TextStyle(
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
                                SizedBox(height: 4),
                                Text(
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
                      SizedBox(height: 16),
                      Divider(color: Color(0xFFFFECEF), height: 1),
                      SizedBox(height: 12),
                      Text(
                        'Your partner proposed this meet-up! Do you want to go?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C1820),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isResponding ? null : () => _respondToDate('declined'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Color(0xFFFFCCD5)),
                                foregroundColor: Color(0xFF8E717D),
                                padding: EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.close_rounded, size: 16),
                              label: Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isResponding ? null : () => _respondToDate('accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isResponding 
                                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                  : Icon(Icons.favorite_rounded, size: 14),
                              label: Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_nextDate != null && 
                        (_nextDate!['creator_id'] == _currentUserId || _nextDate!['status'] == 'accepted')) ...[
                      SizedBox(height: 16),
                      Divider(color: Color(0xFFFFECEF), height: 1),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isResponding ? null : _cancelDatePlan,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Color(0xFFFFCCD5)),
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.delete_outline_rounded, size: 16),
                              label: Text('Cancel Meet-up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isResponding ? null : _editDatePlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.edit_rounded, size: 14),
                              label: Text('Edit Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Spacer(flex: 1),

              ElevatedButton.icon(
                onPressed: _showDatePlanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  'Plan Meet-up Tonight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
