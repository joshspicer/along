import 'dart:async';

import 'package:along/core/router/keyboard_dismissal_observer.dart';
import 'package:along/core/router/primary_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('dismisses the keyboard on root route navigation', (
    tester,
  ) async {
    final textFieldFocusNode = FocusNode();
    addTearDown(textFieldFocusNode.dispose);
    final router = GoRouter(
      initialLocation: '/input',
      observers: [KeyboardDismissalObserver()],
      routes: [
        GoRoute(
          path: '/input',
          builder: (_, _) =>
              Scaffold(body: TextField(focusNode: textFieldFocusNode)),
        ),
        GoRoute(
          path: '/next',
          builder: (_, _) => const Scaffold(body: Text('Next')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(textFieldFocusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    unawaited(router.push<void>('/next'));
    await tester.pumpAndSettle();

    expect(textFieldFocusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('dismisses the keyboard on shell route navigation', (
    tester,
  ) async {
    final textFieldFocusNode = FocusNode();
    addTearDown(textFieldFocusNode.dispose);
    final router = GoRouter(
      initialLocation: '/focus',
      routes: [
        ShellRoute(
          observers: [KeyboardDismissalObserver()],
          builder: (_, state, child) =>
              PrimaryScaffold(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/focus',
              builder: (_, _) => TextField(focusNode: textFieldFocusNode),
            ),
            GoRoute(
              path: '/look-back',
              builder: (_, _) => const Text('History'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(textFieldFocusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Look back'));
    await tester.pumpAndSettle();

    expect(textFieldFocusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
