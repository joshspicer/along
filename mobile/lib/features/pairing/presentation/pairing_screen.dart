import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/onboarding_scaffold.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({required this.incomingToken, super.key});

  final String incomingToken;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    eyebrow: 'Private invitation',
    title: 'Join your person.',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You opened a private Along invitation. Join it to create your shared focus space.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        AsyncButton(
          label: 'Join private space',
          icon: Icons.people_alt_outlined,
          busy: _busy,
          onPressed: _accept,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => context.go('/focus'),
          child: const Text('Not now'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    footer: const Text('Only accept invitations from someone you know.'),
  );

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .acceptPairInvite(widget.incomingToken);
    } on Object catch (error) {
      if (mounted) {
        ref.read(diagnosticServiceProvider).record('pairing.failure', {
          'operation': 'accept',
          'error_type': error.runtimeType.toString(),
        });
        setState(() => _error = friendlyNetworkError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
