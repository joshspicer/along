import 'package:along/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('app routes use opaque no-transition pages', () {
    final page = appPageForTest(const ColoredBox(color: Colors.teal));

    expect(page, isA<CustomTransitionPage<void>>());
    expect(page.opaque, isTrue);
    expect(page.transitionDuration, Duration.zero);
  });

  test('invite survives redirects through account recovery', () {
    const invite = 'private_token-with-safe.characters';

    expect(
      inviteLocationForTest('/recovery-kit', invite),
      '/recovery-kit?invite=private_token-with-safe.characters',
    );
    expect(inviteLocationForTest('/recovery-kit', null), '/recovery-kit');
    expect(postRecoveryLocationForTest(invite), '/join/$invite');
  });

  test('account setup without an invitation ends at focus', () {
    expect(postRecoveryLocationForTest(null), '/focus');
  });
}
