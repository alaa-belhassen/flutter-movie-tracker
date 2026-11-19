import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env', isOptional: true);
  runApp(const ProviderScope(child: MovieTrackerApp()));
}

class MovieTrackerApp extends ConsumerWidget {
  const MovieTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Movie Tracker',
      theme: AppTheme.buildTheme(palette),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
