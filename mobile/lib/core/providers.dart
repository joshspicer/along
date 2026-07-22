import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/focus/data/session_repository.dart';
import '../features/pairing/data/pair_repository.dart';
import 'database/app_database.dart';
import 'network/token_coordinator.dart';
import 'platform/notification_service.dart';
import 'platform/passkey_service.dart';
import 'secure/secure_store.dart';
import 'sync/sync_engine.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(),
);

final tokenCoordinatorProvider = Provider<TokenCoordinator>(
  (ref) => TokenCoordinator(ref.watch(secureStoreProvider)),
);

final passkeyServiceProvider = Provider<PasskeyService>(
  (ref) => const NativePasskeyService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const NotificationService(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    tokens: ref.watch(tokenCoordinatorProvider),
    secureStore: ref.watch(secureStoreProvider),
    passkeyService: ref.watch(passkeyServiceProvider),
    database: ref.watch(databaseProvider),
  ),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(tokenCoordinatorProvider),
  );
  unawaited(engine.initialize());
  ref.onDispose(() => unawaited(engine.stopRealtime()));
  return engine;
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final pairRepositoryProvider = Provider<PairRepository>(
  (ref) => PairRepository(
    ref.watch(tokenCoordinatorProvider),
    ref.watch(databaseProvider),
  ),
);

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
