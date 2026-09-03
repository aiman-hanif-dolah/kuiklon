import 'package:flutter/material.dart';

class KColors {
  static const Color inkBg = Color(0xFF101014);
  static const Color inkSurface = Color(0xFF17171C);
  static const Color inkElevated = Color(0xFF1E1E24);
  static const Color inkBorder = Color(0xFF2A2A32);
  static const Color textPrimary = Color(0xFFEDEDF2);
  static const Color textSecondary = Color(0xFF9C9CA8);
  static const Color textMuted = Color(0xFF5C5C68);
  static const Color lime = Color(0xFFB6F53C);
  static const Color limeDim = Color(0xFF7FA82A);
  static const Color warm = Color(0xFFF2B450);
  static const Color warmDeep = Color(0xFFC87F2F);
  static const Color red = Color(0xFFF26D6D);
  static const Color teal = Color(0xFF5AD8C8);
}

class KTheme {
  static ThemeData dark() {
    const base = ColorScheme.dark(
      primary: KColors.lime,
      onPrimary: Color(0xFF0C0C10),
      secondary: KColors.warm,
      onSecondary: Color(0xFF0C0C10),
      surface: KColors.inkSurface,
      onSurface: KColors.textPrimary,
      error: KColors.red,
      outline: KColors.inkBorder,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: KColors.inkBg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.compact,
      fontFamily: 'SpaceGrotesk',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.05,
            color: KColors.textPrimary),
        displayMedium: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: KColors.textPrimary),
        headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: KColors.textPrimary),
        bodyLarge: TextStyle(
            fontSize: 15, height: 1.5, color: KColors.textPrimary),
        bodyMedium: TextStyle(
            fontSize: 13.5, height: 1.45, color: KColors.textSecondary),
        labelLarge: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: KColors.textPrimary),
        labelMedium: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            color: KColors.textSecondary),
        labelSmall: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: KColors.textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KColors.inkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KColors.inkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KColors.inkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: KColors.lime, width: 1.4),
        ),
        hintStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            color: KColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KColors.lime,
          foregroundColor: const Color(0xFF0C0C10),
          textStyle: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KColors.textPrimary,
          side: const BorderSide(color: KColors.inkBorder),
          textStyle: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: KColors.inkBorder, thickness: 1),
    );
  }
}