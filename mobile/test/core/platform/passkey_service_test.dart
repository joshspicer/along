import 'package:along/core/platform/passkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passkey debug report includes server correlation and native details', () {
    const error = PasskeyException(
      'Passkey failed (Apple error 1004).',
      diagnosticId: 'diagnostic-123',
      details: <String, Object?>{
        'domain': 'com.apple.AuthenticationServices.AuthorizationError',
        'code': 1004,
      },
    );

    expect(error.debugReport, contains('Diagnostic ID: diagnostic-123'));
    expect(error.debugReport, contains('code: 1004'));
    expect(error.debugReport, isNot(contains('challenge')));
    expect(error.debugReport, isNot(contains('credential')));
  });
}