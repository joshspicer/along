import 'dart:convert';

import 'package:flutter/services.dart';

abstract interface class PasskeyService {
  Future<Map<String, Object?>> register(Map<String, Object?> options);
  Future<Map<String, Object?>> authenticate(Map<String, Object?> options);
}

class NativePasskeyService implements PasskeyService {
  const NativePasskeyService();

  static const _channel = MethodChannel('com.joshspicer.along/passkeys');

  @override
  Future<Map<String, Object?>> register(Map<String, Object?> options) =>
      _invoke('register', options);

  @override
  Future<Map<String, Object?>> authenticate(Map<String, Object?> options) =>
      _invoke('authenticate', options);

  Future<Map<String, Object?>> _invoke(
    String method,
    Map<String, Object?> options,
  ) async {
    try {
      final response = await _channel.invokeMethod<String>(
        method,
        <String, Object?>{'requestJson': jsonEncode(options)},
      );
      if (response == null) {
        throw const PasskeyException('No passkey response was returned.');
      }
      return jsonDecode(response) as Map<String, Object?>;
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') {
        throw const PasskeyCancelled();
      }
      throw PasskeyException(error.message ?? 'The passkey could not be used.');
    }
  }
}

class PasskeyException implements Exception {
  const PasskeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PasskeyCancelled extends PasskeyException {
  const PasskeyCancelled() : super('Passkey setup was cancelled.');
}
