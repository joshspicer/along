import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/server_availability.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../../core/widgets/async_button.dart';
import 'onboarding_scaffold.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.invite});

  final String? invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(serverAvailabilityProvider).value;
    final serverUnavailable = availability == ServerAvailability.unavailable;
    return OnboardingScaffold(
      eyebrow: 'Along',
      title: 'Focus, together.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start on your own. Your partner can join anytime.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 38),
          Semantics(
            label: 'Two people connected privately',
            child: const _PairIllustration(),
          ),
          const SizedBox(height: 38),
          if (serverUnavailable) ...[
            Text(
              'The shared service is offline. Solo focus still works.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            AsyncButton(
              label: 'Continue offline',
              icon: Icons.offline_bolt_rounded,
              onPressed: () async {
                await ref
                    .read(authControllerProvider.notifier)
                    .continueOffline();
              },
            ),
          ] else ...[
            AsyncButton(
              label: 'Create our space',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go(_passkeyLocation('create')),
            ),
            const SizedBox(height: 10),
            AsyncButton(
              label: 'Sign in with a passkey',
              outlined: true,
              icon: Icons.key_rounded,
              onPressed: () => context.go(_passkeyLocation('login')),
            ),
            TextButton(
              onPressed: () => context.go('/recover'),
              child: const Text('Use a recovery code'),
            ),
          ],
        ],
      ),
      footer: Text(
        'Private. Just the two of you.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _passkeyLocation(String mode) {
    final query = <String, String>{'mode': mode};
    if (invite != null) {
      query['invite'] = invite!;
    }
    return Uri(path: '/passkey', queryParameters: query).toString();
  }
}

class _PairIllustration extends StatelessWidget {
  const _PairIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 220,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: context.colorScheme.outlineVariant),
            borderRadius: const BorderRadius.all(Radius.elliptical(220, 120)),
          ),
        ),
        Transform.translate(
          offset: const Offset(-62, -28),
          child: _person(context, 'J', context.colorScheme.primary),
        ),
        Transform.translate(
          offset: const Offset(62, 28),
          child: _person(context, 'A', context.colorScheme.secondary),
        ),
        Icon(Icons.auto_awesome_rounded, color: context.colorScheme.tertiary),
      ],
    ),
  );

  Widget _person(BuildContext context, String label, Color color) => Container(
    width: 82,
    height: 82,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: context.colorScheme.surface, width: 5),
    ),
    child: Text(
      label,
      style: context.textTheme.headlineMedium?.copyWith(
        color: context.colorScheme.surface,
      ),
    ),
  );
}
