import 'package:flutter/material.dart';

import '../../../core/widgets/along_mark.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.body,
    super.key,
    this.eyebrow,
    this.footer,
    this.showMark = true,
  });

  final String title;
  final String? eyebrow;
  final Widget body;
  final Widget? footer;
  final bool showMark;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showMark) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AlongMark(),
                  ),
                  const SizedBox(height: 32),
                ],
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Semantics(
                  header: true,
                  child: Text(title, style: context.textTheme.headlineLarge),
                ),
                const SizedBox(height: 18),
                body,
                if (footer != null) ...[const SizedBox(height: 28), footer!],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
