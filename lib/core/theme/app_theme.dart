import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData theme(bool dark) {
    AppColors.isDark = dark;
    final bg = dark ? AppColorsDark.background : AppColorsLight.background;
    final surface = dark ? AppColorsDark.surface : AppColorsLight.surface;
    final primary = dark ? AppColorsDark.primary : AppColorsLight.primary;
    final text = dark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary;
    final textSec = dark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary;
    final muted = dark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
    final border = dark ? AppColorsDark.border : AppColorsLight.border;
    final accent = dark ? AppColorsDark.accent : AppColorsLight.accent;
    final danger = dark ? AppColorsDark.danger : AppColorsLight.danger;

    final base = GoogleFonts.vazirmatnTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: danger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.vazirmatn(fontSize: 18, fontWeight: FontWeight.w700, color: text),
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      textTheme: base.copyWith(
        headlineMedium: GoogleFonts.vazirmatn(fontSize: 22, fontWeight: FontWeight.w800, color: text),
        titleLarge: GoogleFonts.vazirmatn(fontSize: 17, fontWeight: FontWeight.w700, color: text),
        titleMedium: GoogleFonts.vazirmatn(fontSize: 15, fontWeight: FontWeight.w600, color: text),
        bodyLarge: GoogleFonts.vazirmatn(fontSize: 15, color: text),
        bodyMedium: GoogleFonts.vazirmatn(fontSize: 13, color: textSec),
        bodySmall: GoogleFonts.vazirmatn(fontSize: 12, color: muted),
        labelLarge: GoogleFonts.vazirmatn(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withOpacity(0.45),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.vazirmatn(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.5), width: 1.5),
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.vazirmatn(color: muted, fontSize: 14),
        prefixIconColor: muted,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 4,
        shadowColor: dark ? Colors.black54 : Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: border,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withOpacity(0.4) : border),
      ),
    );
  }

  static ThemeData get darkTheme => theme(true);
  static ThemeData get lightTheme => theme(false);
}
