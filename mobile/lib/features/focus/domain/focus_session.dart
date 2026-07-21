import 'package:freezed_annotation/freezed_annotation.dart';

part 'focus_session.freezed.dart';
part 'focus_session.g.dart';

enum SessionState {
  open,
  together,
  paused,
  completed,
  cancelled,
  expired;

  bool get isTerminal =>
      this == completed || this == cancelled || this == expired;
}

@freezed
abstract class SessionParticipant with _$SessionParticipant {
  const factory SessionParticipant({
    required String accountId,
    required String displayName,
    required DateTime joinedAt,
  }) = _SessionParticipant;

  factory SessionParticipant.fromJson(Map<String, Object?> json) =>
      _$SessionParticipantFromJson(json);
}

@freezed
abstract class FocusNote with _$FocusNote {
  const factory FocusNote({
    required String id,
    required String accountId,
    required String displayName,
    required String body,
    required DateTime createdAt,
  }) = _FocusNote;

  factory FocusNote.fromJson(Map<String, Object?> json) =>
      _$FocusNoteFromJson(json);
}

@freezed
abstract class FocusSession with _$FocusSession {
  const FocusSession._();

  const factory FocusSession({
    required String id,
    required String pairId,
    required String startedBy,
    required SessionState state,
    required int durationSeconds,
    required DateTime startedAt,
    required DateTime endsAt,
    required int version,
    @Default(false) bool offlineOrigin,
    SessionState? pauseOrigin,
    DateTime? pausedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    @Default(<SessionParticipant>[]) List<SessionParticipant> participants,
    @Default(<FocusNote>[]) List<FocusNote> notes,
  }) = _FocusSession;

  factory FocusSession.fromJson(Map<String, Object?> json) =>
      _$FocusSessionFromJson(json);

  bool includes(String accountId) =>
      participants.any((participant) => participant.accountId == accountId);

  Duration remainingAt(DateTime authoritativeNow) {
    final clock = state == SessionState.paused && pausedAt != null
        ? pausedAt!
        : authoritativeNow;
    final remaining = endsAt.difference(clock);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isActive =>
      state == SessionState.open ||
      state == SessionState.together ||
      state == SessionState.paused;
}
