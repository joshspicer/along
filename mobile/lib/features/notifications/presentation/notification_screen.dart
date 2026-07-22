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
    eyebrow: 'Notifications',
    title: 'Know when they start.',
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
        const SizedBox(height: 12),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 28),
        AsyncButton(
          label: 'Allow notifications',
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
