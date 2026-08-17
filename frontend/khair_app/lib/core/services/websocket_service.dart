import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

/// WebSocket service for real-time event updates and notifications.
///
/// Connects to the backend WS endpoint with JWT auth.
/// Exposes a broadcast stream of typed messages.
class WebSocketService with WidgetsBindingObserver {
  static final WebSocketService _instance = WebSocketService._();
  static WebSocketService get instance => _instance;
  WebSocketService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      debugPrint('[WS] App paused/detached, disconnecting');
      disconnect();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[WS] App resumed, reconnecting');
      connect();
    }
  }

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  static const _maxReconnectAttempts = 10;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming WebSocket messages.
  /// Each message has `type` (String) and `data` (dynamic).
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  /// Connect to WebSocket using stored JWT token.
  Future<void> connect() async {
    if (_channel != null || _isConnecting) return;

    _isConnecting = true;

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token == null) {
        debugPrint('[WS] No auth token, skipping connect');
        return;
      }

      // Convert HTTP URL to WS URL
      final wsUrl = ApiConfig.apiBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final uri = Uri.parse('$wsUrl/ws?token=$token');
      debugPrint('[WS] Connecting to ${uri.host}...');

      final channel = WebSocketChannel.connect(uri);
      // `WebSocketChannel.connect` returns before the browser has finished the
      // handshake. Awaiting `ready` keeps connection failures inside this
      // recoverable path instead of letting them escape as uncaught errors.
      await channel.ready;
      _channel = channel;

      channel.stream.listen(
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
      _isConnecting = false;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnect from WebSocket.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
    _reconnectAttempts = 0;
    debugPrint('[WS] Disconnected');
  }

  /// Schedule a reconnect with exponential backoff.
  void _scheduleReconnect() {
    if (_channel != null || _isConnecting) return;
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
