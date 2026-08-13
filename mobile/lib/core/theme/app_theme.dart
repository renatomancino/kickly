import 'package:flutter/material.dart';

class AppTheme {
  // Same visual tokens used by src/app/globals.css in the PWA.
  static const primary = Color(0xFFC7FF3D);
  static const background = Color(0xFF0B0D0C);
  static const surface = Color(0xFF181C19);
  static const surfaceHigh = Color(0xFF222722);
  static const outline = Color(0xFF303630);

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
      visualDensity: VisualDensity.standard,
    );

    final readableText = base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );

    return base.copyWith(
      textTheme: readableText.copyWith(
        headlineLarge: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
        headlineMedium: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(color: Color(0xFFF3F6F3)),
        bodyMedium: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 14,
          height: 1.45,
        ),
        bodySmall: const TextStyle(color: Color(0xFF9EA59E)),
        labelLarge: const TextStyle(
          color: Color(0xFFF3F6F3),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
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
          borderRadius: BorderRadius.circular(22),
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
        labelStyle: const TextStyle(
          color: Color(0xFFD7DDD7),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFA0B0D0C),
        indicatorColor: Colors.transparent,
        height: 66,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: Color(0xFF9EA59E),
        indicatorColor: primary,
        dividerColor: outline,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
