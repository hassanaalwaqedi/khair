/// Centralized API configuration.
///
/// All files that need the backend URL should import this file
/// instead of hardcoding URLs.
class ApiConfig {
  ApiConfig._();

  /// Compile-time env override (pass `--dart-define=API_URL=...`).
  static const _envApiUrl = String.fromEnvironment('API_URL');
  static const _envPublicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');

  /// The base API URL including the `/api/v1` path prefix.
  /// Debug builds default to localhost; release builds default to production.
  static final String apiBaseUrl = () {
    String url = _envApiUrl.isNotEmpty
        ? _envApiUrl
        : 'https://khair-4adc.onrender.com/api/v1';
    return url.endsWith('/') ? url : '$url/';
  }();

  /// The server origin (scheme + host), without any path.
  static final serverOrigin = _extractOrigin(apiBaseUrl);

  static final String publicAppUrl = () {
    String url =
        _envPublicAppUrl.isNotEmpty ? _envPublicAppUrl : 'https://khair.app';
    return url.replaceFirst(RegExp(r'/$'), '');
  }();

  /// Builds the WebSocket endpoint from the API base without accidentally
  /// duplicating the trailing slash before `/ws`.
  static Uri webSocketUri(String token) {
    final apiUri = Uri.parse(apiBaseUrl);
    final normalizedPath = apiUri.path.replaceFirst(RegExp(r'/+$'), '');
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return apiUri.replace(
      scheme: scheme,
      path: '$normalizedPath/ws',
      queryParameters: {'token': token},
    );
  }

  /// Event share links point to the canonical public domain.
  static String publicEventUrl(String eventId) =>
      '$publicAppUrl/events/$eventId';

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
