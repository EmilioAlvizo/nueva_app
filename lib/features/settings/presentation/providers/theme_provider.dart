// lib/features/settings/presentation/providers/theme_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { dark, light }

class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.dark;

  void setDark()  => state = AppThemeMode.dark;
  void setLight() => state = AppThemeMode.light;
  void toggle()   => state = state == AppThemeMode.dark
      ? AppThemeMode.light
      : AppThemeMode.dark;

  bool get isDark => state == AppThemeMode.dark;
}

final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeMode>(ThemeNotifier.new);