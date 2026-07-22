import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class RuntimeConfig {
  const RuntimeConfig({
    required this.apiBaseUrl,
    required this.apnsEnvironment,
    required this.requestTimeoutSeconds,
  });

  final String apiBaseUrl;
  final String apnsEnvironment;
  final int requestTimeoutSeconds;

  Uri get webSocketUri {
    final httpUri = Uri.parse(apiBaseUrl);
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/ws',
      query: null,
    );
  }
}

class RuntimeConfigController extends AsyncNotifier<RuntimeConfig> {
  static const _endpointKey = 'advanced.api_base_url';
  static const _apnsKey = 'advanced.apns_environment';
  static const _timeoutKey = 'advanced.request_timeout_seconds';

  @override
  Future<RuntimeConfig> build() async {
    final preferences = await SharedPreferences.getInstance();
    return RuntimeConfig(
      apiBaseUrl:
          preferences.getString(_endpointKey) ?? AppConfig.defaultApiBaseUrl,
      apnsEnvironment:
          preferences.getString(_apnsKey) ?? AppConfig.defaultApnsEnvironment,
      requestTimeoutSeconds: preferences.getInt(_timeoutKey) ?? 20,
    );
  }

  Future<void> save({
    required String apiBaseUrl,
    required String apnsEnvironment,
    required int requestTimeoutSeconds,
  }) async {
    final endpoint = Uri.tryParse(apiBaseUrl.trim());
    if (endpoint == null ||
        !endpoint.hasScheme ||
        endpoint.host.isEmpty ||
        (endpoint.scheme != 'https' && endpoint.scheme != 'http')) {
      throw const FormatException('Enter a valid HTTP or HTTPS endpoint.');
    }
    if (requestTimeoutSeconds < 3 || requestTimeoutSeconds > 120) {
      throw const FormatException('Timeout must be between 3 and 120 seconds.');
    }
    final normalized = endpoint.replace(path: '', query: null, fragment: null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _endpointKey,
      normalized.toString().replaceFirst(RegExp(r'/$'), ''),
    );
    await preferences.setString(_apnsKey, apnsEnvironment);
    await preferences.setInt(_timeoutKey, requestTimeoutSeconds);
    ref.invalidateSelf();
    await future;
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_endpointKey);
    await preferences.remove(_apnsKey);
    await preferences.remove(_timeoutKey);
    ref.invalidateSelf();
    await future;
  }
}

final runtimeConfigProvider =
    AsyncNotifierProvider<RuntimeConfigController, RuntimeConfig>(
      RuntimeConfigController.new,
    );
