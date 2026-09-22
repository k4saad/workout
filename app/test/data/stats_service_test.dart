import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/stats_service.dart';

import '../support/fixtures.dart';

void main() {
  final programme = Fixtures.programme;

  late AppDatabase db;
  late StatsService stats;

  setUp(() {
    db = AppDatabase.memory();
    stats = StatsService(
      db: db,
      library: Fixtures.library,
      inventory: Fixtures.inventory,
    );
  });

  tearDown(() => db.close());

  Future<int> session({
    int weekNo = 5,
    String dayId = 'b-mon',
    String blockId = 'build',
    DateTime? started,
    DateTime? finished,
    SessionStatus status = SessionStatus.completed,
  }) => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          programmeId: programme.id,
          blockId: blockId,
          dayId: dayId,
          weekNo: weekNo,
          plannedDate: DateTime(2026, 11, 2),
          scheduledDate: DateTime(2026, 11, 2),
          startedAt: Value(started),
          finishedAt: Value(finished),
          status: Value(status),
        ),
      );

  Future<void> logSet(
    int sessionId, {
    required String exerciseId,
    required int setIndex,
    double? kg,
    int? reps,
    bool warmup = false,
    DateTime? at,
  }) => db
      .into(db.setLogs)
      .insert(
        SetLogsCompanion.insert(
          sessionId: sessionId,
          prescriptionId: 'b-mon-1',
          exerciseId: exerciseId,
          setIndex: setIndex,
          completedAt: at ?? DateTime(2026, 11, 2, 19),
        ).copyWith(
          reps: Value(reps),
          loadKg: Value(kg),
          isWarmup: Value(warmup),
        ),
      );

  group('per-lift summary', () {
    test('trend, best set and tonnage come off the logs', () async {
      final s1 = await session();
      await logSet(
        s1,
        exerciseId: 'barbell-back-squat',
        setIndex: 1,
        kg: 21,
        reps: 5,
        at: DateTime(2026, 11, 2, 19),
      );
      await logSet(
        s1,
        exerciseId: 'barbell-back-squat',
        setIndex: 2,
        kg: 21,
        reps: 5,
        at: DateTime(2026, 11, 2, 19, 5),
      );
      final s2 = await session();
      await logSet(
        s2,
        exerciseId: 'barbell-back-squat',
        setIndex: 1,
        kg: 24,
        reps: 5,
        at: DateTime(2026, 11, 9, 19),
      );

      final summary = await stats.summaryFor('barbell-back-squat');
      expect(summary.name, 'Barbell back squat');
      expect(summary.trend, hasLength(2));
      expect(summary.best!.weightKg, 24);
      expect(summary.workingSets, 3);
      expect(summary.tonnageKg, 21 * 5 + 21 * 5 + 24 * 5);
      expect(summary.lastTrainedOn, DateTime(2026, 11, 9, 19));
      expect(summary.changeFraction, closeTo((28 - 24.5) / 24.5, 0.001));
    });

    test('ramp sets never reach the numbers', () async {
      final s = await session();
      await logSet(
        s,
        exerciseId: 'barbell-back-squat',
        setIndex: 0,
        kg: 9,
        reps: 8,
        warmup: true,
      );
      await logSet(
        s,
        exerciseId: 'barbell-back-squat',
        setIndex: 1,
        kg: 21,
        reps: 5,
      );

      final summary = await stats.summaryFor('barbell-back-squat');
      expect(summary.workingSets, 1);
      expect(summary.tonnageKg, 105);
    });

    test('a lift with no load gets no invented estimate', () async {
      final s = await session();
      await logSet(s, exerciseId: 'pull-up-negative', setIndex: 1, reps: 3);

      final summary = await stats.summaryFor('pull-up-negative');
      expect(summary.hasEstimate, isFalse);
      expect(summary.workingSets, 1);
    });

    test('summaries are ordered by estimated max', () async {
      final s = await session();
      await logSet(
        s,
        exerciseId: 'barbell-back-squat',
        setIndex: 1,
        kg: 40,
        reps: 5,
      );
      await logSet(s, exerciseId: 'ez-bar-curl', setIndex: 1, kg: 12, reps: 10);

      final all = await stats.allSummaries();
      expect(all.first.exerciseId, 'barbell-back-squat');
      expect(all, hasLength(2));
    });
  });

  group('weekly volume', () {
    test('counts working sets per muscle for one week', () async {
      final s = await session(weekNo: 5);
      for (var i = 1; i <= 4; i++) {
        await logSet(
          s,
          exerciseId: 'barbell-bench-press',
          setIndex: i,
          kg: 17,
          reps: 6,
        );
      }

      final byExercise = await stats.setsInWeek(5);
      expect(byExercise['barbell-bench-press'], 4);

      final muscles = await stats.weeklyMuscleVolume(5);
      final chest = muscles.firstWhere((m) => m.muscle == 'chest');
      expect(chest.directSets, 4);
      expect(chest.isLow, isTrue, reason: 'four sets is under the floor');
    });

    test('a week with nothing logged is empty, not zeroed nonsense', () async {
      expect(await stats.setsInWeek(11), isEmpty);
      expect(await stats.weeklyMuscleVolume(11), isEmpty);
    });
  });

  group('plate gaps', () {
    test('reports the coarsest lift first', () async {
      final s = await session();
      await logSet(
        s,
        exerciseId: 'barbell-overhead-press',
        setIndex: 1,
        kg: 13,
        reps: 6,
      );
      await logSet(
        s,
        exerciseId: 'barbell-deadlift',
        setIndex: 1,
        kg: 39,
        reps: 5,
      );

      final report = await stats.plateGaps(programme);
      expect(report.gaps, hasLength(2));
      expect(report.gaps.first.exerciseId, 'barbell-overhead-press');
      expect(report.gaps.first.percent, greaterThan(report.gaps.last.percent));
    });

    test('uses the newest logged load, not the first', () async {
      final s = await session();
      await logSet(
        s,
        exerciseId: 'barbell-overhead-press',
        setIndex: 1,
        kg: 13,
        reps: 6,
        at: DateTime(2026, 11, 2, 19),
      );
      await logSet(
        s,
        exerciseId: 'barbell-overhead-press',
        setIndex: 2,
        kg: 15,
        reps: 6,
        at: DateTime(2026, 11, 9, 19),
      );

      final report = await stats.plateGaps(programme);
      expect(report.gaps.single.currentKg, 15);
    });
  });

  group('session duration', () {
    test('measures wall clock against the generated estimate', () async {
      await session(
        started: DateTime(2026, 11, 2, 18, 30),
        finished: DateTime(2026, 11, 2, 19, 32),
      );
      final s = await stats.sessionDurations(programme);
      expect(s.count, 1);
      expect(s.medianMinutes, 62);
      expect(s.durations.single.estimatedMinutes, greaterThan(0));
    });

    test('a retroactively logged session has no honest duration', () async {
      await session(started: null, finished: DateTime(2026, 11, 2, 19, 30));
      final s = await stats.sessionDurations(programme);
      expect(
        s.isEmpty,
        isTrue,
        reason: 'a reconstructed session must not fake a stopwatch reading',
      );
    });

    test('several long sessions call the ceiling fiction', () async {
      for (final minutes in [72, 75, 70, 58]) {
        await session(
          started: DateTime(2026, 11, 2, 18),
          finished: DateTime(2026, 11, 2, 18).add(Duration(minutes: minutes)),
        );
      }
      final s = await stats.sessionDurations(programme);
      expect(s.ceilingIsFiction, isTrue);
      expect(s.verdict, contains('cut volume'));
    });
  });

  group('niggles', () {
    test('newest first, and resolvable', () async {
      await db
          .into(db.niggles)
          .insert(
            NigglesCompanion.insert(
              loggedOn: DateTime(2026, 11, 2),
              site: NiggleSite.knee,
              severity: 3,
            ).copyWith(exerciseId: const Value('bulgarian-split-squat')),
          );
      await db
          .into(db.niggles)
          .insert(
            NigglesCompanion.insert(
              loggedOn: DateTime(2026, 11, 9),
              site: NiggleSite.lowBack,
              severity: 2,
            ),
          );

      final list = await stats.niggles();
      expect(list, hasLength(2));
      expect(list.first.site, NiggleSite.lowBack);
      expect(list.last.exerciseId, 'bulgarian-split-squat');

      await stats.resolveNiggle(list.first.id, DateTime(2026, 11, 12));
      final after = await stats.niggles();
      expect(after.first.resolvedOn, DateTime(2026, 11, 12));
    });
  });
}
