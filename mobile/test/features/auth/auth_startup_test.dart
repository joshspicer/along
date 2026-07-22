import 'package:along/core/config/runtime_config.dart';
import 'package:along/core/providers.dart';
import 'package:along/core/secure/secure_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'auth waits for persisted runtime configuration before restoring',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [secureStoreProvider.overrideWithValue(_EmptySecureStore())],
      );
      addTearDown(container.dispose);

      final auth = await container.read(authControllerProvider.future);

      expect(auth.isSignedIn, isFalse);
      expect(
        (await container.read(runtimeConfigProvider.future)).apiBaseUrl,
        'https://along.spicer.dev',
      );
    },
  );
}

class _EmptySecureStore implements SecureStore {
  @override
  Future<void> clearSession() async {}

  @override
  Future<String> installationId() async => 'installation';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}
