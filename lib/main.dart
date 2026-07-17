// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wjdazuycudtzycpekxga.supabase.co',
    anonKey: 'sb_publishable_WQO-DB3TWcrQvk9dVfH7Ng_W36hiG_f',
  );

  runApp(
    // ProviderScope wraps the whole app — required by Riverpod
    const ProviderScope(
      child: GallinasApp(),
    ),
  );
}

class GallinasApp extends ConsumerWidget {
  const GallinasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    return MaterialApp.router(
      title: 'GallinasApp',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark : AppTheme.light,
      routerConfig: router,
    );
  }
}