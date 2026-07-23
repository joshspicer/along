import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../config/runtime_config.dart';

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.timestamp,
    required this.name,
    this.fields = const <String, Object?>{},
  });

  final DateTime timestamp;
  final String name;
  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'name': name,
    'fields': fields,
  };

  String get printable {
    final values = fields.entries.map((entry) => '${entry.key}=${entry.value}');
    return '${timestamp.toUtc().toIso8601String()} $name ${values.join(' ')}'
        .trim();
  }
}

class DiagnosticService {
  DiagnosticService(RuntimeConfig config)
    : _client = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          headers: const <String, Object?>{
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
        ),
      );

  static const allowedNames = <String>{
    'app.started',
    'app.lifecycle',
    'route.redirect',
    'auth.state',
    'network.failure',
    'sync.failure',
    'realtime.failure',
    'pairing.failure',
  };

  final Dio _client;
  final List<DiagnosticEvent> _events = <DiagnosticEvent>[];
  bool _uploading = false;
  String? _lastDiagnosticId;

  String? get lastDiagnosticId => _lastDiagnosticId;
  List<DiagnosticEvent> get events => List.unmodifiable(_events);

  void record(String name, [Map<String, Object?> fields = const {}]) {
    if (!allowedNames.contains(name)) return;
    final safeFields = <String, Object?>{};
    for (final entry in fields.entries.take(12)) {
      final value = entry.value;
      if (value is String) {
        safeFields[entry.key] = _bounded(value, 200);
      } else if (value is bool || value is num) {
        safeFields[entry.key] = value;
      }
    }
    _events.add(
      DiagnosticEvent(
        timestamp: DateTime.now().toUtc(),
        name: name,
        fields: safeFields,
      ),
    );
    if (_events.length > 50) _events.removeAt(0);
    if (name.endsWith('.failure')) unawaited(upload());
  }

  Future<String?> upload() async {
    if (_uploading || _events.isEmpty) return _lastDiagnosticId;
    _uploading = true;
    try {
      final snapshot = _events.toList();
      final response = await _client.post<Map<String, Object?>>(
        '/v1/diagnostics/events',
        data: <String, Object?>{
          'app_commit': AppConfig.gitCommit,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'events': snapshot.map((event) => event.toJson()).toList(),
        },
      );
      _lastDiagnosticId = response.data?['diagnostic_id']?.toString();
      _events.removeRange(0, snapshot.length.clamp(0, _events.length));
      return _lastDiagnosticId;
    } on Object {
      return _lastDiagnosticId;
    } finally {
      _uploading = false;
    }
  }

  String get debugReport => <String>[
    'Along diagnostics',
    'Commit: ${AppConfig.gitCommit}',
    if (_lastDiagnosticId != null) 'Diagnostic ID: $_lastDiagnosticId',
    ..._events.map((event) => event.printable),
  ].join('\n');

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);
}
