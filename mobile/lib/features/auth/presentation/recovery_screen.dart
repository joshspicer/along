import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import '../data/auth_repository.dart';
import 'onboarding_scaffold.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _handle = TextEditingController();
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    eyebrow: 'Recovery',
    title: 'Use a recovery code.',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _handle,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Recovery handle'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'One-time code'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        AsyncButton(
          label: 'Recover account',
          icon: Icons.shield_outlined,
          busy: ref.watch(authControllerProvider).isLoading,
          onPressed: _recover,
        ),
      ],
    ),
  );

  Future<void> _recover() async {
    if (_handle.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() => _error = 'Enter both details from your recovery kit.');
      return;
    }
    try {
      setState(() => _error = null);
      await ref
          .read(authControllerProvider.notifier)
          .recover(recoveryHandle: _handle.text, code: _code.text);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    }
  }
}
