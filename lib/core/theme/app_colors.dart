import 'package:flutter/material.dart';

class AppColorsLight {
  static const Color background = Color(0xFFE9EDF8);
  static const Color backgroundEnd = Color(0xFFF3EEFF);
  static const Color surface = Color(0xE6FFFFFF);
  static const Color surfaceSolid = Color(0xFFF7F8FD);
  static const Color surfaceElevated = Color(0xFFFBFBFE);
  static const Color primary = Color(0xFF7C6CF6);
  static const Color primaryDark = Color(0xFF5E52E0);
  static const Color accent = Color(0xFF22C55E);
  static const Color textPrimary = Color(0xFF1C1A33);
  static const Color textSecondary = Color(0xFF5A5878);
  static const Color textMuted = Color(0xFF9A97B5);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color border = Color(0x40FFFFFF);
  static const Color chipBg = Color(0xFFE9E5FF);
  static const Color shadow = Color(0x1A5E52E0);
  static const Color navBar = Color(0xF5FFFFFF);
}

class AppColorsDark {
  // مثل مرجع: آبی‌بنفش ملایم، نه سیاه خالص
  static const Color background = Color(0xFF22233A);
  static const Color backgroundEnd = Color(0xFF2C2D4A);
  static const Color surface = Color(0xD92F314C);
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
  static const Color shadow = Color(0x33000000);
  static const Color navBar = Color(0xF222233A);
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
