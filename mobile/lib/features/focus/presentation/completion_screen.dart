import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../../core/widgets/async_button.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/focus_session.dart';

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen> {
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<FocusSession?>(
        future: ref.read(sessionRepositoryProvider).byId(widget.sessionId),
        builder: (context, snapshot) {
          final session = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (session == null) {
            return _Missing(onDone: () => context.go('/focus'));
          }
          final together = session.participants.length > 1;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompletionMark(together: together),
                    const SizedBox(height: 28),
                    Text(
                      '${session.completedAt == null ? 25 : session.completedAt!.difference(session.startedAt).inMinutes.clamp(1, 25)} minutes${together ? '' : ' · Just you'}',
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      together
                          ? 'Both here. Nicely done.'
                          : 'A little room for you.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      together
                          ? 'You made a little room for the same thing at the same time.'
                          : 'You showed up without turning it into another obligation.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Saved to Look back'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Leave a small note',
                              style: context.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _note,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                hintText: 'Proud of us',
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final suggestion
                                    in together
                                        ? const [
                                            'Proud of us',
                                            'Glad you joined',
                                            'That felt good',
                                          ]
                                        : const [
                                            'That helped',
                                            'Got some focus in',
                                            'Thinking of you',
                                          ])
                                  ActionChip(
                                    label: Text(suggestion),
                                    onPressed: () => _note.text = suggestion,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AsyncButton(
                              label: 'Send note',
                              icon: Icons.send_rounded,
                              outlined: true,
                              busy: _sending,
                              onPressed: () => _send(session),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AsyncButton(
                      label: 'Back to focus',
                      onPressed: () => context.go('/focus'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> _send(FocusSession session) async {
    if (_note.text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(sessionRepositoryProvider).addNote(session, _note.text);
      if (mounted) {
        _note.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Note saved.')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyNetworkError(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _CompletionMark extends StatelessWidget {
  const _CompletionMark({required this.together});

  final bool together;

  @override
  Widget build(BuildContext context) => Semantics(
    label: together ? 'Shared focus completed' : 'Solo focus completed',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _person(context, 'Y', context.colorScheme.primary),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: context.colorScheme.tertiary,
          ),
        ),
        if (together) _person(context, 'P', context.colorScheme.secondary),
      ],
    ),
  );

  Widget _person(BuildContext context, String text, Color color) => Container(
    width: 70,
    height: 70,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Text(
      text,
      style: context.textTheme.headlineMedium?.copyWith(
        color: context.colorScheme.surface,
      ),
    ),
  );
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(onPressed: onDone, child: const Text('Back to focus')),
  );
}
