import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Lightweight crash reporting service.
///
/// Captures uncaught Flutter errors and Dart zone errors.
/// Logs them to the console in debug mode. In production this can be
/// extended to send reports to Firebase Crashlytics, Sentry, or a
/// custom backend endpoint.
///
/// Usage — call [CrashReporter.init] in `main()`:
/// ```dart
/// void main() {
///   CrashReporter.init(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await configureDependencies();
///     runApp(const KhairApp());
///   });
/// }
/// ```
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._();
  CrashReporter._();

  /// Whether the reporter has been initialised.
  static bool _initialised = false;

  /// Initialise crash reporting and run the app inside a guarded zone.
  static void init(Future<void> Function() appRunner) {
    // Catch Flutter framework errors (widget build, layout, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // keep default red‐screen in debug
      _instance._recordFlutterError(details);
    };

    // Catch errors on the platform thread
    PlatformDispatcher.instance.onError = (error, stack) {
      _instance._recordError(error, stack, reason: 'PlatformDispatcher');
      return true; // prevent default crash
    };

    // Catch errors from background isolates
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final errorAndStack = pair as List<dynamic>;
      _instance._recordError(
        errorAndStack.first,
        StackTrace.fromString(errorAndStack.last.toString()),
        reason: 'Isolate',
      );
    }).sendPort);

    // Run app inside a zone to catch anything that slips through
    runZonedGuarded(
      () async {
        await appRunner();
        _initialised = true;
      },
      (error, stack) {
        _instance._recordError(error, stack, reason: 'runZonedGuarded');
      },
    );
  }

  // ── Recording ──

  void _recordFlutterError(FlutterErrorDetails details) {
    _log(
      'FlutterError',
      details.exceptionAsString(),
      details.stack,
      library: details.library,
    );

    // TODO: When Firebase Crashlytics is configured, uncomment:
    // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  void _recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) {
    _log(reason ?? 'Uncaught', error.toString(), stack);

    // TODO: When Firebase Crashlytics is configured, uncomment:
    // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }

  /// Record a non‑fatal error manually from anywhere in the app.
  static void reportError(Object error, StackTrace? stack, {String? reason}) {
    _instance._recordError(error, stack, reason: reason ?? 'manual');
  }

  // ── Logging ──

  void _log(String source, String message, StackTrace? stack, {String? library}) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 CRASH REPORT [$source]');
      if (library != null) debugPrint('   Library: $library');
      debugPrint('   Error: $message');
      if (stack != null) {
        debugPrint('   Stack:\n${stack.toString().split('\n').take(8).join('\n')}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // TODO: In production, post to /api/v1/crash-reports or Crashlytics
  }
}
