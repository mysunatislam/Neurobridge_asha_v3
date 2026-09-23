import 'package:flutter/material.dart';

/// NeuroBridge Asha calm healthcare-safe theme.
/// Dark navy/charcoal base, soft teal primary, warm amber attention,
/// red only for urgent/emergency. Light mode also provided.
class AshaTheme {
  static const teal = Color(0xFF2DD4BF);
  static const tealDim = Color(0xFF0E3A3A);
  static const navy = Color(0xFF060B18);
  static const surface = Color(0xFF0D1528);
  static const card = Color(0xFF101B3C);
  static const amber = Color(0xFFFFC44D);
  static const danger = Color(0xFFFF5A6E);
  static const ink = Color(0xFFF2F5FA);
  static const muted = Color(0xFF93A1BB);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
    ).copyWith(
      primary: teal,
      secondary: teal,
      surface: surface,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: ink,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 18, color: ink, height: 1.4),
        bodyMedium: TextStyle(fontSize: 16, color: ink, height: 1.4),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(220, 64),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C72),
      brightness: Brightness.light,
    );
    return ThemeData(useMaterial3: true, colorScheme: scheme);
  }
}
