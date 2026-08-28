// lib/main.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/providers/theme_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Supabase.initialize(
    /* url: 'https://wjdazuycudtzycpekxga.supabase.co',
    anonKey: 'sb_publishable_WQO-DB3TWcrQvk9dVfH7Ng_W36hiG_f', */
    url: 'https://xagnnkqqtdtvadaseubc.supabase.co',
    anonKey: 'sb_publishable_ItraVK0Eb5JHGX17QNfZIA_2A7VLfnj',
  );

  runApp(
    // ProviderScope wraps the whole app — required by Riverpod
    const ProviderScope(child: GallinasApp()),
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}