import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/runtime_config.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/along_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: AlongApp()));
}

class AlongApp extends ConsumerStatefulWidget {
  const AlongApp({super.key});

  @override
  ConsumerState<AlongApp> createState() => _AlongAppState();
}

class _AlongAppState extends ConsumerState<AlongApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_recordStarted());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(runtimeConfigProvider).value == null) return;
    ref.read(diagnosticServiceProvider).record('app.lifecycle', {
      'state': state.name,
    });
  }

  Future<void> _recordStarted() async {
    await ref.read(runtimeConfigProvider.future);
    if (mounted) {
      ref.read(diagnosticServiceProvider).record('app.started');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Along Focus Together',
      debugShowCheckedModeBanner: false,
      theme: AlongTheme.light(),
      darkTheme: AlongTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
