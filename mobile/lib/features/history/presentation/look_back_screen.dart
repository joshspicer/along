import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../focus/domain/focus_session.dart';

class LookBackScreen extends ConsumerWidget {
  const LookBackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(sessionRepositoryProvider);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const AlongMark(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Look back',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.MMMM().format(DateTime.now()),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The time you made.',
                    style: context.textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<FocusSession>>(
            stream: repository.watchHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: _HistoryMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Look back is unavailable.',
                    detail: 'Your local history remains on this device.',
                  ),
                );
              }
              final sessions = snapshot.data ?? const [];
              if (sessions.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _HistoryMessage(
                    icon: Icons.history_rounded,
                    title: 'Nothing here yet.',
                    detail: 'Finished sessions appear here.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _SessionRecord(session: sessions[index]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionRecord extends StatelessWidget {
  const _SessionRecord({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final together = session.participants.length > 1;
    final finished = session.completedAt ?? session.endsAt;
    final minutes = finished
        .difference(session.startedAt)
        .inMinutes
        .clamp(1, 25);
    final note = session.notes.isEmpty ? null : session.notes.last.body;
    return Semantics(
      label:
          '${together ? 'Focus together' : 'Quiet focus'}, $minutes minutes, ${DateFormat.yMMMMd().add_jm().format(finished.toLocal())}${note == null ? '' : ', note: $note'}',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: together
                      ? context.colorScheme.secondaryContainer
                      : context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  together ? Icons.people_alt_outlined : Icons.timer_outlined,
                  color: together
                      ? context.colorScheme.onSecondaryContainer
                      : context.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      together ? 'Focus together' : 'Quiet focus',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$minutes min · ${DateFormat.MMMd().add_jm().format(finished.toLocal())}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 8),
                      Text('“$note”', style: context.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: context.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
