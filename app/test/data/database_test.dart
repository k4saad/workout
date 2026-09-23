import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> makeSession({
    String dayId = 'b-mon',
    int week = 5,
    DateTime? date,
    SessionStatus status = SessionStatus.inProgress,
  }) {
    final d = date ?? DateTime(2026, 11, 2);
    return db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'build',
            dayId: dayId,
            weekNo: week,
            plannedDate: d,
            scheduledDate: d,
            status: Value(status),
            startedAt: Value(DateTime(2026, 11, 2, 18, 30)),
          ),
        );
  }

  Future<void> logSet(
    int sessionId, {
    String prescriptionId = 'b-mon-1',
    String exerciseId = 'barbell-back-squat',
    required int setIndex,
    required int reps,
    double? loadKg,
    int? rir,
    bool isWarmup = false,
    DateTime? at,
  }) => db
      .into(db.setLogs)
      .insert(
        SetLogsCompanion.insert(
          sessionId: sessionId,
          prescriptionId: prescriptionId,
          exerciseId: exerciseId,
          setIndex: setIndex,
          reps: Value(reps),
          loadKg: Value(loadKg),
          rir: Value(rir),
          isWarmup: Value(isWarmup),
          completedAt: at ?? DateTime(2026, 11, 2, 18, 40 + setIndex),
        ),
      );

  test('opens an in-memory database and creates every table', () async {
    // 7 training tables + 5 progress tables (schema v2).
    expect(db.allTables, hasLength(18));
    for (final t in db.allTables) {
      await db.select(t).get(); // must not throw
    }
  });

  test('a session round-trips', () async {
    final id = await makeSession();
    final s = await db.sessionById(id);
    expect(s, isNotNull);
    expect(s!.dayId, 'b-mon');
    expect(s.status, SessionStatus.inProgress);
    expect(s.loggedRetroactively, isFalse);
  });

  test('inProgressSession finds a killed session so it can resume', () async {
    await makeSession(status: SessionStatus.completed);
    final live = await makeSession(status: SessionStatus.inProgress);
    final found = await db.inProgressSession();
    expect(found?.id, live);
  });

  test('sets cascade-delete with their session', () async {
    final id = await makeSession();
    await logSet(id, setIndex: 1, reps: 5, loadKg: 21);
    expect(await db.setsForSession(id), hasLength(1));

    await (db.delete(db.sessions)..where((s) => s.id.equals(id))).go();
    final orphans = await db.select(db.setLogs).get();
    expect(orphans, isEmpty, reason: 'foreign key cascade did not fire');
  });

  group('history lookup precedence', () {
    test(
      'lastSetsForPrescription returns that session\'s working sets',
      () async {
        final s1 = await makeSession(date: DateTime(2026, 10, 26));
        await logSet(
          s1,
          setIndex: 1,
          reps: 5,
          loadKg: 19,
          at: DateTime(2026, 10, 26, 18, 40),
        );
        final s2 = await makeSession(date: DateTime(2026, 11, 2));
        await logSet(
          s2,
          setIndex: 1,
          reps: 5,
          loadKg: 21,
          at: DateTime(2026, 11, 2, 18, 40),
        );
        await logSet(
          s2,
          setIndex: 2,
          reps: 5,
          loadKg: 21,
          at: DateTime(2026, 11, 2, 18, 44),
        );

        final sets = await db.lastSetsForPrescription(
          'b-mon-1',
          'barbell-back-squat',
        );
        expect(sets, hasLength(2));
        expect(
          sets.every((s) => s.loadKg == 21),
          isTrue,
          reason: 'must return the most recent session only',
        );
      },
    );

    test('ramp sets are excluded from history', () async {
      final id = await makeSession();
      await logSet(id, setIndex: 0, reps: 8, loadKg: 9, isWarmup: true);
      await logSet(id, setIndex: 1, reps: 5, loadKg: 21);

      final sets = await db.lastSetsForPrescription(
        'b-mon-1',
        'barbell-back-squat',
      );
      expect(sets, hasLength(1));
      expect(sets.single.loadKg, 21);
    });

    test('two prescriptions of the same exercise do not contaminate '
        'each other', () async {
      // The real case: single-leg calf raise is 3x15 on Monday and 3x20 on
      // Thursday. Keying history on exerciseId alone would have Monday's
      // 15-rep sets drive Thursday's 20-rep target.
      final mon = await makeSession(dayId: 'b-mon');
      await logSet(
        mon,
        prescriptionId: 'b-mon-3b',
        exerciseId: 'single-leg-calf-raise',
        setIndex: 1,
        reps: 15,
        at: DateTime(2026, 11, 2, 19),
      );
      final thu = await makeSession(dayId: 'b-thu');
      await logSet(
        thu,
        prescriptionId: 'b-thu-3b',
        exerciseId: 'single-leg-calf-raise',
        setIndex: 1,
        reps: 20,
        at: DateTime(2026, 11, 5, 19),
      );

      final monHistory = await db.lastSetsForPrescription(
        'b-mon-3b',
        'single-leg-calf-raise',
      );
      final thuHistory = await db.lastSetsForPrescription(
        'b-thu-3b',
        'single-leg-calf-raise',
      );
      expect(monHistory.single.reps, 15);
      expect(thuHistory.single.reps, 20);

      // The by-exercise fallback sees only the newest, which is exactly why
      // it is the FALLBACK and not the primary lookup.
      final byExercise = await db.lastSetsForExercise('single-leg-calf-raise');
      expect(byExercise.single.reps, 20);
    });

    test('lastSetsForExercise is the fallback after a swap', () async {
      final id = await makeSession();
      await logSet(
        id,
        prescriptionId: 'b-mon-3a',
        exerciseId: 'reverse-lunge',
        setIndex: 1,
        reps: 8,
        loadKg: 6,
      );

      // A brand-new prescription id has no history of its own...
      expect(
        await db.lastSetsForPrescription('b-mon-3a-v2', 'reverse-lunge'),
        isEmpty,
      );
      // ...but the exercise does.
      final byExercise = await db.lastSetsForExercise('reverse-lunge');
      expect(byExercise, hasLength(1));
      expect(byExercise.single.loadKg, 6);
    });
  });

  group('stall counters', () {
    test('upsert by (exercise, prescription)', () async {
      await db.setStall('barbell-bench-press', 'b-tue-1', 1);
      expect((await db.stallFor('barbell-bench-press', 'b-tue-1'))?.count, 1);

      await db.setStall('barbell-bench-press', 'b-tue-1', 2);
      expect((await db.stallFor('barbell-bench-press', 'b-tue-1'))?.count, 2);

      // A different prescription of the same lift stalls independently.
      expect(await db.stallFor('barbell-bench-press', 't-tue-1'), isNull);
    });
  });

  group('bodyweight', () {
    test('one entry per day, re-entering replaces', () async {
      await db.upsertBodyweight(DateTime(2026, 9, 28), 50.0);
      await db.upsertBodyweight(DateTime(2026, 9, 28), 50.4);
      final all = await db.bodyweightHistory();
      expect(all, hasLength(1));
      expect(all.single.kg, 50.4);
    });

    test('bodyweightNear finds the closest entry within the window', () async {
      await db.upsertBodyweight(DateTime(2026, 9, 27), 50.1);
      await db.upsertBodyweight(DateTime(2026, 9, 30), 50.6);

      final near = await db.bodyweightNear(DateTime(2026, 9, 28));
      expect(near?.kg, 50.1);

      final far = await db.bodyweightNear(DateTime(2026, 10, 20));
      expect(far, isNull, reason: 'outside the +/-2 day window');
    });
  });

  test('niggles record what hurt, where, and how much', () async {
    await db
        .into(db.niggles)
        .insert(
          NigglesCompanion.insert(
            loggedOn: DateTime(2026, 11, 2),
            site: NiggleSite.knee,
            severity: 2,
            exerciseId: const Value('bulgarian-split-squat'),
            note: const Value('front knee, only on the left'),
          ),
        );
    final rows = await db.select(db.niggles).get();
    expect(rows.single.site, NiggleSite.knee);
    expect(rows.single.resolvedOn, isNull);
  });

  test('wipe clears every table, for restore', () async {
    final id = await makeSession();
    await logSet(id, setIndex: 1, reps: 5, loadKg: 21);
    await db.upsertBodyweight(DateTime(2026, 9, 28), 50.0);

    await db.wipe();

    for (final t in db.allTables) {
      expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
    }
  });
}
