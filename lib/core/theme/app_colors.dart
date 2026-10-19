import 'package:flutter/material.dart';

class AppColorsLight {
  static const Color background = Color(0xFFF0F2FA);
  static const Color backgroundEnd = Color(0xFFE8E4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSolid = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5548E0);
  static const Color accent = Color(0xFF16A34A);
  static const Color textPrimary = Color(0xFF1A1730);
  static const Color textSecondary = Color(0xFF5C5878);
  static const Color textMuted = Color(0xFF9B97B0);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);
  static const Color border = Color(0xFFE2E0F0);
  static const Color chipBg = Color(0xFFEEECFF);
  static const Color shadow = Color(0x1A000000);
  static const Color navBar = Color(0xFFFFFFFF);
}

class AppColorsDark {
  static const Color background = Color(0xFF22233A);
  static const Color backgroundEnd = Color(0xFF2C2D4A);
  static const Color surface = Color(0xFF2F314C);
  static const Color surfaceSolid = Color(0xFF2F314C);
  static const Color surfaceElevated = Color(0xFF383A58);
  static const Color primary = Color(0xFF9B8CFF);
  static const Color primaryDark = Color(0xFF7C6CF6);
  static const Color accent = Color(0xFF34D399);
  static const Color textPrimary = Color(0xFFF2F0FF);
  static const Color textSecondary = Color(0xFFB8B5D0);
  static const Color textMuted = Color(0xFF8885A5);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);
  static const Color border = Color(0x28FFFFFF);
  static const Color chipBg = Color(0xFF3F3B68);
  static const Color shadow = Color(0x40000000);
  static const Color navBar = Color(0xFF1E1F33);
}

class AppColors {
  static bool isDark = true;

  static Color get background => isDark ? AppColorsDark.background : AppColorsLight.background;
  static Color get backgroundEnd => isDark ? AppColorsDark.backgroundEnd : AppColorsLight.backgroundEnd;
  static Color get surface => isDark ? AppColorsDark.surface : AppColorsLight.surface;
  static Color get surfaceSolid => isDark ? AppColorsDark.surfaceSolid : AppColorsLight.surfaceSolid;
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
  static Color get navBar => isDark ? AppColorsDark.navBar : AppColorsLight.navBar;

  static const List<Color> avatarPalette = [
    Color(0xFF7C6CF0),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
  ];

  static const Map<String, int> defaultTagColors = {
    'مشتری': 0xFF7C6CF0,
    'همکار': 0xFF22C55E,
    'سایر': 0xFF94A3B8,
  };
}
