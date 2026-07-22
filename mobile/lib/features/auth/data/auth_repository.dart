import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/token_coordinator.dart';
import '../../../core/platform/passkey_service.dart';
import '../../../core/secure/secure_store.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  AuthRepository({
    required this.tokens,
    required this.secureStore,
    required this.passkeyService,
    required this.database,
  });

  final TokenCoordinator tokens;
  final SecureStore secureStore;
  final PasskeyService passkeyService;
  final AppDatabase database;

  Future<AuthState> restore() async {
    final payload = await tokens.restore();
    if (payload == null) {
      return const AuthState.signedOut();
    }
    return _stateFromPayload(payload);
  }

  Future<AuthState> register(String displayName) async {
    final optionsResponse = await tokens.publicClient
        .post<Map<String, Object?>>(
          '/v1/auth/register/options',
          data: <String, Object?>{'display_name': displayName},
        );
    final options = optionsResponse.data!;
    final credential = await passkeyService.register(
      Map<String, Object?>.from(options['publicKey']! as Map),
    );
    final response = await tokens.publicClient.post<Map<String, Object?>>(
      '/v1/auth/register/finish',
      data: credential,
      options: Options(
        headers: await _ceremonyHeaders(
          options['challenge_id']! as String,
          passkeyLabel: await _deviceName(),
        ),
      ),
    );
    final payload = response.data!;
    await tokens.captureAuthPayload(payload);
    return _stateFromPayload(payload);
  }

  Future<AuthState> signIn() async {
    final optionsResponse = await tokens.publicClient
        .post<Map<String, Object?>>(
          '/v1/auth/login/options',
          data: const <String, Object?>{},
        );
    final options = optionsResponse.data!;
    final credential = await passkeyService.authenticate(
      Map<String, Object?>.from(options['publicKey']! as Map),
    );
    final response = await tokens.publicClient.post<Map<String, Object?>>(
      '/v1/auth/login/finish',
      data: credential,
      options: Options(
        headers: await _ceremonyHeaders(options['challenge_id']! as String),
      ),
    );
    final payload = response.data!;
    await tokens.captureAuthPayload(payload);
    return _stateFromPayload(payload);
  }

  Future<AuthState> recover({
    required String recoveryHandle,
    required String code,
  }) async {
    final response = await tokens.publicClient.post<Map<String, Object?>>(
      '/v1/auth/recover',
      data: <String, Object?>{'recovery_handle': recoveryHandle, 'code': code},
      options: Options(headers: await _deviceHeaders()),
    );
    final payload = response.data!;
    await tokens.captureAuthPayload(payload);
    return _stateFromPayload(payload);
  }

  Future<void> logout() async {
    try {
      await tokens.client.post<void>('/v1/auth/logout');
    } on DioException {
      // Local token deletion still signs the device out if the network is down.
    }
    await tokens.clear();
    await database.clearProfile();
  }

  Future<void> addPasskey() async {
    final optionsResponse = await tokens.client.post<Map<String, Object?>>(
      '/v1/auth/passkeys/options',
      data: const <String, Object?>{},
    );
    final options = optionsResponse.data!;
    final credential = await passkeyService.register(
      Map<String, Object?>.from(options['publicKey']! as Map),
    );
    await tokens.client.post<void>(
      '/v1/auth/passkeys/finish',
      data: credential,
      options: Options(
        headers: <String, Object?>{
          'X-Along-Challenge': options['challenge_id']! as String,
          'X-Along-Passkey-Label': await _deviceName(),
        },
      ),
    );
  }

  Future<List<Map<String, Object?>>> passkeys() async {
    final response = await tokens.client.get<Map<String, Object?>>(
      '/v1/auth/passkeys',
    );
    return (response.data!['passkeys']! as List<Object?>)
        .cast<Map<String, Object?>>();
  }

  Future<void> revokePasskey(String id) =>
      tokens.client.delete<void>('/v1/auth/passkeys/$id');

  Future<List<Map<String, Object?>>> sessions() async {
    final response = await tokens.client.get<Map<String, Object?>>(
      '/v1/auth/sessions',
    );
    return (response.data!['sessions']! as List<Object?>)
        .cast<Map<String, Object?>>();
  }

  Future<void> revokeSession(String id) =>
      tokens.client.delete<void>('/v1/auth/sessions/$id');

  Future<List<Map<String, Object?>>> installations() async {
    final response = await tokens.client.get<Map<String, Object?>>(
      '/v1/auth/installations',
    );
    return (response.data!['installations']! as List<Object?>)
        .cast<Map<String, Object?>>();
  }

  Future<void> revokeInstallation(String id) =>
      tokens.client.delete<void>('/v1/auth/installations/$id');

  Future<RecoveryKit> regenerateRecoveryCodes() async {
    final response = await tokens.client.post<Map<String, Object?>>(
      '/v1/auth/recovery-codes/regenerate',
      data: const <String, Object?>{'confirm': true},
    );
    return RecoveryKit.fromJson(
      response.data!['recovery_kit']! as Map<String, Object?>,
    );
  }

  Future<AuthState> _stateFromPayload(Map<String, Object?> payload) async {
    final account = AuthAccount.fromJson(
      payload['account']! as Map<String, Object?>,
    );
    final saved = await database.profile();
    final explained = saved?.$2 ?? false;
    final recovery = payload['recovery_kit'] == null
        ? null
        : RecoveryKit.fromJson(
            payload['recovery_kit']! as Map<String, Object?>,
          );
    await database.saveProfile(account, notificationsExplained: explained);
    return AuthState.signedIn(
      account: account,
      recoveryKit: recovery,
      notificationsExplained: explained,
    );
  }

  Future<Map<String, Object?>> _ceremonyHeaders(
    String challenge, {
    String? passkeyLabel,
  }) async {
    final headers = await _deviceHeaders();
    headers['X-Along-Challenge'] = challenge;
    if (passkeyLabel != null) {
      headers['X-Along-Passkey-Label'] = passkeyLabel;
    }
    return headers;
  }

  Future<Map<String, Object?>> _deviceHeaders() async => <String, Object?>{
    'X-Along-Installation-ID': await secureStore.installationId(),
    'X-Along-Platform': Platform.isIOS ? 'ios' : 'android',
    'X-Along-Device-Name': await _deviceName(),
  };

  Future<String> _deviceName() async =>
      Platform.isIOS ? 'iPhone or iPad' : 'Android device';
}

String friendlyNetworkError(Object error) {
  if (error is PasskeyCancelled) {
    return error.message;
  }
  if (error is PasskeyException) {
    return error.message;
  }
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map<String, Object?>) {
      final detail = body['error'];
      if (detail is Map<String, Object?> && detail['message'] is String) {
        return detail['message']! as String;
      }
    }
    return 'Along could not reach the server. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
