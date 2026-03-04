import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Handles network errors and provides user-friendly messages
class NetworkErrorHandler {
  /// Get user-friendly message for network errors
  static String getMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    
    if (errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }
    
    if (errorString.contains('certificate') ||
        errorString.contains('ssl') ||
        errorString.contains('handshake')) {
      return 'Secure connection failed. Please try again later.';
    }
    
    if (errorString.contains('403') ||
        errorString.contains('forbidden')) {
      return 'Access denied. You may not have permission for this action.';
    }
    
    if (errorString.contains('404') ||
        errorString.contains('not found')) {
      return 'The requested resource was not found.';
    }
    
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Server error. Please try again later.';
    }
    
    if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    
    if (errorString.contains('feature_disabled') ||
        errorString.contains('lockdown')) {
      return 'This feature is temporarily disabled.';
    }
    
    return 'An error occurred. Please try again.';
  }

  /// Get retry policy based on error type
  static bool shouldRetry(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Retry on network/timeout errors
    if (errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socketexception')) {
      return true;
    }
    
    // Don't retry on auth/permission errors
    if (errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('unauthorized')) {
      return false;
    }
    
    // Retry on server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return true;
    }
    
    return false;
  }
}

/// Production logger that respects environment settings
class ProductionLogger {
  static bool _enabled = !kReleaseMode;

  /// Enable or disable logging
  static void setEnabled(bool enabled) {
    _enabled = enabled && !kReleaseMode;
  }

  /// Log debug message (only in debug mode)
  static void debug(String message, [Map<String, dynamic>? data]) {
    if (_enabled && kDebugMode) {
      _log('DEBUG', message, data);
    }
  }

  /// Log info message
  static void info(String message, [Map<String, dynamic>? data]) {
    if (_enabled) {
      _log('INFO', message, data);
    }
  }

  /// Log warning message
  static void warn(String message, [Map<String, dynamic>? data]) {
    if (_enabled) {
      _log('WARN', message, data);
    }
  }

  /// Log error message (always logged for crash reporting)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    // Always log errors for crash reporting
    _log('ERROR', message, {'error': error?.toString()});
    
    if (kDebugMode && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void _log(String level, String message, Map<String, dynamic>? data) {
    final timestamp = DateTime.now().toIso8601String();
    String log = '[$timestamp] $level: $message';
    
    if (data != null && data.isNotEmpty) {
      // Sanitize sensitive data
      final sanitized = _sanitize(data);
      log += ' | ${sanitized.toString()}';
    }
    
    debugPrint(log);
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    const sensitiveKeys = ['password', 'token', 'secret', 'authorization'];
    
    return data.map((key, value) {
      if (sensitiveKeys.any((k) => key.toLowerCase().contains(k))) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }
}

/// Check current platform for conditional behavior
class PlatformInfo {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
