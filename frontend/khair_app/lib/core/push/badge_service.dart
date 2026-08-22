import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_app_badger/flutter_app_badger.dart';

/// Updates the launcher icon badge count on Android (Samsung/Xiaomi/Sony etc.)
/// and iOS. Stock Pixel/AOSP launchers show notification dots automatically
/// without this package; numeric counts require manufacturer support.
///
/// All calls are safe on platforms where badges are unsupported — the package
/// silently no-ops when the launcher does not have the feature.
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  /// Set [count] as the launcher badge number.
  /// Pass 0 to clear the badge.
  Future<void> updateBadge(int count) async {
    if (kIsWeb) return;
    try {
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (_) {
      // Badge API not available on this launcher — fail silently.
      // App correctness never depends on badge support.
    }
  }

  /// Clear the launcher badge (equivalent to updateBadge(0)).
  Future<void> clearBadge() => updateBadge(0);
}
