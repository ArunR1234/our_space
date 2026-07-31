import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

/// Central service for all offline capabilities:
/// 1. Connectivity monitoring
/// 2. Message cache (read old messages offline)
/// 3. Draft message queue (send when back online)
/// 4. Dashboard cache (read last dashboard data offline)
class OfflineService extends ChangeNotifier {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  // ── State ──────────────────────────────────────────────────────────────
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Keys
  static const _kMessages      = 'offline_messages_cache';
  static const _kDraftQueue    = 'offline_draft_queue';
  static const _kDashboard     = 'offline_dashboard_cache';

  // ── Init ───────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Check current connectivity state immediately
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasInternet(results);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasInternet(results);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ── Message Cache ──────────────────────────────────────────────────────

  /// Save latest messages to local storage after a successful load.
  Future<void> cacheMessages(List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((m) => m.toJson()).toList();
      await prefs.setString(_kMessages, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('OfflineService: Failed to cache messages: $e');
    }
  }

  /// Load messages from local cache when offline.
  Future<List<Message>> loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kMessages);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => Message.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('OfflineService: Failed to load cached messages: $e');
      return [];
    }
  }

  // ── Draft Queue ────────────────────────────────────────────────────────

  /// Queue a message draft when the user tries to send while offline.
  Future<void> enqueueDraft(String content, {int? replyToId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kDraftQueue);
      final queue = raw != null
          ? (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      queue.add({
        'content': content,
        'reply_to_id': replyToId,
        'queued_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_kDraftQueue, jsonEncode(queue));
    } catch (e) {
      debugPrint('OfflineService: Failed to enqueue draft: $e');
    }
  }

  /// Fetch all pending drafts.
  Future<List<Map<String, dynamic>>> getDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kDraftQueue);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clear all drafts after they've been sent.
  Future<void> clearDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraftQueue);
  }

  /// Returns true if there are queued drafts.
  Future<bool> hasPendingDrafts() async {
    final drafts = await getDrafts();
    return drafts.isNotEmpty;
  }

  // ── Dashboard Cache ────────────────────────────────────────────────────

  /// Save dashboard API response to local storage.
  Future<void> cacheDashboard(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDashboard, jsonEncode(data));
    } catch (e) {
      debugPrint('OfflineService: Failed to cache dashboard: $e');
    }
  }

  /// Load dashboard data from local cache.
  Future<Map<String, dynamic>?> loadCachedDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kDashboard);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ── User Status Cache ──────────────────────────────────────────────────
  static const _kUserStatus = 'offline_user_status_cache';

  /// Save user status response locally.
  Future<void> cacheUserStatus(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserStatus, jsonEncode(data));
    } catch (e) {
      debugPrint('OfflineService: Failed to cache user status: $e');
    }
  }

  /// Load cached user status.
  Future<Map<String, dynamic>?> loadCachedUserStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kUserStatus);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
