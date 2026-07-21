import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import '../../auth/presentation/onboarding_scaffold.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    eyebrow: 'Only partner moments',
    title: 'Know when your partner starts.',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            minTileHeight: 76,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            title: const Text('Along'),
            subtitle: const Text('Your partner started a 25-minute focus.'),
            trailing: const Text('now'),
          ),
        ),
        const SizedBox(height: 22),
        const _Promise(
          icon: Icons.shield_outlined,
          title: 'Quiet by design',
          detail: 'No streak warnings, marketing, or urgent pressure.',
        ),
        const _Promise(
          icon: Icons.tune_rounded,
          title: 'You stay in control',
          detail: 'Notifications remain optional and can be changed later.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 28),
        AsyncButton(
          label: 'Continue to device settings',
          icon: Icons.notifications_active_outlined,
          busy: _busy,
          onPressed: _request,
        ),
        TextButton(
          onPressed: _busy
              ? null
              : ref
                    .read(authControllerProvider.notifier)
                    .markNotificationsExplained,
          child: const Text('Not now'),
        ),
      ],
    ),
  );

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestNotifications();
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Notification permission could not be opened. You can continue without it.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 64,
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(detail),
  );
}
