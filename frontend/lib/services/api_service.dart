import 'dart:convert';
import 'dart:io' show Platform, Socket;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_service.dart';
import 'server_config.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  final http.Client _client = http.Client();
  
  String? _customHost;
  String _detectedHost = ServerConfig.localHostFallback; // Current machine LAN IP fallback
  Map<String, dynamic>? _cachedUserStatus;
  DateTime? _lastStatusFetch;

  void clearCache() {
    _cachedUserStatus = null;
    _lastStatusFetch = null;
  }

  String get host {
    if (ServerConfig.useProduction) {
      return ServerConfig.productionHost;
    }
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    if (kIsWeb) {
      return '127.0.0.1';
    } else if (Platform.isAndroid) {
      return _detectedHost;
    } else {
      return '127.0.0.1';
    }
  }

  bool get _isLocal {
    if (ServerConfig.useProduction) {
      return false;
    }
    final h = host.toLowerCase();
    return h.startsWith('127.0.0.1') || 
           h.startsWith('10.') || 
           h.startsWith('192.168.') || 
           h.startsWith('localhost') || 
           h.startsWith('172.');
  }

  String get baseUrl {
    if (ServerConfig.useProduction) {
      final scheme = ServerConfig.productionUseHttps ? 'https' : 'http';
      return '$scheme://$host/api';
    }
    if (_isLocal) {
      return 'http://$host:8000/api';
    }
    return 'https://$host/api';
  }

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _customHost = prefs.getString('custom_host');

    // Auto-detect whether emulator (10.0.2.2) or machine LAN IP is reachable
    if (Platform.isAndroid && (_customHost == null || _customHost!.isEmpty)) {
      await _autoDetectAndroidHost();
    }
  }

  Future<void> _autoDetectAndroidHost() async {
    // Candidates: 1. Emulator loopback, 2. Machine's current LAN IP, 3. Machine's previous LAN IP
    final candidates = [ServerConfig.localHostFallback, '10.0.2.2', '10.164.158.59', '10.19.193.59'];
    for (final ip in candidates) {
      try {
        final socket = await Socket.connect(ip, 8000, timeout: const Duration(milliseconds: 300));
        socket.destroy();
        _detectedHost = ip;
        break;
      } catch (_) {}
    }
  }

  Future<void> setCustomHost(String? value) async {
    _customHost = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString('custom_host', value);
    } else {
      await prefs.remove('custom_host');
    }
  }

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  Map<String, String> _headers([bool withAuth = true]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    clearCache();
    String deviceName = 'Unknown Device';
    if (kIsWeb) {
      deviceName = 'Web App';
    } else if (Platform.isAndroid) {
      deviceName = 'Android Device';
    } else if (Platform.isIOS) {
      deviceName = 'iOS Device';
    } else if (Platform.isWindows) {
      deviceName = 'Windows PC';
    } else if (Platform.isMacOS) {
      deviceName = 'macOS PC';
    } else if (Platform.isLinux) {
      deviceName = 'Linux PC';
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _token = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/register'),
      headers: _headers(false),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _token = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return {'success': true, 'data': data};
    } else {
      final errors = data['errors'] as Map<String, dynamic>?;
      String errorMsg = 'Registration failed';
      if (errors != null && errors.isNotEmpty) {
        errorMsg = errors.values.first[0].toString();
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  Future<void> logout() async {
    _token = null;
    clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> getUserStatus() async {
    if (OfflineService.instance.isOffline) {
      final cached = await OfflineService.instance.loadCachedUserStatus();
      if (cached != null) {
        _cachedUserStatus = cached;
        return cached;
      }
    }

    final now = DateTime.now();
    if (_cachedUserStatus != null && _lastStatusFetch != null &&
        now.difference(_lastStatusFetch!) < const Duration(seconds: 10)) {
      return _cachedUserStatus!;
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/user-status'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _cachedUserStatus = jsonDecode(response.body);
        _lastStatusFetch = now;
        if (_cachedUserStatus != null) {
          OfflineService.instance.cacheUserStatus(_cachedUserStatus!);
        }
        return _cachedUserStatus!;
      } else {
        throw Exception('Failed to load user status');
      }
    } catch (e) {
      // Fallback to cache on exception/error
      final cached = await OfflineService.instance.loadCachedUserStatus();
      if (cached != null) {
        _cachedUserStatus = cached;
        return cached;
      }
      rethrow;
    }
  }
  Future<Map<String, dynamic>> pairPartner(String partnerEmail) async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/pair-partner'),
      headers: _headers(),
      body: jsonEncode({
        'partner_email': partnerEmail,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Pairing failed'};
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/dashboard-summary'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }

  Future<Map<String, dynamic>> updateAnniversaryDate(String date) async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/relationship/anniversary'),
      headers: _headers(),
      body: jsonEncode({
        'anniversary_date': date,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update proposal date');
    }
  }

  Future<List<dynamic>> getMessages() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/chat-messages'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<Map<String, dynamic>> sendMessage(String content, {int? replyToId}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat-messages'),
      headers: _headers(),
      body: jsonEncode({
        'content': content,
        ...?replyToId != null ? {'reply_to_id': replyToId} : null,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message');
    }
  }

  Future<void> reactToMessage(int messageId, String? reaction) async {
    await _client.post(
      Uri.parse('$baseUrl/chat-messages/$messageId/react'),
      headers: _headers(),
      body: jsonEncode({
        'reaction': reaction,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  Future<void> markMessageAsRead(int messageId) async {
    await _client.post(
      Uri.parse('$baseUrl/chat-messages/$messageId/read'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> editMessage(int messageId, String content) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/chat-messages/$messageId'),
      headers: _headers(),
      body: jsonEncode({
        'content': content,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to edit message');
    }
  }

  Future<void> clearChatHistory() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat-messages/clear'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to clear chat history');
    }
  }

  Future<Map<String, dynamic>> updateProfile(String name, String avatar) async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/user/update'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'avatar': avatar,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update profile');
    }
  }

  Future<void> updateFcmToken(String? fcmToken) async {
    await _client.post(
      Uri.parse('$baseUrl/user/fcm-token'),
      headers: _headers(),
      body: jsonEncode({
        'fcm_token': fcmToken,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> updatePreferences(bool showPreviews) async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/user/preferences'),
      headers: _headers(),
      body: jsonEncode({
        'show_previews': showPreviews,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update notification preferences');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    await _client.delete(
      Uri.parse('$baseUrl/chat-messages/$messageId'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<List<dynamic>> getDatePlans() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/date-plans'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load date plans');
    }
  }

  Future<Map<String, dynamic>> proposeDatePlan(String title, DateTime date, String? location) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/date-plans'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'date': date.toUtc().toIso8601String(),
        'location': location,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to propose date plan');
    }
  }

  Future<Map<String, dynamic>> respondToDatePlan(int planId, String status) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/date-plans/$planId/respond'),
      headers: _headers(),
      body: jsonEncode({
        'status': status,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to respond to date plan');
    }
  }

  Future<Map<String, dynamic>> updateDatePlan(int planId, String title, DateTime date, String? location) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/date-plans/$planId'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'date': date.toUtc().toIso8601String(),
        'location': location,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update date plan');
    }
  }

  Future<void> deleteDatePlan(int planId) async {
    await _client.delete(
      Uri.parse('$baseUrl/date-plans/$planId'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']}; // Removed debug_otp for security
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to send reset code.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'password': newPassword,
        'password_confirmation': newPassword,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to reset password.'};
    }
  }

  Future<Map<String, dynamic>> sendSignupOtp(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/signup/send-otp'),
        headers: _headers(false),
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true, 
          'message': data['message'],
          'debug_otp': data['debug_otp']
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send verification code.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifySignupOtp(String email, String otp) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/signup/verify-otp'),
        headers: _headers(false),
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Invalid verification code.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> cancelPairing() async {
    clearCache();
    final response = await _client.post(
      Uri.parse('$baseUrl/cancel-pairing'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to cancel pairing.'};
    }
  }

  Future<List<dynamic>> getDevices() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/user/devices'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load active sessions');
    }
  }

  Future<void> logoutDevice(int tokenId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/user/devices/$tokenId'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to log out from device');
    }
  }

  Future<void> logoutOtherDevices() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/user/devices/logout-others'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to log out from other devices');
    }
  }
}
