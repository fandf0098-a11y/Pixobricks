// THEME LOCK: dark + light — source: user prompt ("Dark Mode and Light Mode") + domain signal (gaming/creative)
// Scaffold.backgroundColor = AppTheme.backgroundDark / AppTheme.backgroundLight — ALL screens

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Primary palette ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF); // electric violet
  static const Color primaryLight = Color(0xFF9B94FF);
  static const Color primaryContainer = Color(0xFF2D2866);
  static const Color secondary = Color(0xFF00D4FF); // AI cyan
  static const Color secondaryContainer = Color(0xFF003D4D);
  static const Color tertiary = Color(0xFFFF6B9D); // playful pink accent

  // ── Semantic colours ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color gemColor = Color(0xFF00D4FF);
  static const Color xpColor = Color(0xFF2ECC71);

  // ── Dark surfaces ─────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0D0B1E);
  static const Color surfaceDark = Color(0xFF1A1730);
  static const Color surfaceVariantDark = Color(0xFF252240);
  static const Color glassOverlayDark = Color(0x14FFFFFF); // 8% white

  // ── Light surfaces ────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF0EEFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE8E4FF);
  static const Color glassOverlayLight = Color(0x1A6C63FF); // 10% primary

  // ── Gradient presets ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [Color(0xFF0D0B1E), Color(0xFF1A0B3E), Color(0xFF0B1A3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    colors: [Color(0xFFF0EEFF), Color(0xFFE8F4FF), Color(0xFFEEF0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFFD4D0FF),
      secondary: secondary,
      onSecondary: Color(0xFF001F2A),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: Color(0xFFB3F0FF),
      tertiary: tertiary,
      onTertiary: Colors.white,
      surface: surfaceDark,
      onSurface: Color(0xFFECEAFF),
      surfaceContainerHighest: surfaceVariantDark,
      onSurfaceVariant: Color(0xFFB0AECF),
      error: error,
      onError: Colors.white,
      outline: Color(0xFF4A4870),
      outlineVariant: Color(0xFF2E2C50),
      inverseSurface: Color(0xFFECEAFF),
      onInverseSurface: backgroundDark,
      inversePrimary: primary,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: _buildTextTheme(const Color(0xFFECEAFF)),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFFECEAFF),
    ),
    cardTheme: CardThemeData(
      color: glassOverlayDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withAlpha(20), width: 1),
      ),
    ),
    inputDecorationTheme: _buildInputDecorationTheme(isDark: true),
    elevatedButtonTheme: _buildElevatedButtonTheme(),
    filledButtonTheme: _buildFilledButtonTheme(),
    chipTheme: _buildChipTheme(isDark: true),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Color(0xFFB0AECF)),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E2C50),
      thickness: 1,
    ),
  );

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8E4FF),
      onPrimaryContainer: Color(0xFF1A1566),
      secondary: Color(0xFF0099BB),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCCF5FF),
      onSecondaryContainer: Color(0xFF001F2A),
      tertiary: Color(0xFFD44080),
      onTertiary: Colors.white,
      surface: surfaceLight,
      onSurface: Color(0xFF1A1840),
      surfaceContainerHighest: surfaceVariantLight,
      onSurfaceVariant: Color(0xFF4A4870),
      error: error,
      onError: Colors.white,
      outline: Color(0xFFB0AECF),
      outlineVariant: Color(0xFFDDDBFF),
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: _buildTextTheme(const Color(0xFF1A1840)),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF1A1840),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withAlpha(179),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDDDBFF), width: 1),
      ),
    ),
    inputDecorationTheme: _buildInputDecorationTheme(isDark: false),
    elevatedButtonTheme: _buildElevatedButtonTheme(),
    filledButtonTheme: _buildFilledButtonTheme(),
    chipTheme: _buildChipTheme(isDark: false),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF4A4870)),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFDDDBFF),
      thickness: 1,
    ),
  );

  // ── Shared builders ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color baseColor) {
    return GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: 0.5,
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme({
    required bool isDark,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withAlpha(15)
          : const Color(0xFF6C63FF).withAlpha(15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withAlpha(31)
              : const Color(0xFF6C63FF).withAlpha(51),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withAlpha(31)
              : const Color(0xFF6C63FF).withAlpha(51),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white.withAlpha(128) : const Color(0xFF4A4870),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: isDark
            ? Colors.white.withAlpha(77)
            : const Color(0xFF4A4870).withAlpha(128),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static ChipThemeData _buildChipTheme({required bool isDark}) {
    return ChipThemeData(
      backgroundColor: isDark
          ? Colors.white.withAlpha(20)
          : const Color(0xFF6C63FF).withAlpha(20),
      selectedColor: primary,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      side: BorderSide(
        color: isDark
            ? Colors.white.withAlpha(31)
            : const Color(0xFF6C63FF).withAlpha(51),
      ),
    );
  }
}