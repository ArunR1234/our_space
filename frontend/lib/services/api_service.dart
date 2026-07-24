import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  String? _customHost;

  String get host {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    if (kIsWeb) {
      return '127.0.0.1';
    } else if (Platform.isAndroid) {
      return '10.34.246.59';
    } else {
      return '127.0.0.1';
    }
  }

  String get baseUrl => 'http://$host:8000/api';

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _customHost = prefs.getString('custom_host');
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
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

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
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: _headers(false),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> getUserStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user-status'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user status');
    }
  }

  Future<Map<String, dynamic>> pairPartner(String partnerEmail) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pair-partner'),
      headers: _headers(),
      body: jsonEncode({
        'partner_email': partnerEmail,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Pairing failed'};
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard-summary'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }

  Future<List<dynamic>> getMessages() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat-messages'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<Map<String, dynamic>> sendMessage(String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat-messages'),
      headers: _headers(),
      body: jsonEncode({
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message');
    }
  }

  Future<void> reactToMessage(int messageId, String? reaction) async {
    await http.post(
      Uri.parse('$baseUrl/chat-messages/$messageId/react'),
      headers: _headers(),
      body: jsonEncode({
        'reaction': reaction,
      }),
    );
  }

  Future<void> markMessageAsRead(int messageId) async {
    await http.post(
      Uri.parse('$baseUrl/chat-messages/$messageId/read'),
      headers: _headers(),
    );
  }

  Future<List<dynamic>> getDatePlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/date-plans'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load date plans');
    }
  }

  Future<Map<String, dynamic>> proposeDatePlan(String title, DateTime date, String? location) async {
    final response = await http.post(
      Uri.parse('$baseUrl/date-plans'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'date': date.toIso8601String(),
        'location': location,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to propose date plan');
    }
  }

  Future<Map<String, dynamic>> respondToDatePlan(int planId, String status) async {
    final response = await http.post(
      Uri.parse('$baseUrl/date-plans/$planId/respond'),
      headers: _headers(),
      body: jsonEncode({
        'status': status,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to respond to date plan');
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message'], 'debug_otp': data['debug_otp']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to send reset code.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: _headers(false),
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'password': newPassword,
        'password_confirmation': newPassword,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to reset password.'};
    }
  }

  Future<Map<String, dynamic>> cancelPairing() async {
    final response = await http.post(
      Uri.parse('$baseUrl/cancel-pairing'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to cancel pairing.'};
    }
  }
}
