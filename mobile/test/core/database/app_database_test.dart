import 'package:along/core/database/app_database.dart';
import 'package:along/features/auth/domain/auth_models.dart';
import 'package:along/features/focus/domain/focus_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('stores current session and newest-first history locally', () async {
    final now = DateTime.utc(2026, 7, 21, 18);
    final active = session(
      id: 'active',
      state: SessionState.open,
      startedAt: now,
    );
    final older = session(
      id: 'older',
      state: SessionState.completed,
      startedAt: now.subtract(const Duration(hours: 2)),
    );
    final newer = session(
      id: 'newer',
      state: SessionState.completed,
      startedAt: now.subtract(const Duration(hours: 1)),
    );
    await database.upsertSession(active);
    await database.upsertSession(older);
    await database.upsertSession(newer);

    expect(await database.watchCurrentSession().first, active);
    final history = await database.watchHistory().first;
    expect(history.map((item) => item.id), ['newer', 'older']);
  });

  test('persists durable cursor, profile, and stable outbox command', () async {
    final command = PendingCommand(
      id: '5fae9d3d-71a7-4ba0-8f7d-d109df8aec8c',
      type: 'session.complete',
      entityId: 'session-id',
      expectedVersion: 3,
      createdAt: DateTime.utc(2026, 7, 21),
    );
    await database.enqueue(command);
    await database.setCursor(42);
    const account = AuthAccount(
      id: 'account-id',
      displayName: 'Jamie',
      pairId: 'pair-id',
      partnerName: 'Alex',
    );
    await database.saveProfile(account, notificationsExplained: true);

    final pending = await database.pendingCommands();
    expect(pending, hasLength(1));
    expect(pending.single.toJson(), command.toJson());
    expect(await database.cursor(), 42);
    final profile = await database.profile();
    expect(profile?.$1.displayName, 'Jamie');
    expect(profile?.$2, isTrue);
  });
}

FocusSession session({
  required String id,
  required SessionState state,
  required DateTime startedAt,
}) => FocusSession(
  id: id,
  pairId: 'pair-id',
  startedBy: 'account-id',
  state: state,
  durationSeconds: 1500,
  startedAt: startedAt,
  endsAt: startedAt.add(const Duration(minutes: 25)),
  completedAt: state == SessionState.completed
      ? startedAt.add(const Duration(minutes: 25))
      : null,
  version: 1,
  participants: [
    SessionParticipant(
      accountId: 'account-id',
      displayName: 'Jamie',
      joinedAt: startedAt,
    ),
  ],
);
