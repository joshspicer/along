import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/focus/domain/focus_session.dart';

part 'app_database.g.dart';

class LocalSessions extends Table {
  TextColumn get id => text()();
  TextColumn get pairId => text()();
  TextColumn get startedBy => text()();
  TextColumn get state => text()();
  TextColumn get pauseOrigin => text().nullable()();
  IntColumn get durationSeconds =>
      integer().withDefault(const Constant(1500))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  IntColumn get version => integer()();
  BoolColumn get offlineOrigin =>
      boolean().withDefault(const Constant(false))();
  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notesJson => text().withDefault(const Constant('[]'))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OutboxCommands extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get entityId => text().nullable()();
  IntColumn get expectedVersion => integer().nullable()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class AppProfiles extends Table {
  TextColumn get id => text().withDefault(const Constant('current'))();
  TextColumn get accountJson => text()();
  BoolColumn get notificationsExplained =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingCommand {
  const PendingCommand({
    required this.id,
    required this.type,
    required this.createdAt,
    this.entityId,
    this.expectedVersion,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String type;
  final String? entityId;
  final int? expectedVersion;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    if (entityId != null) 'entity_id': entityId,
    if (expectedVersion != null) 'expected_version': expectedVersion,
    'payload': payload,
  };
}

@DriftDatabase(
  tables: [LocalSessions, OutboxCommands, SyncMetadata, AppProfiles],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'along',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 1;

  Stream<FocusSession?> watchCurrentSession() {
    final query = select(localSessions)
      ..where(
        (table) => table.state.isIn([
          SessionState.open.name,
          SessionState.together.name,
          SessionState.paused.name,
        ]),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _sessionFromRow(row),
    );
  }

  Stream<List<FocusSession>> watchHistory() {
    final query = select(localSessions)
      ..where((table) => table.state.equals(SessionState.completed.name))
      ..orderBy([
        (table) => OrderingTerm.desc(table.completedAt),
        (table) => OrderingTerm.desc(table.startedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_sessionFromRow).toList(growable: false),
    );
  }

  Future<FocusSession?> sessionById(String id) async {
    final row = await (select(
      localSessions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _sessionFromRow(row);
  }

  Future<void> upsertSession(
    FocusSession session, {
    bool pendingSync = false,
  }) => into(localSessions).insertOnConflictUpdate(
    LocalSessionsCompanion.insert(
      id: session.id,
      pairId: session.pairId,
      startedBy: session.startedBy,
      state: session.state.name,
      pauseOrigin: Value(session.pauseOrigin?.name),
      durationSeconds: Value(session.durationSeconds),
      startedAt: session.startedAt,
      endsAt: session.endsAt,
      pausedAt: Value(session.pausedAt),
      completedAt: Value(session.completedAt),
      cancelledAt: Value(session.cancelledAt),
      version: session.version,
      offlineOrigin: Value(session.offlineOrigin),
      participantsJson: Value(
        jsonEncode(
          session.participants
              .map((participant) => participant.toJson())
              .toList(),
        ),
      ),
      notesJson: Value(
        jsonEncode(session.notes.map((note) => note.toJson()).toList()),
      ),
      pendingSync: Value(pendingSync),
    ),
  );

  Future<void> deleteSession(String id) =>
      (delete(localSessions)..where((table) => table.id.equals(id))).go();

  Future<void> enqueue(PendingCommand command) =>
      into(outboxCommands).insertOnConflictUpdate(
        OutboxCommandsCompanion.insert(
          id: command.id,
          type: command.type,
          entityId: Value(command.entityId),
          expectedVersion: Value(command.expectedVersion),
          payloadJson: Value(jsonEncode(command.payload)),
          createdAt: command.createdAt,
        ),
      );

  Future<List<PendingCommand>> pendingCommands({int limit = 100}) async {
    final query = select(outboxCommands)
      ..where(
        (table) =>
            table.nextAttemptAt.isNull() |
            table.nextAttemptAt.isSmallerOrEqualValue(DateTime.now().toUtc()),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows
        .map(
          (row) => PendingCommand(
            id: row.id,
            type: row.type,
            entityId: row.entityId,
            expectedVersion: row.expectedVersion,
            payload:
                (jsonDecode(row.payloadJson) as Map<String, Object?>?) ??
                const {},
            createdAt: row.createdAt,
          ),
        )
        .toList(growable: false);
  }

  Future<void> removeCommand(String id) =>
      (delete(outboxCommands)..where((table) => table.id.equals(id))).go();

  Future<void> markCommandFailed(String id, String error) => customUpdate(
    '''
      UPDATE outbox_commands
      SET attempts = attempts + 1,
          last_error = ?,
          next_attempt_at = ?
      WHERE id = ?
    ''',
    variables: [
      Variable<String>(error),
      Variable<DateTime>(
        DateTime.now().toUtc().add(const Duration(seconds: 5)),
      ),
      Variable<String>(id),
    ],
    updates: {outboxCommands},
  );

  Future<int> cursor() async {
    final row = await (select(
      syncMetadata,
    )..where((table) => table.key.equals('cursor'))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  Future<void> setCursor(int cursor) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(key: 'cursor', value: cursor.toString()),
      );

  Future<Duration> serverOffset() async {
    final row =
        await (select(syncMetadata)
              ..where((table) => table.key.equals('server_offset_ms')))
            .getSingleOrNull();
    return Duration(milliseconds: int.tryParse(row?.value ?? '') ?? 0);
  }

  Future<void> setServerOffset(Duration offset) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(
          key: 'server_offset_ms',
          value: offset.inMilliseconds.toString(),
        ),
      );

  Future<void> saveProfile(
    AuthAccount account, {
    required bool notificationsExplained,
  }) => into(appProfiles).insertOnConflictUpdate(
    AppProfilesCompanion.insert(
      accountJson: jsonEncode(account.toJson()),
      notificationsExplained: Value(notificationsExplained),
    ),
  );

  Future<(AuthAccount, bool)?> profile() async {
    final row = await (select(
      appProfiles,
    )..where((table) => table.id.equals('current'))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return (
      AuthAccount.fromJson(jsonDecode(row.accountJson) as Map<String, Object?>),
      row.notificationsExplained,
    );
  }

  Future<void> clearProfile() async {
    await transaction(() async {
      await delete(appProfiles).go();
      await delete(outboxCommands).go();
      await delete(syncMetadata).go();
      await delete(localSessions).go();
    });
  }

  FocusSession _sessionFromRow(LocalSession row) => FocusSession(
    id: row.id,
    pairId: row.pairId,
    startedBy: row.startedBy,
    state: SessionState.values.byName(row.state),
    pauseOrigin: row.pauseOrigin == null
        ? null
        : SessionState.values.byName(row.pauseOrigin!),
    durationSeconds: row.durationSeconds,
    startedAt: row.startedAt.toUtc(),
    endsAt: row.endsAt.toUtc(),
    pausedAt: row.pausedAt?.toUtc(),
    completedAt: row.completedAt?.toUtc(),
    cancelledAt: row.cancelledAt?.toUtc(),
    version: row.version,
    offlineOrigin: row.offlineOrigin,
    participants: (jsonDecode(row.participantsJson) as List<Object?>)
        .map(
          (item) => SessionParticipant.fromJson(item! as Map<String, Object?>),
        )
        .toList(growable: false),
    notes: (jsonDecode(row.notesJson) as List<Object?>)
        .map((item) => FocusNote.fromJson(item! as Map<String, Object?>))
        .toList(growable: false),
  );
}
