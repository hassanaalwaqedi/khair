import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Consistent Back behaviour for routes that may be opened directly from a
/// notification, a shared URL, or browser refresh.  A normal in-app route is
/// popped; a route with no local history returns to its intentional fallback
/// instead of closing the application.
extension KhairNavigation on BuildContext {
  bool get canNavigateBack => GoRouter.of(this).canPop();

  void popOrGo<T>(String fallbackLocation, {T? result}) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      if (kDebugMode) debugPrint('[navigation] pop');
      router.pop<T>(result);
      return;
    }

    if (kDebugMode) {
      debugPrint('[navigation] no local history; going to $fallbackLocation');
    }
    // A system Back callback is still inside Navigator's pop transaction.
    // Scheduling the replacement for the next frame avoids a dropped go()
    // when the app was opened from an external platform route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(fallbackLocation);
    });
  }
}

/// Intercepts Android/system Back only when [child] has no route beneath it.
/// It deliberately does not interfere with ordinary Navigator pops, dialogs,
/// or bottom sheets, which are always dismissed before the page itself.
class RouteBackFallback extends StatelessWidget {
  const RouteBackFallback({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canNavigateBack;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.popOrGo(fallbackLocation);
      },
      child: child,
    );
  }
}
