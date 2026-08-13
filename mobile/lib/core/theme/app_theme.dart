import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF75E36B);
  static const background = Color(0xFF0B0D0C);
  static const surface = Color(0xFF141715);
  static const surfaceHigh = Color(0xFF1C211E);
  static const outline = Color(0xFF2B312D);

  static ThemeData get dark {
    const colors = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF071006),
      secondary: Color(0xFFB8F5B2),
      onSecondary: Color(0xFF071006),
      surface: surface,
      onSurface: Color(0xFFF3F6F3),
      error: Color(0xFFFF6B72),
      onError: Color(0xFF240004),
      outline: outline,
      surfaceContainerLowest: background,
      surfaceContainerLow: Color(0xFF101311),
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: Color(0xFF242A26),
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: outline),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: outline),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xF5141715),
        indicatorColor: Color(0x2975E36B),
        height: 72,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
