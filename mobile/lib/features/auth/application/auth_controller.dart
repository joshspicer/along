import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/runtime_config.dart';
import '../../../core/providers.dart';
import '../../pairing/data/pair_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  PairRepository get _pairs => ref.read(pairRepositoryProvider);

  @override
  Future<AuthState> build() async {
    await ref.watch(runtimeConfigProvider.future);
    final restored = await _repository.restore();
    ref.read(diagnosticServiceProvider).record('auth.state', {
      'status': restored.status.name,
      'paired': restored.account?.pairId != null,
      'source': 'restore',
    });
    if (restored.isSignedIn && restored.account?.pairId != null) {
      ref.read(syncEngineProvider).startRealtime();
      unawaited(ref.read(syncEngineProvider).syncNow());
    }
    return restored;
  }

  Future<void> register(String displayName) =>
      _run(() => _repository.register(displayName));

  Future<void> signIn() => _run(_repository.signIn);

  Future<void> recover({
    required String recoveryHandle,
    required String code,
  }) => _run(
    () => _repository.recover(recoveryHandle: recoveryHandle, code: code),
  );

  Future<void> continueOffline() async {
    state = const AsyncLoading();
    state = AsyncData(await _repository.startOffline());
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(syncEngineProvider).stopRealtime();
    await _repository.logout();
    state = const AsyncData(AuthState.signedOut());
  }

  Future<Uri> createPairInvite() => _pairs.createInvite();

  Future<void> acceptPairInvite(String tokenOrUrl) async {
    final account = await _pairs.accept(tokenOrUrl);
    final current = state.requireValue;
    final next = current.copyWith(account: account);
    await ref
        .read(databaseProvider)
        .saveProfile(
          account,
          notificationsExplained: next.notificationsExplained,
        );
    state = AsyncData(next);
    ref.read(syncEngineProvider).startRealtime();
    unawaited(ref.read(syncEngineProvider).syncNow());
  }

  void acknowledgeRecoveryKit() {
    state = AsyncData(state.requireValue.copyWith(clearRecoveryKit: true));
  }

  Future<bool> requestNotifications() async {
    final result = await ref.read(notificationServiceProvider).request();
    if (result.apnsToken != null) {
      await ref
          .read(tokenCoordinatorProvider)
          .client
          .put<void>(
            '/v1/push/device',
            data: <String, Object?>{
              'token': result.apnsToken,
              'environment': ref
                  .read(runtimeConfigProvider)
                  .requireValue
                  .apnsEnvironment,
            },
          );
    }
    await markNotificationsExplained();
    return result.granted;
  }

  Future<void> markNotificationsExplained() async {
    final current = state.requireValue;
    final account = current.account!;
    await ref
        .read(databaseProvider)
        .saveProfile(account, notificationsExplained: true);
    state = AsyncData(current.copyWith(notificationsExplained: true));
  }

  Future<void> refreshAccount() async {
    final account = await _pairs.refreshAccount();
    state = AsyncData(state.requireValue.copyWith(account: account));
  }

  Future<void> _run(Future<AuthState> Function() action) async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await action());
      final auth = state.requireValue;
      ref.read(diagnosticServiceProvider).record('auth.state', {
        'status': auth.status.name,
        'paired': auth.account?.pairId != null,
        'recovery_kit': auth.recoveryKit != null,
      });
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
