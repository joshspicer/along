import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/along_mark.dart';
import '../../../core/widgets/async_button.dart';
import 'onboarding_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.invite});

  final String? invite;

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    eyebrow: 'A shared place to show up',
    title: 'Make a little room that belongs to both of you.',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Focus on your own, meet in the same moment, and remember the time you found each other there.',
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
    ),
    footer: Text(
      'Private by default. Just the two of you.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

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
