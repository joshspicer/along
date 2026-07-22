// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionParticipant _$SessionParticipantFromJson(Map<String, dynamic> json) =>
    _SessionParticipant(
      accountId: json['account_id'] as String,
      displayName: json['display_name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$SessionParticipantToJson(_SessionParticipant instance) =>
    <String, dynamic>{
      'account_id': instance.accountId,
      'display_name': instance.displayName,
      'joined_at': instance.joinedAt.toIso8601String(),
    };

_FocusNote _$FocusNoteFromJson(Map<String, dynamic> json) => _FocusNote(
  id: json['id'] as String,
  accountId: json['account_id'] as String,
  displayName: json['display_name'] as String,
  body: json['body'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FocusNoteToJson(_FocusNote instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account_id': instance.accountId,
      'display_name': instance.displayName,
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
    };

_FocusSession _$FocusSessionFromJson(
  Map<String, dynamic> json,
) => _FocusSession(
  id: json['id'] as String,
  pairId: json['pair_id'] as String,
  startedBy: json['started_by'] as String,
  state: $enumDecode(_$SessionStateEnumMap, json['state']),
  durationSeconds: (json['duration_seconds'] as num).toInt(),
  startedAt: DateTime.parse(json['started_at'] as String),
  endsAt: DateTime.parse(json['ends_at'] as String),
  version: (json['version'] as num).toInt(),
  offlineOrigin: json['offline_origin'] as bool? ?? false,
  pauseOrigin: $enumDecodeNullable(_$SessionStateEnumMap, json['pause_origin']),
  pausedAt: json['paused_at'] == null
      ? null
      : DateTime.parse(json['paused_at'] as String),
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  cancelledAt: json['cancelled_at'] == null
      ? null
      : DateTime.parse(json['cancelled_at'] as String),
  participants:
      (json['participants'] as List<dynamic>?)
          ?.map((e) => SessionParticipant.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SessionParticipant>[],
  notes:
      (json['notes'] as List<dynamic>?)
          ?.map((e) => FocusNote.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <FocusNote>[],
);

Map<String, dynamic> _$FocusSessionToJson(_FocusSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pair_id': instance.pairId,
      'started_by': instance.startedBy,
      'state': _$SessionStateEnumMap[instance.state]!,
      'duration_seconds': instance.durationSeconds,
      'started_at': instance.startedAt.toIso8601String(),
      'ends_at': instance.endsAt.toIso8601String(),
      'version': instance.version,
      'offline_origin': instance.offlineOrigin,
      'pause_origin': _$SessionStateEnumMap[instance.pauseOrigin],
      'paused_at': instance.pausedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'participants': instance.participants.map((e) => e.toJson()).toList(),
      'notes': instance.notes.map((e) => e.toJson()).toList(),
    };

const _$SessionStateEnumMap = {
  SessionState.open: 'open',
  SessionState.together: 'together',
  SessionState.paused: 'paused',
  SessionState.completed: 'completed',
  SessionState.cancelled: 'cancelled',
  SessionState.expired: 'expired',
};
