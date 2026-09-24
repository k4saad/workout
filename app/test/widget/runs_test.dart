import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
import 'package:keller_twelve/features/runs/live_run_screen.dart';
import 'package:keller_twelve/features/runs/runs_screen.dart';

/// The run screens, driven by a scripted GPS: what Saad sees before, during
/// and after a run, and what lands in the database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _ScriptedGps gps;

  const origin = GeoPoint(51.9634, 7.6130);
  RunFix fix(int s, double metresNorth, {double accuracy = 5}) => RunFix(
    tMs: DateTime.now().millisecondsSinceEpoch + s * 1000,
    lat: origin.lat + metresNorth / 111195.0,
    lng: origin.lng,
    accuracyM: accuracy,
  );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_runs_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.loadLibrary();
    gps = _ScriptedGps();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  List<Override> overrides() => [
    programmeRepositoryProvider.overrideWithValue(repo),
    databaseProvider.overrideWithValue(db),
    locationSourceProvider.overrideWithValue(gps),
    mapTilesEnabledProvider.overrideWithValue(false),
  ];

  /// Pushes the live screen from a stub page, so the pop result is seen.
  Future<List<bool?>> pumpLive(
    WidgetTester tester, {
    RunLaunch launch = const RunLaunch(),
  }) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final results = <bool?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => results.add(
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LiveRunScreen(launch: launch),
                      ),
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
    return results;
  }

  Future<void> run(WidgetTester tester, int from, int to) async {
    for (var s = from; s <= to; s++) {
      gps.controller.add(fix(s, s * 3.0));
      await settle(tester, rounds: 1);
    }
    await settle(tester);
  }

  Future<void> holdToFinish(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.text('Hold to finish')),
    );
    // The finish fills over 1.2 s; step through it the way a thumb does.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await settle(tester, rounds: 10);
  }

  testWidgets('waits for GPS, then starts, records and finishes', (
    tester,
  ) async {
    final results = await pumpLive(tester);
    expect(find.text('Finding GPS…'), findsOneWidget);

    gps.controller.add(fix(0, 0));
    await settle(tester);
    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('GPS ±5 m'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await settle(tester);
    await run(tester, 1, 120);
    expect(find.text('0.36'), findsOneWidget, reason: '120 s at 3 m/s');
    expect(find.text('Hold to finish'), findsOneWidget);

    // A tap is not a finish.
    await tester.tap(find.text('Hold to finish'));
    await settle(tester);
    expect(find.text('Hold the button to finish'), findsOneWidget);
    expect(find.text('Run saved'), findsNothing);

    await holdToFinish(tester);
    expect(find.text('Run saved'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('HOW HARD WAS IT?'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('HOW HARD WAS IT?'), findsOneWidget);

    final saved = await db.select(db.runs).getSingle();
    expect(saved.status, RunStatus.finished);
    expect(saved.distanceM, closeTo(360, 6));
    expect(gps.listening, isFalse, reason: 'the GPS goes off at the end');

    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
    await settle(tester);
    expect((await db.select(db.runs).getSingle()).effort, 4);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(results, [true]);
  });

  testWidgets('pausing breaks the run, resuming carries on', (tester) async {
    await pumpLive(tester);
    gps.controller.add(fix(0, 0));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await run(tester, 1, 30);

    await tester.tap(find.text('Pause'));
    await settle(tester);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Discard this run'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('back in the middle of a run asks first', (tester) async {
    final results = await pumpLive(tester);
    gps.controller.add(fix(0, 0));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await run(tester, 1, 10);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await settle(tester);
    expect(find.text('Your run is still recording'), findsOneWidget);

    await tester.tap(find.text('Keep running'));
    await settle(tester);
    expect(find.text('Hold to finish'), findsOneWidget);
    expect(results, isEmpty, reason: 'still on the run');
  });

  testWidgets('a refused permission says why and how to fix it', (
    tester,
  ) async {
    gps.access = LocationAccess.deniedForever;
    await pumpLive(tester);
    expect(find.text('Location is off for this app'), findsOneWidget);
    expect(find.text('Allow location'), findsOneWidget);
    expect(find.text('Open app settings'), findsOneWidget);
  });

  testWidgets('a programme run shows its target and logs its set', (
    tester,
  ) async {
    final sid = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'foundation',
            dayId: 'f-sun',
            weekNo: 1,
            plannedDate: DateTime(2026, 10, 4),
            scheduledDate: DateTime(2026, 10, 4),
            status: const Value(SessionStatus.inProgress),
          ),
        );
    await pumpLive(
      tester,
      launch: RunLaunch(
        title: 'Easy run · 15 min',
        exerciseName: 'Easy run',
        link: RunLink(
          sessionId: sid,
          weekNo: 1,
          dayId: 'f-sun',
          prescriptionId: 'f-sun-1',
          exerciseId: 'easy-run',
          target: const RunTarget.duration(900),
          targetRepsMin: 900,
          targetRepsMax: 900,
        ),
      ),
    );
    expect(find.text('EASY RUN · 15 MIN'), findsOneWidget);
    gps.controller.add(fix(0, 0));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await run(tester, 1, 60);
    expect(find.textContaining('to go'), findsOneWidget);

    await holdToFinish(tester);
    expect(find.text('Logged as Easy run'), findsOneWidget);
    final set = (await db.setsForSession(sid)).single;
    expect(set.durationSec, closeTo(60, 3));
    expect(set.distanceM, closeTo(180, 5));
  });

  group('the runs list', () {
    Future<void> pumpList(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(theme: AppTheme.dark, home: child),
        ),
      );
      await settle(tester, rounds: 8);
    }

    Future<int> seedRun() async {
      final runs = RunRepository(db);
      final id = await runs.start();
      final t = RunTrack();
      for (var s = 0; s <= 400; s++) {
        final f = fix(s, s * 3.0);
        t.add(f, segmentStart: s == 0);
        await runs.addPoint(id, f, segmentStart: s == 0);
      }
      await runs.finish(id, t, effort: 5);
      return id;
    }

    testWidgets('empty, it says where runs come from', (tester) async {
      await pumpList(tester, const RunsScreen());
      expect(find.text('No runs yet'), findsOneWidget);
      expect(find.text('Start a free run'), findsOneWidget);
    });

    testWidgets('a run shows its distance, time and pace', (tester) async {
      await tester.runAsync(seedRun);
      await pumpList(tester, const RunsScreen());
      expect(find.text('1.20'), findsWidgets);
      expect(find.textContaining('/km'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its page has the splits and the effort', (tester) async {
      final id = (await tester.runAsync(seedRun))!;
      await pumpList(tester, RunDetailScreen(runId: id));
      expect(find.text('SPLITS'), findsOneWidget);
      expect(find.text('km 1'), findsOneWidget);
      expect(find.text('HOW HARD WAS IT?'), findsOneWidget);
      expect(find.byTooltip('Delete this run'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ScriptedGps implements LocationSource {
  LocationAccess access = LocationAccess.granted;
  final controller = StreamController<RunFix>.broadcast(sync: true);
  int _listeners = 0;

  bool get listening => _listeners > 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<RunFix> watch() {
    late StreamController<RunFix> out;
    StreamSubscription<RunFix>? sub;
    out = StreamController<RunFix>(
      sync: true,
      onListen: () {
        _listeners++;
        sub = controller.stream.listen(out.add);
      },
      onCancel: () async {
        _listeners--;
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> openSettings() async {}
}
