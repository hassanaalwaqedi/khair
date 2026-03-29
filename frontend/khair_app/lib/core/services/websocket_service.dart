import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service for real-time updates (chat messages, notifications).
///
/// Connects to the backend WS endpoint with JWT auth.
/// Exposes a broadcast stream of typed messages.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  static WebSocketService get instance => _instance;
  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;
  static const _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://khair.it.com/api/v1',
  );

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming WebSocket messages.
  /// Each message has `type` (String) and `data` (dynamic).
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  /// Connect to WebSocket using stored JWT token.
  Future<void> connect() async {
    if (_channel != null) return;

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('[WS] No auth token, skipping connect');
        return;
      }

      // Convert HTTP URL to WS URL
      final wsUrl = _baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final uri = Uri.parse('$wsUrl/ws?token=$token');
      debugPrint('[WS] Connecting to ${uri.host}...');

      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            debugPrint('[WS] Received: ${message['type']}');
            _messageController.add(message);
          } catch (e) {
            debugPrint('[WS] Parse error: $e');
          }
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _channel = null;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _channel = null;
          _scheduleReconnect();
        },
      );

      _reconnectAttempts = 0;
      debugPrint('[WS] Connected successfully');
    } catch (e) {
      debugPrint('[WS] Connect error: $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;
    debugPrint('[WS] Disconnected');
  }

  /// Schedule a reconnect with exponential backoff.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    debugPrint('[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  /// Dispose the service.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
