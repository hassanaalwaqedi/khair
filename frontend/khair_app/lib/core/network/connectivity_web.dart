import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'platform_connectivity.dart';

/// Web implementation using browser's navigator.onLine API.
class PlatformConnectivityImpl extends PlatformConnectivity {
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  void initialize() {
    _isOnline = web.window.navigator.onLine;

    web.window.addEventListener(
      'online',
      ((web.Event e) {
        _isOnline = true;
        _controller.add(true);
      }).toJS,
    );

    web.window.addEventListener(
      'offline',
      ((web.Event e) {
        _isOnline = false;
        _controller.add(false);
      }).toJS,
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}
