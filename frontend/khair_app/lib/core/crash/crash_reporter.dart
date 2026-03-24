import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Lightweight crash reporting service with Sentry integration.
///
/// Captures uncaught Flutter errors and Dart zone errors.
/// In debug mode, logs to console. In production, reports to Sentry.
///
/// Usage — call [CrashReporter.init] in `main()`:
/// ```dart
/// void main() {
///   CrashReporter.init(
///     sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
///     appRunner: () async {
///       WidgetsFlutterBinding.ensureInitialized();
///       await configureDependencies();
///       runApp(const KhairApp());
///     },
///   );
/// }
/// ```
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._();
  CrashReporter._();

  /// Whether Sentry is enabled for this session.
  static bool _sentryEnabled = false;

  /// Initialise crash reporting and run the app inside a guarded zone.
  static Future<void> init({
    required Future<void> Function() appRunner,
    String sentryDsn = '',
  }) async {
    // If a Sentry DSN is provided and we're not in debug, use Sentry
    if (sentryDsn.isNotEmpty && !kDebugMode) {
      _sentryEnabled = true;
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = 0.3; // 30% of transactions
          options.environment = kReleaseMode ? 'production' : 'staging';
          options.sendDefaultPii = false;
        },
        appRunner: () => _runGuarded(appRunner),
      );
    } else {
      // No Sentry — run with basic guarded zone
      _runGuarded(appRunner);
    }
  }

  static void _runGuarded(Future<void> Function() appRunner) {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _instance._recordFlutterError(details);
    };

    // Catch platform dispatcher errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _instance._recordError(error, stack, reason: 'PlatformDispatcher');
      return true;
    };

    // Catch isolate errors (not available on web)
    if (!kIsWeb) {
      Isolate.current.addErrorListener(RawReceivePort((pair) async {
        final errorAndStack = pair as List<dynamic>;
        _instance._recordError(
          errorAndStack.first,
          StackTrace.fromString(errorAndStack.last.toString()),
          reason: 'Isolate',
        );
      }).sendPort);
    }

    // Run app inside a guarded zone
    runZonedGuarded(
      () async {
        await appRunner();
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

    if (_sentryEnabled) {
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    }
  }

  void _recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) {
    _log(reason ?? 'Uncaught', error.toString(), stack);

    if (_sentryEnabled) {
      Sentry.captureException(error, stackTrace: stack);
    }
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
  }
}

