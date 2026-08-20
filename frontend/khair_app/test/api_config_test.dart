import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/config/api_config.dart';

void main() {
  test('WebSocket URL extends the API path without a duplicate slash', () {
    final uri = ApiConfig.webSocketUri('test-token');

    expect(uri.scheme, 'wss');
    expect(uri.path, '/api/v1/ws');
    expect(uri.queryParameters['token'], 'test-token');
  });
}
