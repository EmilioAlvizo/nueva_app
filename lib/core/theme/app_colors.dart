// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const bg = Color(0xFF0D1117);
  static const bgCard = Color(0xFF2a2d25);
  static const bgCard2 = Color(0xFF1f221e);
  static const bgCard3 = Color(0xFF1C2333);
  static const bgInput = Color(0xFF1A2030);

  // Backgrounds light
  static const bgLight = Color(0xFFF8F9FA);
  static const bgCardLg = Color(0xFFF1F3ED);
  static const bgCard2Lg = Color(0xFFE6EAE2);
  static const bgCard3Lg = Color(0xFFEEF2F6);
  static const bgInputLg = Color(0xFFF0F2F5);

  /* static const bgDark = Color(0xFF0D1117);
  static const bgCard = Color(0xFF161B22);
  static const bgCardLight = Color(0xFF1C2333);
  static const bgInput = Color(0xFF1A2030); */

  // Accent
  static const green = Color(0xFF39D353);
  static const greenDark = Color(0xFF238636);
  static const greenGlow = Color(0x4039D353);
  static const amber = Color(0xFFD97706);

  // Text
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);

  // Text light
  static const textPrimaryLg = Color(0xFF1F2328);
  static const textSecondaryLg = Color(0xFF57606A);
  static const textMutedLg = Color(0xFF8C95A0);

  // Semantic
  static const positive = Color(0xFF39D353);
  static const negative = Color(0xFFF85149);
  static const warning = Color(0xFFD29922);

  // Border
  static const border = Color(0xFF30363D);
  static const borderFocus = Color(0xFF39D353);
  static const border1 = Colors.black12;
  static const border1lg = Colors.white12;

  // array de tipos de animales

  static const naranjal = Color(0xFFee862b);
  static const naranjao = Color(0xFFF3a968);

  static const tipoColor = [
    Color(0xFF06B6D4), // cyan
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF10B981), // emerald
    Color(0xFFF97316), // orange
  ];
}
