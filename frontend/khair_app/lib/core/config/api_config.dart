/// Centralized API configuration.
///
/// All files that need the backend URL should import this file
/// instead of hardcoding URLs.
class ApiConfig {
  ApiConfig._();

  /// The base API URL including the `/api/v1` path prefix.
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://khair-evdzcxfucuh4g2c9.swedencentral-01.azurewebsites.net/api/v1',
  );

  /// The server origin (scheme + host), without any path.
  static final serverOrigin = _extractOrigin(apiBaseUrl);

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
      return 'https://khair-evdzcxfucuh4g2c9.swedencentral-01.azurewebsites.net';
    }
  }
}
