import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/runtime_config.dart';
import '../diagnostics/diagnostic_service.dart';
import '../secure/secure_store.dart';

class TokenCoordinator {
  TokenCoordinator(this._secureStore, RuntimeConfig config, {this._diagnostics})
    : _raw = Dio(_baseOptions(config.apiBaseUrl, config)),
      _passkeyRaw = Dio(_baseOptions(config.passkeyBaseUrl, config)),
      client = Dio(_baseOptions(config.apiBaseUrl, config)),
      passkeyClient = Dio(_baseOptions(config.passkeyBaseUrl, config)) {
    _raw.interceptors.add(InterceptorsWrapper(onError: _recordFailure));
    _passkeyRaw.interceptors.add(InterceptorsWrapper(onError: _recordFailure));
    for (final authorizedClient in [client, passkeyClient]) {
      authorizedClient.interceptors.add(
        QueuedInterceptorsWrapper(
          onRequest: _authorize,
          onError: _retryUnauthorized,
        ),
      );
    }
  }

  final SecureStore _secureStore;
  final DiagnosticService? _diagnostics;
  final Dio _raw;
  final Dio _passkeyRaw;
  final Dio client;
  final Dio passkeyClient;
  String? _accessToken;
  DateTime? _expiresAt;
  Future<Map<String, Object?>?>? _refreshing;

  Dio get publicClient => _raw;
  Dio get passkeyPublicClient => _passkeyRaw;
  String? get accessToken => _accessToken;

  Future<Map<String, Object?>?> restore() async {
    final refresh = await _secureStore.readRefreshToken();
    if (refresh == null) {
      return null;
    }
    return refreshSession(refreshToken: refresh);
  }

  Future<void> captureAuthPayload(Map<String, Object?> payload) async {
    final tokens = payload['tokens']! as Map<String, Object?>;
    _accessToken = tokens['access_token']! as String;
    _expiresAt = DateTime.parse(tokens['expires_at']! as String).toUtc();
    await _secureStore.writeRefreshToken(tokens['refresh_token']! as String);
  }

  Future<Map<String, Object?>?> refreshSession({String? refreshToken}) {
    final active = _refreshing;
    if (active != null) {
      return active;
    }
    final future = _performRefresh(refreshToken);
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> clear() async {
    _accessToken = null;
    _expiresAt = null;
    await _secureStore.clearSession();
  }

  Future<void> _authorize(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_accessToken == null ||
        _expiresAt == null ||
        _expiresAt!.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        )) {
      await refreshSession();
    }
    final token = _accessToken;
    if (token != null) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _retryUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode != HttpStatus.unauthorized ||
        error.requestOptions.extra['along_retried'] == true) {
      _recordFailure(error, handler);
      return;
    }
    final refreshed = await refreshSession();
    if (refreshed == null) {
      _recordFailure(error, handler);
      return;
    }
    try {
      final token = _accessToken;
      final options = error.requestOptions;
      options.extra['along_retried'] = true;
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      handler.resolve(await _raw.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  void _recordFailure(DioException error, ErrorInterceptorHandler handler) {
    _diagnostics?.record('network.failure', <String, Object?>{
      'method': error.requestOptions.method,
      'path': _diagnosticPath(error.requestOptions.path),
      'status': error.response?.statusCode ?? 0,
      'type': error.type.name,
    });
    handler.next(error);
  }

  String _diagnosticPath(String value) {
    final path = Uri.tryParse(value)?.path ?? value;
    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.length <= 2) return '/${segments.join('/')}';
    if (segments.length >= 3 && segments[1] == 'auth') {
      return '/${segments.take(3).join('/')}';
    }
    return '/${segments.take(2).join('/')}';
  }

  Future<Map<String, Object?>?> _performRefresh(String? explicitToken) async {
    final refresh = explicitToken ?? await _secureStore.readRefreshToken();
    if (refresh == null) {
      return null;
    }
    try {
      final response = await _raw.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: <String, Object?>{'refresh_token': refresh},
      );
      final payload = response.data;
      if (payload == null) {
        return null;
      }
      await captureAuthPayload(payload);
      return payload;
    } on DioException {
      await clear();
      return null;
    }
  }

  static BaseOptions _baseOptions(String baseUrl, RuntimeConfig config) =>
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: Duration(seconds: config.requestTimeoutSeconds),
        sendTimeout: Duration(seconds: config.requestTimeoutSeconds),
        headers: const <String, Object?>{
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      );
}
