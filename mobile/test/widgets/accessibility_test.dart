import 'package:along/core/router/primary_scaffold.dart';
import 'package:along/core/theme/along_theme.dart';
import 'package:along/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'welcome supports large text and exposes one clear primary action',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
          GoRoute(path: '/passkey', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/recover', builder: (_, _) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AlongTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create our space'), findsOneWidget);
      expect(find.text('Focus'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('primary navigation contains only Focus and Look back', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/focus',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              PrimaryScaffold(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/focus', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/look-back', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AlongTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Look back'), findsOneWidget);
  });
}
