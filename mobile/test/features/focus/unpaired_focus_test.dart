import 'package:along/core/database/app_database.dart';
import 'package:along/core/sync/sync_engine.dart';
import 'package:along/features/auth/domain/auth_models.dart';
import 'package:along/features/focus/data/session_repository.dart';
import 'package:along/features/focus/domain/focus_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockUuid extends Mock implements Uuid {}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('unpaired accounts can complete a local solo focus', () async {
    final uuid = _MockUuid();
    when(uuid.v4).thenReturn('solo-session');
    final repository = SessionRepository(
      database,
      _MockSyncEngine(),
      uuid: uuid,
    );
    const account = AuthAccount(id: 'account-id', displayName: 'Jamie');

    final started = await repository.start(account);
    await repository.complete(started);

    expect(started.pairId, 'solo-account-id');
    expect(started.offlineOrigin, isTrue);
    final history = await database.watchHistory().first;
    expect(history.single.state, SessionState.completed);
    expect(await database.pendingCommands(), isEmpty);
  });
}
