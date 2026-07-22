import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/focus_session.dart';
import 'authoritative_timer.dart';

class LiveFocusScreen extends ConsumerStatefulWidget {
  const LiveFocusScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<LiveFocusScreen> createState() => _LiveFocusScreenState();
}

class _LiveFocusScreenState extends ConsumerState<LiveFocusScreen> {
  bool _busy = false;
  bool _elapsedHandled = false;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(sessionRepositoryProvider);
    final account = ref.watch(authControllerProvider).requireValue.account!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Focus',
          onPressed: () => context.go('/focus'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Focus now'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Semantics(
                label: 'Session status',
                child: const _LiveBadge(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<FocusSession?>(
          stream: repository.watchCurrent(),
          builder: (context, snapshot) {
            final session = snapshot.data;
            if (session == null || session.id != widget.sessionId) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _EndedState(onReturn: () => context.go('/look-back'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      _Presence(session: session, accountId: account.id),
                      const SizedBox(height: 8),
                      AuthoritativeTimer(
                        session: session,
                        authoritativeNow: () => repository.authoritativeNow,
                        onElapsed: () => _elapsed(session),
                      ),
                      const SizedBox(height: 14),
                      _SyncStatus(session: session),
                      const SizedBox(height: 34),
                      _Actions(
                        session: session,
                        busy: _busy,
                        onPauseResume: () => _pauseResume(session),
                        onCheer: () => _cheer(session),
                        onFinish: () => _finish(session),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pauseResume(FocusSession session) => _run(() async {
    final repository = ref.read(sessionRepositoryProvider);
    if (session.state == SessionState.paused) {
      await repository.resume(session);
    } else {
      await repository.pause(session);
    }
  });

  Future<void> _cheer(FocusSession session) => _run(() async {
    await ref.read(sessionRepositoryProvider).cheer(session);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A quiet cheer reached your partner.')),
      );
    }
  });

  Future<void> _finish(FocusSession session) => _run(() async {
    await ref.read(sessionRepositoryProvider).complete(session);
    if (mounted) {
      context.go('/complete/${session.id}');
    }
  });

  Future<void> _elapsed(FocusSession session) async {
    if (_elapsedHandled) {
      return;
    }
    _elapsedHandled = true;
    await _finish(session);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyNetworkError(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'Live',
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Presence extends StatelessWidget {
  const _Presence({required this.session, required this.accountId});

  final FocusSession session;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final together = session.participants.length > 1;
    return Semantics(
      label: together
          ? 'You and your partner are both here'
          : 'You are focusing. Your partner can join.',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _avatar(context, 'You', context.colorScheme.primary),
          if (together) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 1,
                    color: context.colorScheme.outline,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.favorite_outline_rounded,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 1,
                    color: context.colorScheme.outline,
                  ),
                ],
              ),
            ),
            _avatar(
              context,
              session.participants
                  .firstWhere(
                    (participant) => participant.accountId != accountId,
                  )
                  .displayName,
              context.colorScheme.secondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String label, Color color) => Column(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: color,
        foregroundColor: context.colorScheme.surface,
        child: Text(label.characters.first.toUpperCase()),
      ),
      const SizedBox(height: 5),
      Text(label, style: context.textTheme.labelMedium),
    ],
  );
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          session.offlineOrigin
              ? Icons.cloud_off_outlined
              : Icons.check_circle_outline,
          size: 18,
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            session.offlineOrigin
                ? 'Saved on this device'
                : session.state == SessionState.together
                ? 'Together'
                : 'Room open',
            style: context.textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.session,
    required this.busy,
    required this.onPauseResume,
    required this.onCheer,
    required this.onFinish,
  });

  final FocusSession session;
  final bool busy;
  final VoidCallback onPauseResume;
  final VoidCallback onCheer;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      _Action(
        label: session.state == SessionState.paused ? 'Resume' : 'Pause',
        icon: session.state == SessionState.paused
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded,
        onPressed: busy ? null : onPauseResume,
      ),
      if (session.state == SessionState.together)
        _Action(
          label: 'Cheer',
          icon: Icons.volunteer_activism_outlined,
          emphasized: true,
          onPressed: busy ? null : onCheer,
        ),
      _Action(
        label: 'Finish',
        icon: Icons.check_rounded,
        onPressed: busy ? null : onFinish,
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 92,
      height: 76,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(height: 5), Text(label)],
      ),
    );
    return emphasized
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _EndedState extends StatelessWidget {
  const _EndedState({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 52),
          const SizedBox(height: 16),
          Text(
            'This focus has ended.',
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onReturn,
            child: const Text('Open Look back'),
          ),
        ],
      ),
    ),
  );
}
