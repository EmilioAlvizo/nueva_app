// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const bgDark      = Color(0xFF0D1117);
  static const bgCard      = Color(0xFF161B22);
  static const bgCardLight = Color(0xFF1C2333);
  static const bgInput     = Color(0xFF1A2030);

  // Accent
  static const green      = Color(0xFF39D353);
  static const greenDark  = Color(0xFF238636);
  static const greenGlow  = Color(0x4039D353);
  static const amber      = Color(0xFFD97706);

  // Text
  static const textPrimary   = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted     = Color(0xFF484F58);

  // Semantic
  static const positive = Color(0xFF39D353);
  static const negative = Color(0xFFF85149);

  // Border
  static const border      = Color(0xFF30363D);
  static const borderFocus = Color(0xFF39D353);
}