import 'package:along/core/config/app_config.dart';
import 'package:along/core/config/runtime_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists custom values and resets every override', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      (await container.read(runtimeConfigProvider.future)).apiBaseUrl,
      AppConfig.defaultApiBaseUrl,
    );

    await container
        .read(runtimeConfigProvider.notifier)
        .save(
          apiBaseUrl: 'https://staging.example.test/',
          apnsEnvironment: 'sandbox',
          requestTimeoutSeconds: 45,
        );
    final custom = await container.read(runtimeConfigProvider.future);
    expect(custom.apiBaseUrl, 'https://staging.example.test');
    expect(custom.apnsEnvironment, 'sandbox');
    expect(custom.requestTimeoutSeconds, 45);

    await container.read(runtimeConfigProvider.notifier).reset();
    final defaults = await container.read(runtimeConfigProvider.future);
    expect(defaults.apiBaseUrl, AppConfig.defaultApiBaseUrl);
    expect(defaults.apnsEnvironment, AppConfig.defaultApnsEnvironment);
    expect(defaults.requestTimeoutSeconds, 20);
  });
}
