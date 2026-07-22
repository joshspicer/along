import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/along_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: AlongApp()));
}

class AlongApp extends ConsumerWidget {
  const AlongApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Along',
      debugShowCheckedModeBanner: false,
      theme: AlongTheme.light(),
      darkTheme: AlongTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
