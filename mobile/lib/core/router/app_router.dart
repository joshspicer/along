import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/passkey_screen.dart';
import '../../features/auth/presentation/recovery_kit_screen.dart';
import '../../features/auth/presentation/recovery_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/focus/presentation/completion_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/focus/presentation/live_focus_screen.dart';
import '../../features/history/presentation/look_back_screen.dart';
import '../../features/notifications/presentation/notification_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../providers.dart';
import 'primary_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(
        path: '/welcome',
        builder: (_, state) =>
            WelcomeScreen(invite: state.uri.queryParameters['invite']),
      ),
      GoRoute(
        path: '/passkey',
        builder: (_, state) =>
            PasskeyScreen(login: state.uri.queryParameters['mode'] == 'login'),
      ),
      GoRoute(path: '/recover', builder: (_, _) => const RecoveryScreen()),
      GoRoute(
        path: '/recovery-kit',
        builder: (_, _) => const RecoveryKitScreen(),
      ),
      GoRoute(path: '/pair', builder: (_, _) => const PairingScreen()),
      GoRoute(
        path: '/join/:token',
        builder: (_, state) =>
            PairingScreen(incomingToken: state.pathParameters['token']),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            PrimaryScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/focus', builder: (_, _) => const FocusScreen()),
          GoRoute(
            path: '/look-back',
            builder: (_, _) => const LookBackScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/live/:sessionId',
        builder: (_, state) =>
            LiveFocusScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/complete/:sessionId',
        builder: (_, state) =>
            CompletionScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
    errorBuilder: (_, _) => const _NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirect(Ref ref, GoRouterState route) {
  final authAsync = ref.read(authControllerProvider);
  final path = route.uri.path;
  final auth = switch (authAsync) {
    AsyncData<AuthState>(:final value) => value,
    _ => null,
  };
  if (auth == null) {
    return path == '/splash' ? null : null;
  }
  final invite =
      route.uri.queryParameters['invite'] ??
      (path.startsWith('/join/') ? route.pathParameters['token'] : null);
  if (!auth.isSignedIn) {
    final publicPath =
        path == '/welcome' || path == '/passkey' || path == '/recover';
    if (path.startsWith('/join/') && invite != null) {
      return '/welcome?invite=$invite';
    }
    return publicPath ? null : '/welcome';
  }
  if (auth.recoveryKit != null && path != '/recovery-kit') {
    return '/recovery-kit';
  }
  if (auth.recoveryKit == null && path == '/recovery-kit') {
    return '/pair';
  }
  if (auth.account?.pairId == null) {
    if (path.startsWith('/join/') || path == '/pair') {
      return null;
    }
    if (invite != null) {
      return '/join/$invite';
    }
    return '/pair';
  }
  if (!auth.notificationsExplained && path != '/notifications') {
    return '/notifications';
  }
  if (path == '/splash' ||
      path == '/welcome' ||
      path == '/passkey' ||
      path == '/recover' ||
      path == '/pair' ||
      path.startsWith('/join/') ||
      path == '/notifications') {
    return '/focus';
  }
  return null;
}

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Semantics(
          label: 'Opening Along',
          child: const CircularProgressIndicator(),
        ),
      ),
    ),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/focus'),
        child: const Text('Return to Along'),
      ),
    ),
  );
}
