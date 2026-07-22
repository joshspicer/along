import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';
import 'onboarding_scaffold.dart';

class RecoveryKitScreen extends ConsumerStatefulWidget {
  const RecoveryKitScreen({super.key});

  @override
  ConsumerState<RecoveryKitScreen> createState() => _RecoveryKitScreenState();
}

class _RecoveryKitScreenState extends ConsumerState<RecoveryKitScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(authControllerProvider).requireValue.recoveryKit!;
    return OnboardingScaffold(
      eyebrow: 'Keep this somewhere private',
      title: 'Save your recovery kit once.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'These codes are shown once and each works once. Print or save them somewhere separate from this device.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recovery handle',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(kit.recoveryHandle),
                  const Divider(height: 28),
                  for (final code in kit.codes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AsyncButton(
            label: 'Print or save securely',
            icon: Icons.print_outlined,
            outlined: true,
            onPressed: () => SharePlus.instance.share(
              ShareParams(subject: 'Along recovery kit', text: kit.printable),
            ),
          ),
          CheckboxListTile(
            value: _saved,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I saved these codes somewhere private'),
            onChanged: (value) => setState(() => _saved = value ?? false),
          ),
          const SizedBox(height: 8),
          AsyncButton(
            label: 'Continue',
            onPressed: _saved
                ? ref
                      .read(authControllerProvider.notifier)
                      .acknowledgeRecoveryKit
                : null,
          ),
        ],
      ),
    );
  }
}
