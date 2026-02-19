import 'dart:async';
import 'platform_connectivity.dart';

/// Mobile/default implementation — assumes always online.
/// For full mobile connectivity detection, integrate connectivity_plus package.
class PlatformConnectivityImpl extends PlatformConnectivity {
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  void initialize() {
    // On mobile, assume online by default.
    // For real connectivity detection, add connectivity_plus package.
    _isOnline = true;
  }

  @override
  void dispose() {
    _controller.close();
  }
}
