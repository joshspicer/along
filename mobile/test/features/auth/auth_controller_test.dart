import 'package:along/core/diagnostics/diagnostic_service.dart';
import 'package:along/core/providers.dart';
import 'package:along/core/sync/sync_engine.dart';
import 'package:along/features/auth/data/auth_repository.dart';
import 'package:along/features/auth/domain/auth_models.dart';
import 'package:along/features/pairing/data/pair_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPairRepository extends Mock implements PairRepository {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockDiagnosticService extends Mock implements DiagnosticService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshing into a pair starts realtime sync', () async {
    SharedPreferences.setMockInitialValues({});
    final authRepository = _MockAuthRepository();
    final pairRepository = _MockPairRepository();
    final syncEngine = _MockSyncEngine();
    final diagnostics = _MockDiagnosticService();
    const unpaired = AuthState.signedIn(
      account: AuthAccount(id: 'account-id', displayName: 'Jamie'),
      notificationsExplained: false,
    );
    const pairedAccount = AuthAccount(
      id: 'account-id',
      displayName: 'Jamie',
      pairId: 'pair-id',
      partnerName: 'Alex',
    );
    when(() => authRepository.restore()).thenAnswer((_) async => unpaired);
    when(
      () => pairRepository.refreshAccount(),
    ).thenAnswer((_) async => pairedAccount);
    when(() => syncEngine.startRealtime()).thenReturn(null);
    when(() => syncEngine.syncNow()).thenAnswer((_) async {});
    when(() => diagnostics.record(any(), any())).thenReturn(null);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        pairRepositoryProvider.overrideWithValue(pairRepository),
        syncEngineProvider.overrideWithValue(syncEngine),
        diagnosticServiceProvider.overrideWithValue(diagnostics),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).refreshAccount();
    await Future<void>.delayed(Duration.zero);

    verify(() => syncEngine.startRealtime()).called(1);
    verify(() => syncEngine.syncNow()).called(1);
  });
}
