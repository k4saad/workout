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
  // Black, grey, crimson. One accent colour, used sparingly, so that when
  // something IS crimson it means "this is the thing".
  static const crimson = Color(0xFFD81E3F);
  static const crimsonDeep = Color(0xFF7E1024);

  /// Kept as an alias so older call sites keep compiling. Crimson is the
  /// accent now; there is no second red.
  static const oxblood = crimson;

  // Day-kind rails. Distinguishable under a bare bulb by LIGHTNESS as much as
  // hue, which is what survives both bad light and colour-vision deficiency —
  // and always paired with a glyph, never load-bearing on their own.
  static const kindLift = crimson; // the main event
  static const kindCardio = Color(0xFFB9553F); // rust — crimson family, dimmer
  static const kindRest = Color(0xFF4E535C); // cool dark grey
  static const kindMobility = Color(0xFF8E8E99); // neutral light grey

  static const moss = kindCardio;
  static const slate = kindRest;
  static const dusk = kindMobility;

  // Near-black, not black: pure #000 on OLED smears on scroll and hides every
  // elevation boundary.
  static const bg = Color(0xFF0A0A0C);
  static const surface = Color(0xFF151518);
  static const surfaceHigh = Color(0xFF1F1F24);
  static const outline = Color(0xFF34343C);
  static const text = Color(0xFFF4F4F6);
  static const textDim = Color(0xFFA0A0AA);

  // Semantic states only, never chrome. Amber and green are what "careful"
  // and "good" mean to everyone, and both are backed by a glyph anyway.
  static const warn = Color(0xFFE0A93B);
  static const good = Color(0xFF5FA37B);

  static Color forKind(DayKind kind) => switch (kind) {
    DayKind.lift => kindLift,
    DayKind.cardio => kindCardio,
    DayKind.rest => kindRest,
    DayKind.mobility => kindMobility,
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
      primary: crimson,
      onPrimary: Colors.white,
      primaryContainer: crimsonDeep,
      onPrimaryContainer: text,
      secondary: Color(0xFF6E7078),
      onSecondary: Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceHigh,
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: crimson.withValues(alpha: 0.20),
        // 68 not 80: the bar is permanent, and every pixel it takes is a pixel
        // of the session not on screen.
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? text : textDim,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 25,
            color: states.contains(WidgetState.selected) ? crimson : textDim,
          ),
        ),
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
