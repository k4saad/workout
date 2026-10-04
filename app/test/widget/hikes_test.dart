import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/data/run_repository.dart';
import 'package:keller_twelve/data/run_tracker.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/features/runs/hikes_screen.dart';
import 'package:keller_twelve/features/runs/live_run_screen.dart';
import 'package:keller_twelve/features/runs/runs_screen.dart';
import 'package:keller_twelve/features/runs/terrain_view.dart';

import '../support/fake_terrain.dart';

/// Hikes: recorded like runs, counted by the climb, and drawn afterwards in
/// 3D on the hills they crossed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Gps gps;
  late FakeTerrain terrain;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_hikes_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.loadLibrary();
    gps = _Gps();
    terrain = FakeTerrain();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  List<Override> overrides() => [
    programmeRepositoryProvider.overrideWithValue(repo),
    databaseProvider.overrideWithValue(db),
    locationSourceProvider.overrideWithValue(gps),
    mapTilesEnabledProvider.overrideWithValue(false),
    terrainSourceProvider.overrideWithValue(terrain),
  ];

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(theme: AppTheme.dark, home: child),
      ),
    );
    await settle(tester);
  }

  Future<int> seedHike() async {
    final runs = RunRepository(db, clock: () => DateTime(2026, 10, 18, 9, 30));
    final id = await runs.start(kind: RunKind.hike);
    final t = RunTrack.hike();
    var first = true;
    for (final f in believableHike(everySec: 6)) {
      t.add(f, segmentStart: first);
      await runs.addPoint(id, f, segmentStart: first);
      first = false;
    }
    await runs.finish(id, t, effort: 4);
    return id;
  }

  testWidgets('empty, it says where hikes come from', (tester) async {
    await pump(tester, const HikesScreen());
    expect(find.text('No hikes yet'), findsOneWidget);
    expect(find.text('Start a hike'), findsOneWidget);
  });

  testWidgets('a hike is listed by its distance and climb, apart from runs', (
    tester,
  ) async {
    await tester.runAsync(seedHike);
    await pump(tester, const HikesScreen());
    expect(find.text('Morning hike'), findsOneWidget);
    expect(find.text('▲ CLIMB'), findsOneWidget);
    expect(find.textContaining('m climbed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(tester, const RunsScreen());
    expect(find.text('No runs yet'), findsOneWidget, reason: 'not a run');
  });

  testWidgets('its page stands the trail on the hills it crossed', (
    tester,
  ) async {
    final id = (await tester.runAsync(seedHike))!;
    await pump(tester, RunDetailScreen(runId: id));
    await settle(tester, rounds: 12);

    expect(find.byType(TerrainView), findsOneWidget);
    expect(find.text('3D terrain'), findsOneWidget);
    expect(find.textContaining('AWS Open Data'), findsOneWidget);
    expect(find.text('▲ ASCENT'), findsOneWidget);
    expect(find.text('▼ DESCENT'), findsOneWidget);
    expect(find.text('HIGHEST POINT'), findsOneWidget);
    expect(
      find.textContaining('from the terrain under the trail'),
      findsOneWidget,
    );
    expect(find.text('ELEVATION'), findsOneWidget);
    expect(find.text('ON THE MAP'), findsOneWidget);
    expect(find.byTooltip('Delete this hike'), findsOneWidget);
    expect(find.text('SPLITS'), findsNothing, reason: 'a hike is not paced');
    expect(terrain.requests, inInclusiveRange(1, 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline, it says so and stands on the GPS heights', (
    tester,
  ) async {
    terrain.online = false;
    final id = (await tester.runAsync(seedHike))!;
    await pump(tester, RunDetailScreen(runId: id));
    await settle(tester, rounds: 12);

    expect(find.byType(TerrainView), findsOneWidget);
    expect(find.text('GPS heights · offline'), findsOneWidget);
    expect(find.textContaining('AWS Open Data'), findsNothing);
    expect(find.textContaining('phone\'s GPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it turns under a finger, and opens full screen', (tester) async {
    final id = (await tester.runAsync(seedHike))!;
    await pump(tester, RunDetailScreen(runId: id));
    await settle(tester, rounds: 12);

    await tester.drag(find.byType(TerrainView), const Offset(-120, 0));
    await settle(tester, rounds: 2);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Full screen 3D'));
    await settle(tester, rounds: 12);
    expect(find.byType(TerrainView), findsNWidgets(2));
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.textContaining('▲'), findsWidgets);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester, rounds: 12);
    expect(find.byType(TerrainView), findsOneWidget);
  });

  testWidgets('the tracker records a hike: climb and height, not pace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LiveRunScreen(launch: RunLaunch.hike()),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('HIKE'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await settle(tester);
    final walk = believableHike(
      everySec: 2,
      startMs: DateTime.now().millisecondsSinceEpoch,
    );
    // Twenty minutes in: well onto the climb.
    for (final f in walk.take(600)) {
      gps.controller.add(f);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await settle(tester);
    expect(find.text('▲ CLIMB'), findsOneWidget);
    expect(find.text('HEIGHT'), findsOneWidget);
    expect(find.text('PACE'), findsNothing);
    expect(find.textContaining('talk in sentences'), findsNothing);

    final g = await tester.startGesture(
      tester.getCenter(find.text('Hold to finish')),
    );
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await settle(tester, rounds: 14);
    expect(find.text('Hike saved'), findsOneWidget);

    final row = (await tester.runAsync(() => db.select(db.runs).getSingle()))!;
    expect(row.kind, RunKind.hike);
    expect(row.elevGainM, greaterThan(10));
    expect(row.maxAltM, isNotNull);
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
