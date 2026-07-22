import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/network/server_availability.dart';
import '../../../core/platform/haptics.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/async_button.dart';

class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  ConsumerState<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState
    extends ConsumerState<AdvancedSettingsScreen> {
  final _endpoint = TextEditingController();
  final _timeout = TextEditingController();
  String _apnsEnvironment = AppConfig.defaultApnsEnvironment;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _endpoint.dispose();
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(runtimeConfigProvider);
    if (config case AsyncData(:final value) when !_initialized) {
      _initialized = true;
      _endpoint.text = value.apiBaseUrl;
      _timeout.text = value.requestTimeoutSeconds.toString();
      _apnsEnvironment = value.apnsEnvironment;
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Advanced'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            TextField(
              controller: _endpoint,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Server endpoint',
                hintText: AppConfig.defaultApiBaseUrl,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _apnsEnvironment,
              decoration: const InputDecoration(labelText: 'Push environment'),
              items: const [
                DropdownMenuItem(
                  value: 'production',
                  child: Text('Production'),
                ),
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _apnsEnvironment = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeout,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Request timeout',
                suffixText: 'seconds',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 28),
            AsyncButton(label: 'Save', busy: _busy, onPressed: _save),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _reset,
              child: const Text('Reset to defaults'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(runtimeConfigProvider.notifier)
          .save(
            apiBaseUrl: _endpoint.text,
            apnsEnvironment: _apnsEnvironment,
            requestTimeoutSeconds: int.tryParse(_timeout.text) ?? 0,
          );
      _refreshNetworking();
      if (mounted) {
        unawaited(AlongHaptics.success());
        context.pop();
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    await ref.read(runtimeConfigProvider.notifier).reset();
    _refreshNetworking();
    final config = ref.read(runtimeConfigProvider).requireValue;
    _endpoint.text = config.apiBaseUrl;
    _timeout.text = config.requestTimeoutSeconds.toString();
    setState(() {
      _apnsEnvironment = config.apnsEnvironment;
      _error = null;
      _busy = false;
    });
    unawaited(AlongHaptics.success());
  }

  void _refreshNetworking() {
    ref.invalidate(tokenCoordinatorProvider);
    ref.invalidate(syncEngineProvider);
    ref.invalidate(sessionRepositoryProvider);
    ref.invalidate(serverAvailabilityProvider);
  }
}
