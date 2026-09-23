import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Dark-first, high-contrast theme for a badly lit basement, read at arm's
/// length, between heavy sets, with chalky hands.
///
/// Rules this encodes:
///  - 48 dp minimum tap targets everywhere
///  - type large enough to read from the floor while racked
///  - colour is NEVER the only carrier of meaning; every state also has a glyph
///  - one accent. Crimson means "this is the thing"; it is never decoration.
abstract final class AppTheme {
  // Black, grey, crimson. One accent colour, used sparingly, so that when
  // something IS crimson it means "this is the thing".
  static const crimson = Color(0xFFD81E3F);
  static const crimsonDeep = Color(0xFF7E1024);

  /// The lit edge of a crimson surface — gradients and glows only, never a
  /// second accent.
  static const crimsonBright = Color(0xFFFF3B5C);

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
  static const surfaceLow = Color(0xFF101013);
  static const surface = Color(0xFF151518);
  static const surfaceHigh = Color(0xFF1F1F24);
  static const surfaceHigher = Color(0xFF2A2A31);
  static const outline = Color(0xFF34343C);
  static const outlineSoft = Color(0xFF24242A);
  static const text = Color(0xFFF4F4F6);
  static const textDim = Color(0xFFA0A0AA);
  static const textFaint = Color(0xFF6E6E78);

  // Semantic states only, never chrome. Amber and green are what "careful"
  // and "good" mean to everyone, and both are backed by a glyph anyway.
  static const warn = Color(0xFFE0A93B);
  static const good = Color(0xFF5FA37B);
  static const danger = Color(0xFFE5645C);

  /// The one gradient: crimson lit from the top left. Hero surfaces and the
  /// primary call to action, nowhere else.
  static const crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [crimsonBright, crimson, crimsonDeep],
    stops: [0.0, 0.45, 1.0],
  );

  /// A card that sits a fraction above the page: lighter at the top edge,
  /// the way light falls from a ceiling bulb.
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B1B20), surface],
  );

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

  /// Body text family. Named explicitly: a style with no family falls back
  /// to the OEM font on some phones and to box glyphs in tests.
  static const fontFamily = 'Roboto';

  /// Display face for numbers — loads, reps, kcal, pace. Bundled, so it is
  /// the same on every phone. Tabular figures so a ticking timer does not
  /// jitter sideways.
  static const numericFamily = 'RobotoCondensed';

  static TextStyle numeric(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = text,
    double? height = 1.0,
    double letterSpacing = -0.5,
  }) => TextStyle(
    fontFamily: numericFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Quotes and the launch screen. `serif` resolves to Noto Serif on
  /// Android — a system font, so nothing is fetched and nothing is bundled.
  static TextStyle serif(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = text,
    FontStyle style = FontStyle.normal,
    double height = 1.4,
  }) => TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontStyle: style,
    height: height,
  );

  /// Small caps-style overline: section labels, eyebrows above a title.
  static const overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: textDim,
    height: 1.2,
  );

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
      onSurfaceVariant: textDim,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigher,
      error: danger,
      onError: Colors.white,
      outline: outline,
      outlineVariant: outlineSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    // Each style is DERIVED from the Material one with copyWith, never
    // replaced with a bare TextStyle: a replacement drops the family, the
    // colour and the letter spacing, which is how every heading in v2 ended
    // up in whatever font the phone maker ships.
    final t = base.textTheme;
    final textTheme = t
        .copyWith(
          displayLarge: t.displayLarge!.copyWith(
            fontFamily: numericFamily,
            fontSize: 64,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -1.5,
          ),
          displayMedium: t.displayMedium!.copyWith(
            fontFamily: numericFamily,
            fontSize: 48,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -1,
          ),
          // Deliberately a notch larger than Material defaults.
          displaySmall: t.displaySmall!.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.6,
          ),
          headlineMedium: t.headlineMedium!.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: -0.4,
          ),
          headlineSmall: t.headlineSmall!.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.2,
          ),
          titleLarge: t.titleLarge!.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleMedium: t.titleMedium!.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
            letterSpacing: 0,
          ),
          titleSmall: t.titleSmall!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: t.bodyLarge!.copyWith(fontSize: 17, height: 1.45),
          bodyMedium: t.bodyMedium!.copyWith(fontSize: 15.5, height: 1.45),
          bodySmall: t.bodySmall!.copyWith(fontSize: 13.5, height: 1.4),
          labelLarge: t.labelLarge!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: t.labelMedium!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        )
        .apply(bodyColor: text, displayColor: text, fontFamily: fontFamily);

    // The numeric faces survive the family-wide apply above.
    final themed = textTheme.copyWith(
      displayLarge: textTheme.displayLarge!.copyWith(
        fontFamily: numericFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: textTheme.displayMedium!.copyWith(
        fontFamily: numericFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final shape16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    );

    return base.copyWith(
      textTheme: themed,
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // The fade-forwards transition, painted on the PAGE background.
          // Its default is ColorScheme.surface, which flashed a lighter band
          // across every push.
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: bg,
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: themed.headlineSmall!.copyWith(
          fontWeight: FontWeight.w800,
          color: text,
        ),
        iconTheme: const IconThemeData(color: text, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: const BorderSide(color: outlineSoft, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineSoft, space: 1),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 14,
        iconColor: textDim,
        textColor: text,
        shape: shape16,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: themed.titleMedium!.copyWith(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: textFaint,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: text,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: themed.titleSmall!.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: text,
          textStyle: themed.titleSmall!.copyWith(fontSize: 15.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: text,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: crimson.withValues(alpha: 0.22),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        labelStyle: themed.labelLarge!.copyWith(fontSize: 14, color: text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        checkmarkColor: text,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: surface,
          foregroundColor: textDim,
          selectedBackgroundColor: crimson.withValues(alpha: 0.22),
          selectedForegroundColor: text,
          side: const BorderSide(color: outline),
          textStyle: themed.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? crimson : surfaceHigher,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: crimson,
        inactiveTrackColor: surfaceHigher,
        thumbColor: Colors.white,
        overlayColor: Color(0x33D81E3F),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: crimson,
        linearTrackColor: surfaceHigher,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: textDim,
        indicatorColor: crimson,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: outlineSoft,
        labelStyle: themed.titleSmall!.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: themed.titleSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: crimson, width: 2),
        ),
        labelStyle: const TextStyle(color: textDim),
        hintStyle: const TextStyle(color: textFaint),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: outlineSoft),
        ),
        titleTextStyle: themed.headlineSmall,
        contentTextStyle: themed.bodyLarge!.copyWith(color: textDim),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        dragHandleColor: outline,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: crimson.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        // 70 not 80: the bar is permanent, and every pixel it takes is a pixel
        // of the session not on screen.
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigher,
        contentTextStyle: themed.bodyLarge!.copyWith(fontSize: 16),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHigher,
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        textStyle: const TextStyle(color: text, fontSize: 14),
      ),
    );
  }
}

/// Corner radii. Larger surfaces get rounder corners, so nesting reads.
abstract final class AppRadius {
  static const double xs = 6;
  static const double s = 10;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 28;
}

/// Motion. Quick enough never to be in the way between sets, slow enough to
/// show where something came from.
///
/// Every animated widget checks `MediaQuery.disableAnimationsOf` and jumps
/// straight to the end state when the phone asks for reduced motion.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 460);

  /// Stagger between list items entering.
  static const stagger = Duration(milliseconds: 45);

  static const curve = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const spring = Curves.easeOutBack;

  /// True when animations should be skipped entirely.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
