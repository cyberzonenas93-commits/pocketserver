import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Vibrant palette: deep indigo base + electric cyan & coral
  static const Color primary = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceElevated = Color(0xFF252542);
  static const Color accent = Color(0xFF00E5CC);
  static const Color accentSecondary = Color(0xFF7C3AED);
  static const Color warning = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00E5CC);
  static const Color text = Color(0xFFF0F0F5);
  static const Color textMuted = Color(0xFFA0A0B8);
  static const double radius = 16.0;
  static const double radiusSmall = 12.0;

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0F1A),
      Color(0xFF16162A),
      Color(0xFF1A1A2E),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E5CC), Color(0xFF00B8A3)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF252542),
      Color(0xFF1E1E38),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentSecondary,
        surface: surface,
        onSurface: text,
        error: warning,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData.dark().textTheme.copyWith(
              bodyLarge: const TextStyle(color: text),
              bodyMedium: const TextStyle(color: text),
              bodySmall: TextStyle(color: text.withValues(alpha: 0.8)),
              titleLarge: const TextStyle(
                color: text,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              titleMedium: const TextStyle(
                color: text,
                fontWeight: FontWeight.w600,
              ),
              labelLarge: const TextStyle(
                color: text,
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: text),
        titleTextStyle: GoogleFonts.dmSans(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.dmSans(color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        titleTextStyle: GoogleFonts.dmSans(color: text, fontWeight: FontWeight.w700, fontSize: 20),
      ),
    );
  }
}
