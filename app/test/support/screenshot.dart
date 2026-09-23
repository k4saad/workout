import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/router.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';

/// Renders real screens to PNG so a human (or a reviewing agent) can LOOK at
/// them without a phone.
///
/// Widget tests draw text in the Ahem test font — every glyph a filled box —
/// which proves layout and nothing about how a screen reads. [loadRealFonts]
/// registers Roboto and the Material icon font from the Flutter SDK's own
/// cache, so the PNGs show what the device shows.
///
/// Output goes to `build/screens/`, which git ignores. These are eyes, not
/// goldens: nothing here fails a build when a pixel moves.
///
///     flutter test test/screens/        # then open build/screens/*.png
abstract final class Screenshot {
  static bool _fontsLoaded = false;

  /// Family name the desktop symbol font is registered under.
  static const symbolFallback = 'TestSymbols';

  /// The app theme with the symbol fallback added to every text style. Only
  /// the FALLBACK changes; each style keeps the family the theme gave it.
  static ThemeData themed(ThemeData t) => t.copyWith(
    textTheme: t.textTheme.apply(fontFamilyFallback: const [symbolFallback]),
  );

  /// The SDK's `bin/cache/artifacts/material_fonts`, found from the running
  /// flutter_tester binary so no path is hardcoded to one machine.
  static Directory get _fontDir {
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.path != dir.parent.path) {
      final candidate = Directory(
        '${dir.path}${Platform.pathSeparator}material_fonts',
      );
      if (candidate.existsSync()) return candidate;
      final nested = Directory(
        '${dir.path}${Platform.pathSeparator}artifacts'
        '${Platform.pathSeparator}material_fonts',
      );
      if (nested.existsSync()) return nested;
      dir = dir.parent;
    }
    throw StateError('material_fonts not found above the flutter_tester');
  }

  static Future<void> loadRealFonts() async {
    // Fonts registered before the binding exists are silently ignored and
    // every glyph comes out as a box.
    TestWidgetsFlutterBinding.ensureInitialized();
    if (_fontsLoaded) return;
    final dir = _fontDir;
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        final file = File('${dir.path}${Platform.pathSeparator}$f');
        if (!file.existsSync()) continue;
        final bytes = file.readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await family('Roboto', [
      'roboto-thin.ttf',
      'roboto-light.ttf',
      'roboto-regular.ttf',
      'roboto-italic.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]);
    await family('RobotoCondensed', [
      'robotocondensed-regular.ttf',
      'robotocondensed-bold.ttf',
    ]);
    await family('MaterialIcons', ['materialicons-regular.otf']);
    // Android resolves the generic 'serif' family to Noto Serif on the
    // device. The SDK ships no serif, so tests stand Roboto in for it rather
    // than falling back to the box glyphs.
    await family('serif', ['roboto-regular.ttf', 'roboto-italic.ttf']);
    // Roboto has no ✓ ✕ ■ ▲ ◐. The phone falls back to its system symbol
    // font; the test engine has no fallback, so borrow one from the desktop
    // if it is there. Test-only: never bundled, never shipped.
    final symbols = File(r'C:\Windows\Fonts\seguisym.ttf');
    if (symbols.existsSync()) {
      final loader = FontLoader(
        symbolFallback,
      )..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync())));
      await loader.load();
    }
    _fontsLoaded = true;
  }

  /// A phone-shaped viewport: 412 x 915 logical px, a common Android size.
  static void phone(WidgetTester tester, {double height = 915}) {
    tester.view.physicalSize = Size(412 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  static final GlobalKey _boundary = GlobalKey(debugLabel: 'screenshot');

  /// Wrap the app (usually the MaterialApp) so [capture] has a surface.
  static Widget frame(Widget app) =>
      RepaintBoundary(key: _boundary, child: app);

  /// Writes the current frame to `build/screens/<name>.png`, at the view's
  /// device pixel ratio so text is crisp.
  static Future<File> capture(WidgetTester tester, String name) async {
    final file = File('build/screens/$name.png');
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    return file;
  }

  /// Lets real async work (sqlite, file reads) complete between frames.
  /// `pumpAndSettle` alone never returns while a spinner is animating.
  static Future<void> settle(WidgetTester tester, {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Pumps the WHOLE app — shell, tabs, router — at [location], against an
  /// in-memory database and a seeded programme directory, so a screenshot
  /// shows exactly what the phone would.
  ///
  /// [overrides] come last, so a test can pin `todayProvider` or anything
  /// else. Returns the router so the test can push further.
  static Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required AppDatabase db,
    required ProgrammeRepository repo,
    String location = '/',
    List<Override> overrides = const [],
  }) async {
    // Warm the repository's caches outside the fake-async zone, or the first
    // frames are all spinners.
    await tester.runAsync(() async {
      await repo.ensureSeeded();
      await repo.loadLibrary();
      await repo.loadInventory();
      await repo.loadProgramme();
    });
    final router = buildRouter();
    await tester.pumpWidget(
      frame(
        ProviderScope(
          overrides: [
            programmeRepositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
            ...overrides,
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: themed(AppTheme.dark),
            routerConfig: router,
          ),
        ),
      ),
    );
    await settle(tester);
    if (location != '/') {
      router.go(location);
      await settle(tester);
    }
    return router;
  }

  /// Pins "today" so a tour renders the same screens every run.
  static Override pinToday(DateTime day) =>
      todayProvider.overrideWith(() => _PinnedToday(day));

  /// Fills an empty database with believable history up to [today]:
  /// weigh-ins trending up, and every required session the programme PLANNED
  /// before today completed on its planned date — except one missed Tuesday,
  /// so the screens show a real mix of states.
  ///
  /// Dates come from the programme's own calendar, never fixed offsets: a
  /// session seeded on the wrong weekday draws states the app cannot produce.
  static Future<void> seedHistory(
    AppDatabase db, {
    required ProgrammeRepository repo,
    required DateTime today,
  }) async {
    final programme = await repo.loadProgramme();
    final calendar = ProgrammeCalendar(programme);
    final start = programme.startDate;

    final weighFrom = DateTime(start.year, start.month, start.day - 5);
    var i = 0;
    for (
      var d = weighFrom;
      !d.isAfter(today);
      d = DateTime(d.year, d.month, d.day + 1), i++
    ) {
      // +0.3 kg a week with a little day-to-day water noise.
      final kg = 50.0 + i * 0.043 + ((i * 7) % 5 - 2) * 0.12;
      await db.upsertBodyweight(d, double.parse(kg.toStringAsFixed(1)));
    }

    var missedOne = false;
    for (
      var d = start;
      d.isBefore(today);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final planned = calendar.forDate(d);
      final day = planned.day;
      if (!planned.hasSession || day == null || day.optional) continue;
      if (!missedOne && d.weekday == DateTime.tuesday && planned.weekNo == 2) {
        missedOne = true;
        continue;
      }
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: programme.id,
              blockId: planned.block!.id,
              dayId: day.id,
              weekNo: planned.weekNo!,
              plannedDate: d,
              scheduledDate: d,
              status: const Value(SessionStatus.completed),
            ),
          );
    }
  }
}

class _PinnedToday extends TodayNotifier {
  _PinnedToday(this.day);
  final DateTime day;
  @override
  DateTime build() => DateTime(day.year, day.month, day.day);
}
