import 'package:along/features/focus/domain/focus_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses authoritative timestamp without resetting when partner joins', () {
    final started = DateTime.utc(2026, 7, 21, 18);
    final joined = FocusSession(
      id: 'session',
      pairId: 'pair',
      startedBy: 'jamie',
      state: SessionState.together,
      durationSeconds: 1500,
      startedAt: started,
      endsAt: started.add(const Duration(minutes: 25)),
      version: 2,
      participants: [
        SessionParticipant(
          accountId: 'jamie',
          displayName: 'Jamie',
          joinedAt: started,
        ),
        SessionParticipant(
          accountId: 'alex',
          displayName: 'Alex',
          joinedAt: started.add(const Duration(minutes: 6)),
        ),
      ],
    );

    expect(
      joined.remainingAt(started.add(const Duration(minutes: 6))),
      const Duration(minutes: 19),
    );
    expect(joined.includes('alex'), isTrue);
  });

  test('paused timer stays fixed and elapsed time clamps to zero', () {
    final started = DateTime.utc(2026, 7, 21, 18);
    final pausedAt = started.add(const Duration(minutes: 8));
    final paused = FocusSession(
      id: 'session',
      pairId: 'pair',
      startedBy: 'jamie',
      state: SessionState.paused,
      durationSeconds: 1500,
      startedAt: started,
      endsAt: started.add(const Duration(minutes: 25)),
      pausedAt: pausedAt,
      pauseOrigin: SessionState.open,
      version: 2,
    );
    expect(
      paused.remainingAt(started.add(const Duration(hours: 2))),
      const Duration(minutes: 17),
    );
    expect(
      paused
          .copyWith(state: SessionState.open, pausedAt: null, endsAt: started)
          .remainingAt(started.add(const Duration(minutes: 1))),
      Duration.zero,
    );
  });
}
