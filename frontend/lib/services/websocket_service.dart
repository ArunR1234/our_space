import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _socketId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _subscription;
  int _reconnectAttempts = 0;
  int? _lastRelationshipId;

  // Uses String.fromEnvironment so it can be overwritten at build time, with local Reverb key fallback.
  static const String _appKey = String.fromEnvironment('REVERB_APP_KEY', defaultValue: '9tutrr2ytrunphebu8ue');

  // Event listeners map
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};

  bool get _isSecure => ApiService.instance.baseUrl.startsWith('https://');

  String get wsUrl {
    final host = ApiService.instance.host;
    if (_isSecure) {
      return 'wss://$host/app/$_appKey?protocol=7&client=js&version=8.4.0&flash=false';
    } else {
      return 'ws://$host:8080/app/$_appKey?protocol=7&client=js&version=8.4.0&flash=false';
    }
  }

  String get httpAuthUrl {
    return '${ApiService.instance.baseUrl}/broadcasting/auth';
  }

  void addListener(String eventName, Function(Map<String, dynamic>) callback) {
    if (!_listeners.containsKey(eventName)) {
      _listeners[eventName] = [];
    }
    if (!_listeners[eventName]!.contains(callback)) {
      _listeners[eventName]!.add(callback);
    }
  }

  void removeListener(String eventName, Function(Map<String, dynamic>) callback) {
    if (_listeners.containsKey(eventName)) {
      _listeners[eventName]!.remove(callback);
    }
  }

  Future<void> connect(int relationshipId) async {
    _lastRelationshipId = relationshipId;
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;
    try {
      if (kDebugMode) {
        print('Connecting to Reverb WebSocket at $wsUrl...');
      }
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _isConnecting = false;

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message, relationshipId);
        },
        onError: (error) {
          if (kDebugMode) {
            print('WebSocket Error: $error');
          }
          _handleDisconnect();
        },
        onDone: () {
          if (kDebugMode) {
            print('WebSocket Connection Closed');
          }
          _handleDisconnect();
        },
      );

      // Start pinging to keep connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected && _channel != null) {
          _channel!.sink.add(jsonEncode({'event': 'pusher:ping'}));
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('WebSocket connection failed: $e');
      }
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message, int relationshipId) async {
    try {
      final decoded = jsonDecode(message.toString());
      final String event = decoded['event'] ?? '';
      final dynamic dataRaw = decoded['data'];

      if (kDebugMode) {
        print('WebSocket Received Event: $event');
      }

      if (event == 'pusher:connection_established') {
        final data = jsonDecode(dataRaw.toString());
        _socketId = data['socket_id'];
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        if (kDebugMode) {
          print('WebSocket Connection Established. Socket ID: $_socketId');
        }
        
        // Authorize and subscribe to the relationship channel
        await _subscribeToChannel(relationshipId);
      } else if (event == 'pusher:pong') {
        // Pong received, connection is healthy
      } else if (event == 'pusher_internal:subscription_succeeded') {
        if (kDebugMode) {
          print('Subscribed to private channel successfully.');
        }
      } else {
        // This is a custom broadcast event from Laravel
        Map<String, dynamic> eventData = {};
        if (dataRaw != null) {
          if (dataRaw is String) {
            eventData = jsonDecode(dataRaw);
          } else if (dataRaw is Map) {
            eventData = Map<String, dynamic>.from(dataRaw);
          }
        }
        
        // Dispatch to registered listeners
        if (_listeners.containsKey(event)) {
          final list = List<Function(Map<String, dynamic>)>.from(_listeners[event]!);
          for (var callback in list) {
            callback(eventData);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing WebSocket message: $e');
      }
    }
  }

  Future<void> _subscribeToChannel(int relationshipId) async {
    if (_socketId == null || ApiService.instance.token == null) {
      if (kDebugMode) {
        print('Cannot subscribe: socketId or auth token is missing');
      }
      return;
    }

    final channelName = 'private-relationship.$relationshipId';

    try {
      if (kDebugMode) {
        print('Authenticating channel $channelName via HTTP...');
      }
      final response = await http.post(
        Uri.parse(httpAuthUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${ApiService.instance.token}',
        },
        body: {
          'socket_id': _socketId,
          'channel_name': channelName,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        final String authSignature = authData['auth'];

        if (kDebugMode) {
          print('Subscribing to WebSocket channel $channelName...');
        }
        _channel!.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {
            'channel': channelName,
            'auth': authSignature,
          }
        }));
      } else {
        if (kDebugMode) {
          print('Failed to authenticate channel: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to channel: $e');
      }
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _socketId = null;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;
    if (kDebugMode) {
      print('Disconnected from WebSocket.');
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_lastRelationshipId == null) return;
    if (_reconnectTimer != null) return;

    _reconnectAttempts++;
    final delaySeconds = 1 << min(5, _reconnectAttempts); // 2, 4, 8, 16, 32s

    if (kDebugMode) {
      print('Scheduling WebSocket reconnect #$_reconnectAttempts in $delaySeconds seconds...');
    }

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      if (_lastRelationshipId != null) {
        connect(_lastRelationshipId!);
      }
    });
  }

  void disconnect() {
    _lastRelationshipId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _handleDisconnect();
    if (_channel != null) {
      _channel!.sink.close();
    }
  }

  void triggerClientEvent(String eventName, int relationshipId, Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'event': eventName,
        'channel': 'private-relationship.$relationshipId',
        'data': data,
      }));
    }
  }
}
