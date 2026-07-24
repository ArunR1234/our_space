import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _socketId;
  Timer? _pingTimer;
  StreamSubscription? _subscription;

  final String _appKey = '9tutrr2ytrunphebu8ue'; // Matches REVERB_APP_KEY in .env

  // Event listeners map
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};

  String get wsUrl {
    final host = ApiService.instance.host;
    return 'ws://$host:8080/app/$_appKey?protocol=7&client=js&version=8.4.0&flash=false';
  }

  String get httpAuthUrl {
    final host = ApiService.instance.host;
    return 'http://$host:8000/api/broadcasting/auth';
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
    if (_isConnected) return;

    try {
      print('Connecting to Reverb WebSocket at $wsUrl...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message, relationshipId);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket Connection Closed');
          _handleDisconnect();
        },
      );

      // Start pinging to keep connection alive
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected && _channel != null) {
          _channel!.sink.add(jsonEncode({'event': 'pusher:ping'}));
        }
      });

    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
    }
  }

  void _handleMessage(dynamic message, int relationshipId) async {
    try {
      final decoded = jsonDecode(message.toString());
      final String event = decoded['event'] ?? '';
      final dynamic dataRaw = decoded['data'];

      print('WebSocket Received Event: $event');

      if (event == 'pusher:connection_established') {
        final data = jsonDecode(dataRaw.toString());
        _socketId = data['socket_id'];
        print('WebSocket Connection Established. Socket ID: $_socketId');
        
        // Authorize and subscribe to the relationship channel
        await _subscribeToChannel(relationshipId);
      } else if (event == 'pusher:pong') {
        // Pong received, connection is healthy
      } else if (event == 'pusher_internal:subscription_succeeded') {
        print('Subscribed to private channel successfully.');
      } else {
        // This is a custom broadcast event from Laravel
        // Custom events typically have data as a nested JSON string or Map
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
          for (var callback in _listeners[event]!) {
            callback(eventData);
          }
        }
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  Future<void> _subscribeToChannel(int relationshipId) async {
    if (_socketId == null || ApiService.instance.token == null) {
      print('Cannot subscribe: socketId or auth token is missing');
      return;
    }

    final channelName = 'private-relationship.$relationshipId';

    try {
      print('Authenticating channel $channelName via HTTP...');
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
      );

      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        final String authSignature = authData['auth'];

        print('Subscribing to WebSocket channel $channelName...');
        _channel!.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {
            'channel': channelName,
            'auth': authSignature,
          }
        }));
      } else {
        print('Failed to authenticate channel: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error subscribing to channel: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _socketId = null;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;
    print('Disconnected from WebSocket.');
  }

  void disconnect() {
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
