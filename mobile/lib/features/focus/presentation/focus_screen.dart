import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../../core/widgets/async_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_models.dart';
import '../data/session_repository.dart';
import '../domain/focus_session.dart';
import 'authoritative_timer.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _busy = false;
  bool _offline = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authControllerProvider).requireValue.account!;
    final repository = ref.watch(sessionRepositoryProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(account: account),
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              final values = snapshot.data;
              final offline =
                  values != null &&
                  values.isNotEmpty &&
                  values.every((value) => value == ConnectivityResult.none);
              if (offline != _offline) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _offline = offline);
                  }
                });
              }
              return AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: offline
                    ? const _OfflineBanner()
                    : const SizedBox.shrink(),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<FocusSession?>(
              stream: repository.watchCurrent(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: repository.watchCurrent);
                }
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _FocusContent(
                  account: account,
                  session: snapshot.data,
                  repository: repository,
                  offline: _offline,
                  busy: _busy,
                  error: _error,
                  onStart: _start,
                  onJoin: _join,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final account = ref.read(authControllerProvider).requireValue.account!;
    await _run(() async {
      final session = await ref.read(sessionRepositoryProvider).start(account);
      if (mounted) {
        context.go('/live/${session.id}');
      }
    });
  }

  Future<void> _join(FocusSession session) async {
    await _run(() async {
      await ref.read(sessionRepositoryProvider).join(session);
      if (mounted) {
        context.go('/live/${session.id}');
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.account});

  final AuthAccount account;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
    child: Row(
      children: [
        const AlongMark(size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Focus',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: 'Account and devices',
          onPressed: () => context.push('/settings'),
          icon: CircleAvatar(
            backgroundColor: context.colorScheme.primary,
            foregroundColor: context.colorScheme.onPrimary,
            child: Text(account.displayName.characters.first.toUpperCase()),
          ),
        ),
      ],
    ),
  );
}

class _FocusContent extends StatelessWidget {
  const _FocusContent({
    required this.account,
    required this.session,
    required this.repository,
    required this.offline,
    required this.busy,
    required this.error,
    required this.onStart,
    required this.onJoin,
  });

  final AuthAccount account;
  final FocusSession? session;
  final SessionRepository repository;
  final bool offline;
  final bool busy;
  final String? error;
  final VoidCallback onStart;
  final ValueChanged<FocusSession> onJoin;

  @override
  Widget build(BuildContext context) {
    final current = session;
    final partnerActive =
        current != null && !current.includes(account.id) && current.isActive;
    final partnerName = account.partnerName ?? 'Your partner';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!offline && !account.isOfflineOnly)
                _PartnerStatus(
                  name: partnerName,
                  active: partnerActive,
                  unavailable: current?.offlineOrigin ?? false,
                ),
              SizedBox(height: offline || account.isOfflineOnly ? 4 : 20),
              Center(
                child: current == null
                    ? _ReadyTimer(repository: repository)
                    : AuthoritativeTimer(
                        session: current,
                        authoritativeNow: () => repository.authoritativeNow,
                        caption: partnerActive
                            ? '$partnerName is here'
                            : current.offlineOrigin
                            ? 'On this device'
                            : current.state == SessionState.together
                            ? 'Together'
                            : 'Room open',
                        compact: true,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                current == null
                    ? 'Start when you’re ready.'
                    : partnerActive
                    ? 'Join whenever you want.'
                    : current.offlineOrigin
                    ? 'A quiet focus, saved here.'
                    : 'Your room is already open.',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                current == null
                    ? offline || account.isOfflineOnly
                          ? 'Solo focus stays on this device.'
                          : '$partnerName can join anytime.'
                    : partnerActive
                    ? 'The same clock keeps running.'
                    : current.offlineOrigin
                    ? 'Solo until you reconnect.'
                    : '$partnerName can join anytime.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ],
              const SizedBox(height: 26),
              if (current == null)
                AsyncButton(
                  label: 'Start focus',
                  icon: Icons.play_arrow_rounded,
                  busy: busy,
                  onPressed: onStart,
                )
              else if (partnerActive)
                AsyncButton(
                  label: 'Join $partnerName',
                  icon: Icons.people_alt_outlined,
                  busy: busy,
                  onPressed: () => onJoin(current),
                )
              else
                AsyncButton(
                  label: 'Continue focus',
                  icon: Icons.timer_outlined,
                  onPressed: () => context.go('/live/${current.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyTimer extends StatelessWidget {
  const _ReadyTimer({required this.repository});

  final SessionRepository repository;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    return AuthoritativeTimer(
      session: FocusSession(
        id: 'ready',
        pairId: 'ready',
        startedBy: 'ready',
        state: SessionState.paused,
        durationSeconds: 1500,
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
        pausedAt: now,
        version: 1,
      ),
      authoritativeNow: () => repository.authoritativeNow,
      caption: 'Ready when you are',
      compact: true,
    );
  }
}

class _PartnerStatus extends StatelessWidget {
  const _PartnerStatus({
    required this.name,
    required this.active,
    required this.unavailable,
  });

  final String name;
  final bool active;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final title = active ? '$name is focusing' : '$name is nearby';
    final detail = active
        ? 'Room already running'
        : 'No shared session running';
    return Semantics(
      label: '$title. $detail.',
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          minTileHeight: 64,
          leading: CircleAvatar(
            backgroundColor: context.colorScheme.secondary,
            foregroundColor: context.colorScheme.onSecondary,
            child: Text(name.characters.first.toUpperCase()),
          ),
          title: Text(title),
          subtitle: Text(unavailable ? 'Reconnect to see updates' : detail),
          trailing: Icon(
            unavailable
                ? Icons.cloud_off_outlined
                : active
                ? Icons.radio_button_checked
                : Icons.circle_outlined,
            color: active
                ? context.colorScheme.tertiary
                : context.colorScheme.onSurfaceVariant,
            semanticLabel: active ? 'Active' : 'Not active',
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: context.colorScheme.tertiaryContainer,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 18),
          SizedBox(width: 8),
          Flexible(child: Text('Offline · solo focus syncs later')),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Object onRetry;

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Focus could not load. Your local sessions are still safe.'),
    ),
  );
}
