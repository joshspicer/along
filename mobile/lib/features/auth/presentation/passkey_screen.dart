import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import '../data/auth_repository.dart';
import 'onboarding_scaffold.dart';

class PasskeyScreen extends ConsumerStatefulWidget {
  const PasskeyScreen({required this.login, super.key});

  final bool login;

  @override
  ConsumerState<PasskeyScreen> createState() => _PasskeyScreenState();
}

class _PasskeyScreenState extends ConsumerState<PasskeyScreen> {
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return OnboardingScaffold(
      eyebrow: widget.login ? 'Welcome back' : 'Passkey-first and private',
      title: widget.login
          ? 'Use your passkey to come back.'
          : 'Create your private account.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.login
                ? 'Your passkey confirms it is you. There is no password to remember.'
                : 'Along uses the passkey already protected by your device. Your account can move across devices and keeps your pair.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (!widget.login) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Your first name or nickname',
                hintText: 'Jamie',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          AsyncButton(
            label: widget.login
                ? 'Continue with passkey'
                : 'Create with passkey',
            icon: Icons.key_rounded,
            busy: busy,
            onPressed: _submit,
          ),
        ],
      ),
      footer: const Text(
        'Along never receives your device unlock code, Face ID, fingerprint, or passcode.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _submit() async {
    if (!widget.login && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Add the name you want your partner to see.');
      return;
    }
    setState(() => _error = null);
    try {
      if (widget.login) {
        await ref.read(authControllerProvider.notifier).signIn();
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .register(_nameController.text.trim());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    }
  }
}
