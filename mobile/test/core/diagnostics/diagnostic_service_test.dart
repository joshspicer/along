import 'package:along/core/config/runtime_config.dart';
import 'package:along/core/diagnostics/diagnostic_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics retain only allowlisted bounded scalar fields', () {
    const config = RuntimeConfig(
      apiBaseUrl: 'https://along.spicer.dev',
      apnsEnvironment: 'production',
      requestTimeoutSeconds: 20,
    );
    final diagnostics = DiagnosticService(config);

    diagnostics.record('not.allowed', const {'token': 'secret'});
    diagnostics.record('network.failure', {
      'path': '/v1/auth/register/options',
      'status': 500,
      'description': 'x' * 300,
      'nested': const {'secret': true},
    });

    expect(diagnostics.events, hasLength(1));
    final event = diagnostics.events.single;
    expect(event.name, 'network.failure');
    expect(event.fields['status'], 500);
    expect((event.fields['description']! as String).length, 200);
    expect(event.fields, isNot(contains('nested')));
    expect(diagnostics.debugReport, isNot(contains('secret')));
  });

  test('diagnostics ring buffer keeps the latest fifty events', () {
    const config = RuntimeConfig(
      apiBaseUrl: 'https://along.spicer.dev',
      apnsEnvironment: 'production',
      requestTimeoutSeconds: 20,
    );
    final diagnostics = DiagnosticService(config);

    for (var index = 0; index < 60; index++) {
      diagnostics.record('auth.state', {'index': index});
    }

    expect(diagnostics.events, hasLength(50));
    expect(diagnostics.events.first.fields['index'], 10);
    expect(diagnostics.events.last.fields['index'], 59);
  });
}
