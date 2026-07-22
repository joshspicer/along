import 'package:along/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug builds default to the local API', () {
    expect(AppConfig.defaultApiBaseUrl, 'http://localhost:8080');
  });
}
