import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/onboarding_scaffold.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, this.incomingToken});

  final String? incomingToken;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  late final TextEditingController _token = TextEditingController(
    text: widget.incomingToken,
  );
  Uri? _invite;
  bool _busy = false;
  String? _error;
  Timer? _pairPoll;

  @override
  void dispose() {
    _pairPoll?.cancel();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    eyebrow: 'One private pairing',
    title: 'Who are you sharing this with?',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Send one private link. It works once, expires in 48 hours, and never needs contact access.',
        ),
        const SizedBox(height: 24),
        if (_invite == null)
          AsyncButton(
            label: 'Create private pairing link',
            icon: Icons.link_rounded,
            busy: _busy,
            onPressed: _create,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(_invite.toString()),
                  const SizedBox(height: 12),
                  AsyncButton(
                    label: 'Share privately',
                    icon: Icons.ios_share_rounded,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        subject: 'Join me in Along',
                        text:
                            'Join our private Along space: ${_invite.toString()}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or open their link'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        TextField(
          controller: _token,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Private link or token'),
        ),
        const SizedBox(height: 12),
        AsyncButton(
          label: 'Join our space',
          outlined: true,
          icon: Icons.people_alt_outlined,
          busy: _busy,
          onPressed: _accept,
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
    footer: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.contacts_outlined, size: 18),
        SizedBox(width: 8),
        Flexible(child: Text('Along never uploads your contacts.')),
      ],
    ),
  );

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await ref
          .read(authControllerProvider.notifier)
          .createPairInvite();
      if (mounted) {
        setState(() => _invite = invite);
        _pairPoll ??= Timer.periodic(
          const Duration(seconds: 5),
          (_) => _checkForAcceptedInvite(),
        );
      }
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

  Future<void> _checkForAcceptedInvite() async {
    try {
      await ref.read(authControllerProvider.notifier).refreshAccount();
      final paired =
          ref.read(authControllerProvider).value?.account?.pairId != null;
      if (paired) {
        _pairPoll?.cancel();
      }
    } on Object {
      // Pairing remains usable offline; the next quiet poll retries.
    }
  }

  Future<void> _accept() async {
    if (_token.text.trim().isEmpty) {
      setState(() => _error = 'Paste the private pairing link first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .acceptPairInvite(_token.text);
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
