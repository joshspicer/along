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
}
