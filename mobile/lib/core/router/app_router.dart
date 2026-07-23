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
import '../../features/settings/presentation/advanced_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../config/runtime_config.dart';
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
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) => _page(const _SplashScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, state) =>
            _page(WelcomeScreen(invite: state.uri.queryParameters['invite'])),
      ),
      GoRoute(
        path: '/passkey',
        pageBuilder: (_, state) => _page(
          PasskeyScreen(login: state.uri.queryParameters['mode'] == 'login'),
        ),
      ),
      GoRoute(
        path: '/recover',
        pageBuilder: (_, _) => _page(const RecoveryScreen()),
      ),
      GoRoute(
        path: '/recovery-kit',
        pageBuilder: (_, _) => _page(const RecoveryKitScreen()),
      ),
      GoRoute(
        path: '/join/:token',
        pageBuilder: (_, state) =>
            _page(PairingScreen(incomingToken: state.pathParameters['token']!)),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, _) => _page(const NotificationScreen()),
      ),
      ShellRoute(
        pageBuilder: (_, state, child) =>
            _page(PrimaryScaffold(location: state.uri.path, child: child)),
        routes: [
          GoRoute(
            path: '/focus',
            pageBuilder: (_, _) => _page(const FocusScreen()),
          ),
          GoRoute(
            path: '/look-back',
            pageBuilder: (_, _) => _page(const LookBackScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/live/:sessionId',
        pageBuilder: (_, state) => _page(
          LiveFocusScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/complete/:sessionId',
        pageBuilder: (_, state) => _page(
          CompletionScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, _) => _page(const SettingsScreen()),
      ),
      GoRoute(
        path: '/settings/advanced',
        pageBuilder: (_, _) => _page(const AdvancedSettingsScreen()),
      ),
    ],
    errorBuilder: (_, _) => const _NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _page(Widget child) => appPageForTest(child);

@visibleForTesting
CustomTransitionPage<void> appPageForTest(Widget child) => CustomTransitionPage(
  opaque: true,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  transitionsBuilder: (_, _, _, child) => child,
  child: child,
);

String? _redirect(Ref ref, GoRouterState route) {
  final authAsync = ref.read(authControllerProvider);
  final path = route.uri.path;
  String? redirect(String destination, String reason) {
    ref.read(diagnosticServiceProvider).record('route.redirect', {
      'from': _diagnosticRoute(path),
      'to': _diagnosticRoute(destination),
      'reason': reason,
    });
    return destination;
  }

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
  if (!auth.canUseApp) {
    final publicPath =
        path == '/welcome' ||
        path == '/passkey' ||
        path == '/recover' ||
        path == '/settings/advanced';
    if (path.startsWith('/join/') && invite != null) {
      return redirect(
        inviteLocationForTest('/welcome', invite),
        'signed_out_invite',
      );
    }
    if (auth.isOfflineGuest) {
      if (path == '/splash' ||
          path == '/welcome' ||
          path == '/passkey' ||
          path == '/recover' ||
          path.startsWith('/join/') ||
          path == '/notifications') {
        return redirect('/focus', 'offline_guest');
      }
      return null;
    }
    return publicPath ? null : redirect('/welcome', 'signed_out');
  }
  if (auth.recoveryKit != null && path != '/recovery-kit') {
    return redirect(
      inviteLocationForTest('/recovery-kit', invite),
      'recovery_kit',
    );
  }
  if (auth.recoveryKit == null && path == '/recovery-kit') {
    return redirect(
      postRecoveryLocationForTest(invite),
      'recovery_acknowledged',
    );
  }
  if (auth.account?.pairId == null) {
    if (path.startsWith('/join/')) {
      return null;
    }
    if (invite != null) {
      return redirect('/join/$invite', 'incoming_invite');
    }
    if (path == '/splash' ||
        path == '/welcome' ||
        path == '/passkey' ||
        path == '/recover' ||
        path == '/notifications') {
      return redirect('/focus', 'unpaired_solo');
    }
    return null;
  }
  if (!auth.notificationsExplained && path != '/notifications') {
    return redirect('/notifications', 'notification_setup');
  }
  if (path == '/splash' ||
      path == '/welcome' ||
      path == '/passkey' ||
      path == '/recover' ||
      path.startsWith('/join/') ||
      path == '/notifications') {
    return redirect('/focus', 'authenticated');
  }
  return null;
}

String _diagnosticRoute(String path) {
  if (path.startsWith('/join/')) return '/join/:token';
  if (path.startsWith('/live/')) return '/live/:sessionId';
  if (path.startsWith('/complete/')) return '/complete/:sessionId';
  return Uri.tryParse(path)?.path ?? path;
}

@visibleForTesting
String inviteLocationForTest(String path, String? invite) {
  if (invite == null || invite.isEmpty) return path;
  return Uri(path: path, queryParameters: {'invite': invite}).toString();
}

@visibleForTesting
String postRecoveryLocationForTest(String? invite) =>
    invite == null || invite.isEmpty ? '/focus' : '/join/$invite';

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(runtimeConfigProvider, (_, _) => notifyListeners());
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
