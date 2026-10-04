import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/stats/lift_detail_screen.dart';
import 'package:keller_twelve/features/stats/stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_stats_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadProgramme();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer. Not worth a failure.
    }
  });

  Widget harness(Widget child) => ProviderScope(
    overrides: [
      programmeRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(child));
    await settle(tester);
    await settle(tester);
  }

  Future<int> session({
    int weekNo = 1,
    DateTime? started,
    DateTime? finished,
  }) => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          programmeId: 'keller-twelve',
          blockId: 'foundation',
          dayId: 'f-tue',
          weekNo: weekNo,
          plannedDate: DateTime(2026, 9, 28),
          scheduledDate: DateTime(2026, 9, 28),
          startedAt: Value(started),
          finishedAt: Value(finished),
          status: const Value(SessionStatus.completed),
        ),
      );

  Future<void> logSet(
    int sessionId, {
    required String exerciseId,
    required int setIndex,
    double? kg,
    int? reps,
    DateTime? at,
  }) => db
      .into(db.setLogs)
      .insert(
        SetLogsCompanion.insert(
          sessionId: sessionId,
          prescriptionId: 'f-tue-1',
          exerciseId: exerciseId,
          setIndex: setIndex,
          completedAt: at ?? DateTime(2026, 9, 28, 19),
        ).copyWith(reps: Value(reps), loadKg: Value(kg)),
      );

  testWidgets('an empty log draws without throwing', (tester) async {
    await pump(tester, const StatsScreen());
    expect(find.text('Numbers'), findsOneWidget);
    expect(find.textContaining('Nothing logged this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly sets per muscle are counted and flagged', (tester) async {
    final s = await session(weekNo: 1);
    for (var i = 1; i <= 4; i++) {
      await logSet(
        s,
        exerciseId: 'barbell-bench-press',
        setIndex: i,
        kg: 17,
        reps: 6,
      );
    }

    await pump(tester, const StatsScreen());

    expect(find.text('chest'), findsOneWidget);
    // Four sets is under the eight-set floor, so it carries the low glyph.
    expect(find.text('↓'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lift opens to its trend and every set', (tester) async {
    final s1 = await session(weekNo: 1);
    await logSet(
      s1,
      exerciseId: 'barbell-back-squat',
      setIndex: 1,
      kg: 21,
      reps: 5,
      at: DateTime(2026, 9, 28, 19),
    );
    final s2 = await session(weekNo: 2);
    await logSet(
      s2,
      exerciseId: 'barbell-back-squat',
      setIndex: 1,
      kg: 24,
      reps: 5,
      at: DateTime(2026, 10, 5, 19),
    );

    await pump(
      tester,
      const LiftDetailScreen(exerciseId: 'barbell-back-squat'),
    );

    expect(find.text('24 x 5'), findsOneWidget);
    // The estimate must be labelled as one, everywhere it appears.
    expect(find.textContaining('estimated'), findsWidgets);
    expect(find.textContaining('ESTIMATE'), findsOneWidget);
    expect(find.text('Every set'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lift with no load gets no invented maximum', (tester) async {
    final s = await session();
    await logSet(s, exerciseId: 'pull-up-negative', setIndex: 1, reps: 3);

    await pump(tester, const LiftDetailScreen(exerciseId: 'pull-up-negative'));

    expect(find.textContaining('no weight to estimate from'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a niggle appears on the timeline and can be cleared', (
    tester,
  ) async {
    await db
        .into(db.niggles)
        .insert(
          NigglesCompanion.insert(
            loggedOn: DateTime(2026, 10, 5),
            site: NiggleSite.knee,
            severity: 3,
          ).copyWith(exerciseId: const Value('bulgarian-split-squat')),
        );

    await pump(tester, const StatsScreen());

    expect(find.textContaining('knee · severity 3/5'), findsOneWidget);
    expect(find.textContaining('Bulgarian split squat'), findsOneWidget);

    await tester.ensureVisible(find.text('Cleared'));
    await tester.pump();
    await tester.tap(find.text('Cleared'));
    await settle(tester);
    await settle(tester);

    final rows = await db.select(db.niggles).get();
    expect(rows.single.resolvedOn, isNotNull);
  });

  testWidgets('the hour is reported against what actually happened', (
    tester,
  ) async {
    for (final minutes in [72, 75, 70, 58]) {
      await session(
        started: DateTime(2026, 9, 28, 18),
        finished: DateTime(2026, 9, 28, 18).add(Duration(minutes: minutes)),
      );
    }

    await pump(tester, const StatsScreen());

    expect(find.text('The hour'), findsOneWidget);
    expect(find.textContaining('cut volume'), findsOneWidget);
  });

  testWidgets('plate gaps name the lift and the plate to buy', (tester) async {
    final s = await session();
    await logSet(
      s,
      exerciseId: 'barbell-overhead-press',
      setIndex: 1,
      kg: 13,
      reps: 6,
    );

    await pump(tester, const StatsScreen());

    expect(find.text('Plate gaps'), findsOneWidget);
    expect(find.text('Standing barbell overhead press'), findsWidgets);
    expect(find.text('4%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
