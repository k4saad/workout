import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show Scrollable, ScrollableState;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/data/run_repository.dart';
import 'package:keller_twelve/data/run_tracker.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/features/runs/hike_summary.dart';
import 'package:keller_twelve/features/runs/live_run_screen.dart';
import 'package:keller_twelve/features/runs/terrain_view.dart';

import '../support/fake_terrain.dart';
import '../support/screenshot.dart';

/// The hike screens, rendered: `build/screens/hike_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/hikes_shots_test.dart
///
/// No network in a test: the terrain is a made-up hill drawn from the same
/// formula as the walk's heights, and the map draws the trail on plain dark.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Gps gps;
  late FakeTerrain terrain;

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_hike_shots_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    gps = _Gps();
    terrain = FakeTerrain();
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
    final hikes = RunRepository(db, clock: () => DateTime(2026, 10, 18, 9, 30));
    final id = await hikes.start(kind: RunKind.hike);
    final t = RunTrack.hike();
    var first = true;
    for (final f in believableHike(everySec: 2)) {
      t.add(f, segmentStart: first);
      await hikes.addPoint(id, f, segmentStart: first);
      first = false;
    }
    await hikes.finish(id, t, effort: 6);
    return id;
  }

  List<Override> overrides() => [
    Screenshot.pinToday(DateTime(2026, 10, 19)),
    mapTilesEnabledProvider.overrideWithValue(false),
    locationSourceProvider.overrideWithValue(gps),
    terrainSourceProvider.overrideWithValue(terrain),
  ];

  testWidgets('hikes list, one hike, full screen', skip: !_enabled, (
    tester,
  ) async {
    final id = (await tester.runAsync(seed))!;
    Screenshot.phone(tester, height: 1200);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/progress',
      overrides: overrides(),
    );
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_hub');

    router.go('/progress/hikes');
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_list');

    router.go('/progress/hikes/$id');
    await Screenshot.settle(tester, rounds: 30);
    await tester.pump(const Duration(milliseconds: 1500)); // mid draw-in
    await Screenshot.capture(tester, 'hike_detail_drawing');
    await tester.pump(const Duration(seconds: 3));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_detail');

    final list = find
        .descendant(
          of: find.byType(HikeSummaryView),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(420);
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_detail_numbers');
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await Screenshot.settle(tester);

    Screenshot.phone(tester);
    await Screenshot.settle(tester);
    await tester.tap(find.byTooltip('Full screen 3D'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_3d');

    // Turned round to the east and tilted down towards the horizon.
    final model = find.byType(TerrainView).last;
    await tester.drag(model, const Offset(-260, 0));
    await Screenshot.settle(tester);
    await tester.drag(model, const Offset(0, -160));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_3d_turned');
  });

  testWidgets('offline: the trail on its own heights', skip: !_enabled, (
    tester,
  ) async {
    terrain.online = false;
    final id = (await tester.runAsync(seed))!;
    Screenshot.phone(tester, height: 1200);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/progress/hikes',
      overrides: overrides(),
    );
    router.go('/progress/hikes/$id');
    await Screenshot.settle(tester, rounds: 30);
    await tester.pump(const Duration(seconds: 5));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'hike_detail_offline');
  });

  testWidgets('the hike, live', skip: !_enabled, (tester) async {
    Screenshot.phone(tester);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: overrides(),
    );
    unawaited(router.push('/track', extra: const RunLaunch.hike()));
    await Screenshot.settle(tester);
    final fixes = believableHike(
      everySec: 2,
      startMs: DateTime.now().millisecondsSinceEpoch,
    );
    gps.controller.add(fixes.first);
    await Screenshot.settle(tester);
    await tester.tap(find.text('Start'));
    await Screenshot.settle(tester);
    for (final f in fixes.skip(1).take(700)) {
      gps.controller.add(f);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'hike_live');
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
