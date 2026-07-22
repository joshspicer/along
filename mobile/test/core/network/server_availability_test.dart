import 'package:along/core/database/app_database.dart';
import 'package:along/core/network/server_availability.dart';
import 'package:along/core/network/token_coordinator.dart';
import 'package:along/core/secure/secure_store.dart';
import 'package:along/core/sync/sync_engine.dart';
import 'package:along/features/auth/domain/auth_models.dart';
import 'package:along/features/focus/data/session_repository.dart';
import 'package:along/features/focus/domain/focus_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server-unavailable launch creates a local-only solo session', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final secureStore = MemorySecureStore();
    final sync = SyncEngine(database, TokenCoordinator(secureStore));
    final repository = SessionRepository(database, sync, forceOffline: true);
    const account = AuthAccount(
      id: 'offline-account',
      displayName: 'You',
      pairId: 'offline-pair',
    );

    final session = await repository.start(account);

    expect(session.offlineOrigin, isTrue);
    expect(session.state, SessionState.open);
    expect(await database.pendingCommands(), isEmpty);
  });

  test('unavailable is a stable launch-time availability state', () {
    expect(ServerAvailability.unavailable.name, 'unavailable');
    expect(serverAvailabilityProvider, isNotNull);
  });
}

class MemorySecureStore implements SecureStore {
  String? refreshToken;

  @override
  Future<void> clearSession() async => refreshToken = null;

  @override
  Future<String> installationId() async => 'test-installation';

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;
}
