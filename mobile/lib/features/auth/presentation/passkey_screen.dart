import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

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
  String? _debugReport;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return OnboardingScaffold(
      eyebrow: widget.login ? 'Welcome back' : 'Private account',
      title: widget.login
          ? 'Sign in with your passkey.'
          : 'Create your account.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.login
                ? 'No password needed.'
                : 'Your device keeps your passkey safe.',
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
            if (_debugReport != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _copyDiagnostics,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy diagnostics'),
                ),
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
      footer: const Text('Protected by your device.'),
    );
  }

  Future<void> _submit() async {
    if (!widget.login && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Add the name you want your partner to see.');
      return;
    }
    setState(() {
      _error = null;
      _debugReport = null;
    });
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
        setState(() {
          _error = friendlyNetworkError(error);
          _debugReport = error is PasskeyException ? error.debugReport : null;
        });
      }
    }
  }

  Future<void> _copyDiagnostics() async {
    final report = _debugReport;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied.')),
      );
    }
  }
}
