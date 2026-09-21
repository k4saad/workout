import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Dark-first, high-contrast theme for a badly lit basement, read at arm's
/// length, between heavy sets, with chalky hands.
///
/// Rules this encodes:
///  - 48 dp minimum tap targets everywhere
///  - type large enough to read from the floor while racked
///  - colour is NEVER the only carrier of meaning; every state also has a glyph
abstract final class AppTheme {
  // Day-kind rails. Chosen to stay distinguishable under a bare bulb and to
  // survive the most common colour-vision deficiencies — but always paired
  // with a glyph, never load-bearing on their own.
  static const oxblood = Color(0xFFB4413C); // lift
  static const moss = Color(0xFF6E9457); // cardio
  static const slate = Color(0xFF5A6169); // rest
  static const dusk = Color(0xFF7A6EA8); // mobility

  static const bg = Color(0xFF0E1012);
  static const surface = Color(0xFF181B1F);
  static const surfaceHigh = Color(0xFF23272D);
  static const outline = Color(0xFF3A4048);
  static const text = Color(0xFFF2F4F6);
  static const textDim = Color(0xFFA8B0B8);

  static const warn = Color(0xFFE8B84B);
  static const good = Color(0xFF6BBF8A);

  static Color forKind(DayKind kind) => switch (kind) {
    DayKind.lift => oxblood,
    DayKind.cardio => moss,
    DayKind.rest => slate,
    DayKind.mobility => dusk,
  };

  /// The glyph that carries the meaning when the colour cannot.
  static String glyphForKind(DayKind kind) => switch (kind) {
    DayKind.lift => '■', // filled square
    DayKind.cardio => '▲', // triangle
    DayKind.rest => '·', // middle dot
    DayKind.mobility => '◆', // diamond
  };

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: oxblood,
      onPrimary: Colors.white,
      secondary: moss,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: text,
      error: Color(0xFFE5645C),
      onError: Colors.white,
      outline: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            // Deliberately a notch larger than Material defaults.
            displaySmall: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
            headlineMedium: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            headlineSmall: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            titleLarge: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            titleMedium: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            bodyLarge: const TextStyle(fontSize: 17, height: 1.45),
            bodyMedium: const TextStyle(fontSize: 15.5, height: 1.45),
            labelLarge: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outline, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline, space: 1),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        iconColor: textDim,
        textColor: text,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: text,
          side: const BorderSide(color: outline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: outline),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: text, fontSize: 16),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Spacing scale. Sized for thumbs, not for pixels.
abstract final class Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const s = SizedBox(height: 8, width: 8);
  static const m = SizedBox(height: 14, width: 14);
  static const l = SizedBox(height: 22, width: 22);
  static const xl = SizedBox(height: 34, width: 34);

  static const pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 32);
}
