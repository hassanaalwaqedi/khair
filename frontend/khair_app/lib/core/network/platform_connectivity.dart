import 'dart:async';

/// Platform connectivity interface.
/// Web and mobile have different implementations.
abstract class PlatformConnectivity {
  bool get isOnline;
  Stream<bool> get onConnectivityChanged;
  void initialize();
  void dispose();
}
