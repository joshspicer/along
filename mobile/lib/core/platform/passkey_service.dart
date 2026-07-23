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
      throw PasskeyException(
        error.message ?? 'The passkey could not be used.',
        details: error.details is Map
            ? Map<String, Object?>.from(error.details as Map)
            : const <String, Object?>{},
      );
    }
  }
}

class PasskeyException implements Exception {
  const PasskeyException(
    this.message, {
    this.details = const <String, Object?>{},
    this.diagnosticId,
  });

  final String message;
  final Map<String, Object?> details;
  final String? diagnosticId;

  PasskeyException withDiagnosticId(String? value) =>
      PasskeyException(message, details: details, diagnosticId: value);

  String get debugReport {
    final lines = <String>[
      _bounded(message, 500),
      if (diagnosticId != null) 'Diagnostic ID: $diagnosticId',
      for (final key in const ['domain', 'code', 'description'])
        if (details[key] != null)
          '$key: ${_bounded(details[key].toString(), 500)}',
    ];
    return lines.join('\n');
  }

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);

  @override
  String toString() => message;
}

class PasskeyCancelled extends PasskeyException {
  const PasskeyCancelled() : super('Passkey setup was cancelled.');
}
