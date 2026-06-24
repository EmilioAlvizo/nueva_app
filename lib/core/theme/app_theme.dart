// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Construye los ThemeData claro y oscuro a partir de AppColors.
/// Úsalos en MaterialApp.router como `theme: AppTheme.light` o
/// `theme: AppTheme.dark`, eligiendo cuál según tu themeProvider.
abstract final class AppTheme {
  static final ThemeData light = _build(isDark: false);
  static final ThemeData dark = _build(isDark: true);

  static ThemeData _build({required bool isDark}) {
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final bg = isDark ? AppColors.bg : AppColors.bgCard3Lg;
    final card = isDark ? AppColors.bgCard : AppColors.bgLight;
    final input = isDark ? AppColors.bgInput : AppColors.bgInputLg;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.textPrimaryLg;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLg;
    // Igual que en tus widgets: border1lg para dark, border1 para light.
    final border = isDark ? AppColors.border1lg : AppColors.border1;

    return base.copyWith(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
            primary: AppColors.green,
            surface: card,
            error: AppColors.negative,
          ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardColor: card,
      dividerColor: border,

      // ── Botones (tu GreenButton hereda esto automáticamente) ──────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: isDark ? AppColors.bg : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Inputs (tu AppTextField hereda esto automáticamente) ──────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        hintStyle: TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.5),
        ),
      ),
    );
  }
}