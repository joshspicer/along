import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/focus_session.dart';

class SessionRepository {
  SessionRepository(this._database, this._sync, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SyncEngine _sync;
  final Uuid _uuid;

  Stream<FocusSession?> watchCurrent() => _database.watchCurrentSession();
  Stream<List<FocusSession>> watchHistory() => _database.watchHistory();
  Future<FocusSession?> byId(String id) => _database.sessionById(id);
  DateTime get authoritativeNow => _sync.authoritativeNow;

  Future<FocusSession> start(AuthAccount account) async {
    final now = DateTime.now().toUtc();
    final session = FocusSession(
      id: _uuid.v4(),
      pairId: account.pairId!,
      startedBy: account.id,
      state: SessionState.open,
      durationSeconds: 1500,
      startedAt: now,
      endsAt: now.add(const Duration(minutes: 25)),
      version: 1,
      participants: [
        SessionParticipant(
          accountId: account.id,
          displayName: account.displayName,
          joinedAt: now,
        ),
      ],
    );
    final command = PendingCommand(
      id: _uuid.v4(),
      type: 'session.start',
      entityId: session.id,
      createdAt: now,
    );
    await _database.upsertSession(session, pendingSync: true);
    await _database.enqueue(command);
    try {
      await _sync.syncNow(throwOnCommandError: true);
      return await _database.sessionById(session.id) ?? session;
    } on DioException catch (error) {
      if (!_isOffline(error)) {
        await _database.deleteSession(session.id);
        rethrow;
      }
      await _database.removeCommand(command.id);
      final offline = session.copyWith(offlineOrigin: true);
      await _database.upsertSession(offline);
      return offline;
    } on SyncCommandException {
      await _database.deleteSession(session.id);
      rethrow;
    }
  }

  Future<void> join(FocusSession session) => _command(session, 'session.join');

  Future<void> pause(FocusSession session) async {
    if (session.offlineOrigin) {
      final now = DateTime.now().toUtc();
      await _database.upsertSession(
        session.copyWith(
          state: SessionState.paused,
          pauseOrigin: session.state,
          pausedAt: now,
          version: session.version + 1,
        ),
      );
      return;
    }
    await _command(session, 'session.pause');
  }

  Future<void> resume(FocusSession session) async {
    if (session.offlineOrigin && session.pausedAt != null) {
      final now = DateTime.now().toUtc();
      await _database.upsertSession(
        session.copyWith(
          state: session.pauseOrigin ?? SessionState.open,
          pauseOrigin: null,
          pausedAt: null,
          endsAt: session.endsAt.add(now.difference(session.pausedAt!)),
          version: session.version + 1,
        ),
      );
      return;
    }
    await _command(session, 'session.resume');
  }

  Future<void> complete(FocusSession session) async {
    if (session.offlineOrigin) {
      final now = DateTime.now().toUtc();
      final completed = session.copyWith(
        state: SessionState.completed,
        completedAt: now,
        pausedAt: null,
        pauseOrigin: null,
        version: session.version + 1,
      );
      await _database.upsertSession(completed, pendingSync: true);
      await _database.enqueue(
        PendingCommand(
          id: _uuid.v4(),
          type: 'session.import_solo',
          entityId: session.id,
          payload: <String, Object?>{
            'started_at': session.startedAt.toIso8601String(),
            'completed_at': now.toIso8601String(),
          },
          createdAt: now,
        ),
      );
      try {
        await _sync.syncNow();
      } on DioException {
        // The durable outbox retries when connectivity returns.
      }
      return;
    }
    await _command(session, 'session.complete');
  }

  Future<void> cancel(FocusSession session) =>
      _command(session, 'session.cancel');

  Future<void> cheer(FocusSession session) =>
      _command(session, 'session.cheer', expectedVersion: false);

  Future<void> addNote(FocusSession session, String body) => _command(
    session,
    'session.note',
    expectedVersion: false,
    payload: <String, Object?>{'body': body.trim()},
  );

  Future<void> _command(
    FocusSession session,
    String type, {
    bool expectedVersion = true,
    Map<String, Object?> payload = const {},
  }) async {
    await _database.enqueue(
      PendingCommand(
        id: _uuid.v4(),
        type: type,
        entityId: session.id,
        expectedVersion: expectedVersion ? session.version : null,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _sync.syncNow(throwOnCommandError: true);
  }

  bool _isOffline(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
}
