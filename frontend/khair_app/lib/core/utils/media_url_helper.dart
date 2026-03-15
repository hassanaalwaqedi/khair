import 'package:dio/dio.dart';
import '../di/injection.dart';

/// Resolves a relative URL (like `/api/v1/files/images/abc.jpg`)
/// to an absolute URL by prepending the server origin derived from
/// the Dio base URL. Already-absolute URLs are returned as-is.
String resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;

  try {
    final dio = getIt<Dio>();
    final base = dio.options.baseUrl; // e.g. https://khair.it.com/api/v1
    final uri = Uri.parse(base);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$origin$url';
  } catch (_) {
    return 'https://khair.it.com$url';
  }
}
