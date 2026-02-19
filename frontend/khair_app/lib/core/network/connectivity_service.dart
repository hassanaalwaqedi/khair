import 'dart:async';
import 'platform_connectivity.dart';
import 'connectivity_mobile.dart'
    if (dart.library.html) 'connectivity_web.dart';

/// Service that monitors network connectivity status.
/// Uses conditional imports for platform-safe behavior:
/// - Web: uses browser's navigator.onLine
/// - Mobile: assumes online (can be enhanced with connectivity_plus)
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  late final PlatformConnectivity _platform;

  /// Whether the device currently has network connectivity.
  bool get isOnline => _platform.isOnline;

  /// Stream of connectivity changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged => _platform.onConnectivityChanged;

  /// Initialize the connectivity monitor. Call once at app startup.
  void initialize() {
    _platform = PlatformConnectivityImpl();
    _platform.initialize();
  }

  /// Dispose resources.
  void dispose() {
    _platform.dispose();
  }
}
