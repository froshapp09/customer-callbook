import 'package:flutter/material.dart';

/// Light — soft, not pure white
class AppColorsLight {
  static const Color background = Color(0xFFE8EAF2);
  static const Color surface = Color(0xFFF4F5FA);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5548E8);
  static const Color accent = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFF1A1C2C);
  static const Color textSecondary = Color(0xFF5C6070);
  static const Color textMuted = Color(0xFF9AA0B0);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);
  static const Color border = Color(0xFFD0D4E0);
  static const Color chipBg = Color(0xFFE0DEFF);
  static const Color shadow = Color(0x33000000);
}

/// Dark — deep charcoal, soft contrast
class AppColorsDark {
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF1A1D27);
  static const Color surfaceElevated = Color(0xFF242836);
  static const Color primary = Color(0xFF8B83FF);
  static const Color primaryDark = Color(0xFF6C63FF);
  static const Color accent = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFF0F1F5);
  static const Color textSecondary = Color(0xFFA0A5B8);
  static const Color textMuted = Color(0xFF6B7085);
  static const Color danger = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF4FC3F7);
  static const Color border = Color(0xFF2E3345);
  static const Color chipBg = Color(0xFF2A2750);
  static const Color shadow = Color(0x66000000);
}

/// Runtime colors via Theme extension style helpers
class AppColors {
  static bool isDark = true;

  static Color get background => isDark ? AppColorsDark.background : AppColorsLight.background;
  static Color get surface => isDark ? AppColorsDark.surface : AppColorsLight.surface;
  static Color get surfaceElevated => isDark ? AppColorsDark.surfaceElevated : AppColorsLight.surfaceElevated;
  static Color get primary => isDark ? AppColorsDark.primary : AppColorsLight.primary;
  static Color get primaryDark => isDark ? AppColorsDark.primaryDark : AppColorsLight.primaryDark;
  static Color get accent => isDark ? AppColorsDark.accent : AppColorsLight.accent;
  static Color get success => accent;
  static Color get textPrimary => isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary;
  static Color get textSecondary => isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary;
  static Color get textMuted => isDark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
  static Color get danger => isDark ? AppColorsDark.danger : AppColorsLight.danger;
  static Color get warning => isDark ? AppColorsDark.warning : AppColorsLight.warning;
  static Color get info => isDark ? AppColorsDark.info : AppColorsLight.info;
  static Color get border => isDark ? AppColorsDark.border : AppColorsLight.border;
  static Color get chipBg => isDark ? AppColorsDark.chipBg : AppColorsLight.chipBg;
  static Color get shadow => isDark ? AppColorsDark.shadow : AppColorsLight.shadow;

  static const Color avatar1 = Color(0xFF7C6CF0);
  static const Color avatar2 = Color(0xFFE91E8C);
  static const Color avatar3 = Color(0xFF00BFA5);
  static const Color avatar4 = Color(0xFF42A5F5);
}
