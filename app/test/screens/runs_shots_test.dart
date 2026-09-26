import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart' show RepaintBoundary;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/data/run_repository.dart';
import 'package:keller_twelve/data/run_tracker.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/features/runs/run_share_card.dart';

import '../support/screenshot.dart';

/// The run screens, rendered: `build/screens/run_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/runs_shots_test.dart
///
/// No network in a test, so the map draws the trail on plain dark; on the
/// phone the same trail sits on dark OpenStreetMap tiles.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Gps gps;

  // A loop round the Aasee in Münster, near enough: out along the water,
  // over the bridge, back.
  const centre = GeoPoint(51.9555, 7.6075);
  GeoPoint onLoop(double metres) {
    const radiusN = 420.0, radiusE = 700.0;
    final a = metres / 3500 * 2 * math.pi;
    final wobble = 1 + 0.06 * math.sin(a * 5);
    return GeoPoint(
      centre.lat + (radiusN * wobble * math.sin(a)) / 111195.0,
      centre.lng +
          (radiusE * wobble * math.cos(a)) /
              (111195.0 * math.cos(centre.lat * math.pi / 180)),
    );
  }

  /// A believable easy run: a warm-up, a steady middle, a hill, a stop at a
  /// crossing, a quicker last kilometre.
  List<RunFix> believableRun({int seconds = 1500, int startMs = 0}) {
    final out = <RunFix>[];
    var d = 0.0;
    final t0 = (startMs == 0
        ? DateTime(2026, 10, 4, 18, 32).millisecondsSinceEpoch
        : startMs);
    for (var s = 0; s <= seconds; s++) {
      final stopped = s >= 610 && s < 640;
      final hill = s >= 800 && s < 1000;
      final kick = s > 1250;
      final speed = stopped
          ? 0.0
          : s < 180
          ? 2.35
          : hill
          ? 2.2
          : kick
          ? 2.95
          : 2.6;
      d += speed;
      final p = onLoop(d);
      out.add(
        RunFix(
          tMs: t0 + s * 1000,
          lat: p.lat,
          lng: p.lng,
          accuracyM: 4,
          altitudeM: 58 + (hill ? (s - 800) * 0.06 : (s >= 1000 ? 12 : 0)),
        ),
      );
    }
    return out;
  }

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_run_shots_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    gps = _Gps();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  Future<int> seed() async {
    final runs = RunRepository(db, clock: () => DateTime(2026, 10, 4, 18, 32));
    final id = await runs.start(
      link: const RunLink(exerciseId: 'easy-run', prescriptionId: 'f-sun-1'),
    );
    final t = RunTrack();
    var first = true;
    for (final f in believableRun()) {
      t.add(f, segmentStart: first);
      await runs.addPoint(id, f, segmentStart: first);
      first = false;
    }
    await runs.finish(id, t, effort: 4);
    return id;
  }

  List<Override> overrides() => [
    Screenshot.pinToday(DateTime(2026, 10, 5)),
    mapTilesEnabledProvider.overrideWithValue(false),
    locationSourceProvider.overrideWithValue(gps),
  ];

  testWidgets('runs list and one run', skip: !_enabled, (tester) async {
    final id = (await tester.runAsync(seed))!;
    Screenshot.phone(tester, height: 1200);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/progress/runs',
      overrides: overrides(),
    );
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_list');

    router.go('/progress/runs/$id');
    await Screenshot.settle(tester, rounds: 24);
    await tester.pump(const Duration(seconds: 2)); // the route draws in
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_detail');

    await tester.tap(find.byTooltip('Colour the route by pace'));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_detail_pace');

    await tester.tap(find.byTooltip('Replay'));
    await tester.pump(const Duration(seconds: 5));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_replay');
  });

  testWidgets('full screen, and the card it shares', skip: !_enabled, (
    tester,
  ) async {
    final id = (await tester.runAsync(seed))!;
    Screenshot.phone(tester);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/progress/runs',
      overrides: overrides(),
    );
    router.go('/progress/runs/$id');
    await Screenshot.settle(tester, rounds: 24);
    await tester.pump(const Duration(seconds: 2));
    await Screenshot.settle(tester);

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200)); // mid draw-in
    await Screenshot.capture(tester, 'run_fullscreen_drawing');
    await tester.pump(const Duration(seconds: 2));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_fullscreen');
    await tester.tap(find.byTooltip('Colour the route by pace'));
    await tester.tap(find.byTooltip('Replay'));
    await tester.pump(const Duration(seconds: 6));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_fullscreen_replay');
    await tester.tap(find.byTooltip('Stop the replay'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(seconds: 1));
    await Screenshot.settle(tester);

    await tester.tap(find.byTooltip('Share as an image').first);
    await tester.pump(const Duration(seconds: 1));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_share_sheet');

    Future<void> saveCard(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(RunShareCard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      await tester.runAsync(() async {
        final png = await renderShareCard(boundary);
        File('build/screens/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png);
      });
    }

    await saveCard('run_card');
    await tester.tap(find.text('Show the route'));
    await Screenshot.settle(tester);
    await saveCard('run_card_numbers');
  });

  testWidgets('the run, live', skip: !_enabled, (tester) async {
    Screenshot.phone(tester);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: overrides(),
    );
    unawaited(router.push('/track'));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'run_locating');

    final now = DateTime.now().millisecondsSinceEpoch;
    final fixes = believableRun(seconds: 700, startMs: now);
    gps.controller.add(fixes.first);
    await Screenshot.settle(tester);
    await tester.tap(find.text('Start'));
    await Screenshot.settle(tester);
    for (final f in fixes.skip(1)) {
      gps.controller.add(f);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'run_live');
  });
}

class _Gps implements LocationSource {
  final controller = StreamController<RunFix>.broadcast(sync: true);

  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;

  @override
  Future<RunFix?> lastKnown() async => null;

  @override
  Stream<RunFix> watch({bool recording = false}) => controller.stream;

  @override
  Future<void> openSettings() async {}
}
