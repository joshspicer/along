import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';

import '../../features/focus/domain/focus_session.dart';
import '../config/runtime_config.dart';
import '../database/app_database.dart';
import '../diagnostics/diagnostic_service.dart';
import '../network/token_coordinator.dart';

class SyncCommandException implements Exception {
  const SyncCommandException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class SyncEngine {
  SyncEngine(
    this._database,
    this._tokens,
    this._config, {
    DiagnosticService? diagnostics,
  }) : _diagnostics = diagnostics;

  final AppDatabase _database;
  final TokenCoordinator _tokens;
  final RuntimeConfig _config;
  final DiagnosticService? _diagnostics;
  Future<void>? _activeSync;
  Duration _serverOffset = Duration.zero;
  bool _running = false;
  IOWebSocketChannel? _channel;

  DateTime get authoritativeNow => DateTime.now().toUtc().add(_serverOffset);

  Future<void> initialize() async {
    _serverOffset = await _database.serverOffset();
  }

  Future<void> syncNow({bool throwOnCommandError = false}) async {
    final active = _activeSync;
    if (active != null) {
      await active;
      if (identical(_activeSync, active)) {
        _activeSync = null;
      }
      if ((await _database.pendingCommands(limit: 1)).isNotEmpty) {
        await syncNow(throwOnCommandError: throwOnCommandError);
      }
      return;
    }
    final future = _performSync(throwOnCommandError: throwOnCommandError);
    _activeSync = future;
    try {
      await future;
    } on Object catch (error) {
      _diagnostics?.record('sync.failure', {
        'error_type': error.runtimeType.toString(),
        'pending_commands': (await _database.pendingCommands()).length,
      });
      rethrow;
    } finally {
      if (identical(_activeSync, future)) {
        _activeSync = null;
      }
    }
  }

  void startRealtime() {
    if (_running) {
      return;
    }
    _running = true;
    unawaited(_reconnectLoop());
  }

  Future<void> stopRealtime() async {
    _running = false;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _performSync({required bool throwOnCommandError}) async {
    final commands = await _database.pendingCommands();
    final cursor = await _database.cursor();
    final sentAt = DateTime.now().toUtc();
    final response = await _tokens.client.post<Map<String, Object?>>(
      '/v1/sync',
      data: <String, Object?>{
        'cursor': cursor,
        'limit': 200,
        'commands': commands.map((command) => command.toJson()).toList(),
      },
    );
    final body = response.data!;
    final serverTime = DateTime.parse(body['server_time']! as String).toUtc();
    final receivedAt = DateTime.now().toUtc();
    final midpoint = sentAt.add(receivedAt.difference(sentAt) ~/ 2);
    _serverOffset = serverTime.difference(midpoint);

    SyncCommandException? commandError;
    await _database.transaction(() async {
      await _database.setServerOffset(_serverOffset);
      final results = body['command_results']! as List<Object?>;
      for (final item in results) {
        final result = item! as Map<String, Object?>;
        final id = result['id']! as String;
        if (result['applied'] == true) {
          final resource = result['resource'];
          if (resource is Map<String, Object?> &&
              resource.containsKey('state')) {
            await _database.upsertSession(FocusSession.fromJson(resource));
          }
          await _database.removeCommand(id);
          continue;
        }
        final error = result['error']! as Map<String, Object?>;
        final code = error['code']! as String;
        final message = error['message']! as String;
        commandError ??= SyncCommandException(code, message);
        if (code == 'cheer_cooldown' || code == 'rate_limited') {
          await _database.markCommandFailed(id, message);
        } else {
          await _database.removeCommand(id);
        }
      }
      final events = body['events']! as List<Object?>;
      for (final item in events) {
        await _applyEvent(item! as Map<String, Object?>);
      }
      final current = body['current_session'];
      if (current is Map<String, Object?>) {
        await _database.upsertSession(FocusSession.fromJson(current));
      }
      await _database.setCursor(body['cursor']! as int);
    });
    if ((body['events']! as List<Object?>).isNotEmpty) {
      try {
        await _refreshHistory();
      } on DioException {
        // Applied cursor data stays valid; history retries on the next sync.
      }
    }
    if (throwOnCommandError && commandError != null) {
      throw commandError!;
    }
    if (body['has_more'] == true) {
      await _performSync(throwOnCommandError: throwOnCommandError);
    }
  }

  Future<void> _applyEvent(Map<String, Object?> event) async {
    final type = event['type']! as String;
    final payload = event['payload'];
    if (payload is Map<String, Object?> && payload.containsKey('state')) {
      await _database.upsertSession(FocusSession.fromJson(payload));
      return;
    }
    if (type == 'session.note_added' &&
        payload is Map<String, Object?> &&
        event['entity_id'] is String) {
      final existing = await _database.sessionById(
        event['entity_id']! as String,
      );
      if (existing != null) {
        await _database.upsertSession(
          existing.copyWith(
            notes: [...existing.notes, FocusNote.fromJson(payload)],
          ),
        );
      }
    }
  }

  Future<void> _refreshHistory() async {
    final response = await _tokens.client.get<Map<String, Object?>>(
      '/v1/sessions',
      queryParameters: const <String, Object?>{'limit': 100},
    );
    for (final item in response.data!['sessions']! as List<Object?>) {
      await _database.upsertSession(
        FocusSession.fromJson(item! as Map<String, Object?>),
      );
    }
  }

  Future<void> _reconnectLoop() async {
    var delay = const Duration(seconds: 1);
    while (_running) {
      final token = _tokens.accessToken;
      if (token == null) {
        await Future<void>.delayed(delay);
        continue;
      }
      try {
        final channel = IOWebSocketChannel.connect(
          _config.webSocketUri,
          headers: <String, Object?>{'Authorization': 'Bearer $token'},
          pingInterval: const Duration(seconds: 25),
        );
        _channel = channel;
        await channel.ready;
        await syncNow();
        delay = const Duration(seconds: 1);
        await for (final message in channel.stream) {
          final decoded = jsonDecode(message as String);
          if (decoded is Map<String, Object?> && decoded['type'] == 'cursor') {
            await syncNow();
          }
          if (!_running) {
            break;
          }
        }
      } on Object catch (error) {
        _diagnostics?.record('realtime.failure', {
          'error_type': error.runtimeType.toString(),
          'retry_seconds': delay.inSeconds,
        });
        // Durable cursor replay on reconnect is the recovery path.
      } finally {
        await _channel?.sink.close();
        _channel = null;
      }
      if (_running) {
        await Future<void>.delayed(delay);
        final nextSeconds = (delay.inSeconds * 2).clamp(1, 30);
        delay = Duration(seconds: nextSeconds);
      }
    }
  }
}
