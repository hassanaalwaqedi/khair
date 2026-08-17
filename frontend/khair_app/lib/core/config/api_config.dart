import 'package:flutter/foundation.dart';

/// Centralized API configuration.
///
/// All files that need the backend URL should import this file
/// instead of hardcoding URLs.
class ApiConfig {
  ApiConfig._();

  /// Compile-time env override (pass `--dart-define=API_URL=...`).
  static const _envApiUrl = String.fromEnvironment('API_URL');

  /// The base API URL including the `/api/v1` path prefix.
  /// Debug builds default to localhost; release builds default to production.
  static final String apiBaseUrl = () {
    String url = _envApiUrl.isNotEmpty
        ? _envApiUrl
        : (kDebugMode
            ? 'http://localhost:8080/api/v1'
            : 'https://api.khair.it.com/api/v1');
    return url.endsWith('/') ? url : '$url/';
  }();

  /// The server origin (scheme + host), without any path.
  static final serverOrigin = _extractOrigin(apiBaseUrl);

  /// Event share links point to the API origin. It returns static Open Graph
  /// metadata for social crawlers, then redirects people to the Flutter app.
  /// Flutter hash routes cannot be crawled by WhatsApp, LinkedIn, or Telegram.
  static String publicEventUrl(String eventId) =>
      '${serverOrigin.replaceFirst(RegExp(r'/$'), '')}/events/$eventId';

  /// Resolves a potentially relative URL to an absolute URL.
  /// Already-absolute URLs are returned as-is.
  static String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$serverOrigin$url';
  }

  static String _extractOrigin(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    } catch (_) {
      return 'https://api.khair.it.com';
    }
  }
}
