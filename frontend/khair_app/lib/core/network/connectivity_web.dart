import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'platform_connectivity.dart';

/// Web implementation using browser's navigator.onLine API.
class PlatformConnectivityImpl extends PlatformConnectivity {
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _onlineSub;
  StreamSubscription? _offlineSub;
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  void initialize() {
    _isOnline = html.window.navigator.onLine ?? true;

    _onlineSub = html.window.onOnline.listen((_) {
      _isOnline = true;
      _controller.add(true);
    });

    _offlineSub = html.window.onOffline.listen((_) {
      _isOnline = false;
      _controller.add(false);
    });
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    _controller.close();
  }
}
