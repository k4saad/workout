import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/session_service.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late SessionService svc;
  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);

  Day buildDay(String id) => resolver
      .resolveDays(programme.blockById('build')!, 5)
      .firstWhere((d) => d.id == id);

  /// Build-block Tuesday: squat, a dumbbell superset, knee raises.
  Day tuesday() => buildDay('b-tue');

  setUp(() {
    db = AppDatabase.memory();
    svc = SessionService(db);
  });
  tearDown(() => db.close());

  Future<Session> startTuesday({DateTime? on, bool retroactive = false}) =>
      svc.start(
        programmeId: programme.id,
        blockId: 'build',
        day: tuesday(),
        weekNo: 5,
        date: on ?? DateTime(2026, 11, 2),
        retroactive: retroactive,
      );

  group('starting', () {
    test('creates one in-progress session', () async {
      final s = await startTuesday();
      expect(s.status, SessionStatus.inProgress);
      expect(s.dayId, 'b-tue');
      expect(s.weekNo, 5);
      expect(s.startedAt, isNotNull);
    });

    test('starting the same day twice does not fork history', () async {
      final a = await startTuesday();
      final b = await startTuesday();
      expect(b.id, a.id);
      expect(await db.select(db.sessions).get(), hasLength(1));
    });

    test('a retroactive session records that it was reconstructed', () async {
      final s = await startTuesday(retroactive: true);
      expect(s.loggedRetroactively, isTrue);
      expect(
        s.startedAt,
        isNull,
        reason: 'you did not start it then, so do not claim a start time',
      );
    });

    test(
      'reopening a finished day keeps its sets and goes back in progress',
      () async {
        final s = await startTuesday();
        await svc.logSet(
          s.id,
          const SetEntry(
            prescriptionId: 'b-tue-1',
            exerciseId: 'barbell-back-squat',
            setIndex: 1,
            reps: 5,
            loadKg: 21,
          ),
        );
        await svc.finish(s.id);

        final again = await startTuesday();
        expect(again.id, s.id);
        expect(again.status, SessionStatus.inProgress);
        expect(again.finishedAt, isNull);
        expect(await db.setsForSession(s.id), hasLength(1));
      },
    );
  });

  group('logging', () {
    test('a set is persisted immediately, not at finish', () async {
      final s = await startTuesday();
      await svc.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 1,
          reps: 5,
          loadKg: 21,
          rir: 2,
          targetRepsMin: 5,
          targetRepsMax: 5,
          targetLoadKg: 21,
        ),
      );

      // Simulate the app dying here: a fresh read must see the set.
      final rows = await db.setsForSession(s.id);
      expect(rows, hasLength(1));
      expect(rows.single.reps, 5);
      expect(rows.single.rir, 2);
      expect(rows.single.targetLoadKg, 21);
    });

    test('a set is stamped by the service clock, not the wall clock', () async {
      // Replaying a week of training in a test, or logging a session from
      // memory, needs the timestamps the service is told.
      final at = DateTime(2026, 11, 2, 18, 42, 7);
      final clocked = SessionService(db, clock: () => at);
      final s = await clocked.start(
        programmeId: programme.id,
        blockId: 'build',
        day: tuesday(),
        weekNo: 5,
        date: DateTime(2026, 11, 2),
      );
      await clocked.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 1,
          reps: 5,
          loadKg: 21,
        ),
      );
      final row = (await db.setsForSession(s.id)).single;
      expect(row.completedAt, at);
    });

    test('a killed session is resumable', () async {
      final s = await startTuesday();
      await svc.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 1,
          reps: 5,
          loadKg: 21,
        ),
      );

      final resumed = await svc.resumable();
      expect(resumed?.id, s.id);
      expect(await svc.loggedSetCount(s.id, 'b-tue-1'), 1);
    });

    test('ramp sets are logged but do not count as working sets', () async {
      final s = await startTuesday();
      await svc.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 0,
          reps: 8,
          loadKg: 9,
          isWarmup: true,
        ),
      );
      expect(await svc.loggedSetCount(s.id, 'b-tue-1'), 0);
      expect(await db.setsForSession(s.id), hasLength(1));
    });

    test('a mis-tapped set can be corrected', () async {
      final s = await startTuesday();
      final id = await svc.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 1,
          reps: 50,
          loadKg: 21,
        ),
      );
      await svc.updateSet(id, reps: 5);
      final rows = await db.setsForSession(s.id);
      expect(rows.single.reps, 5);
    });
  });

  group('per-side work', () {
    test('a 3 x 8 per-side prescription plans six entries, not three', () {
      final bss = buildDay('b-sat').allPrescriptions
          .firstWhere((p) => p.id == 'b-sat-3a');
      expect(bss.perSide, isTrue);
      final planned = SessionService.plannedSets(bss);
      expect(planned, hasLength(6));
      expect(planned.map((e) => e.side).toSet(), {'L', 'R'});
      expect(planned.where((e) => e.setIndex == 1), hasLength(2));
    });

    test('a bilateral prescription plans one entry per set', () {
      final squat = tuesday().allPrescriptions.firstWhere(
        (p) => p.id == 'b-tue-1',
      );
      expect(squat.perSide, isFalse);
      expect(SessionService.plannedSets(squat), hasLength(3));
      expect(
        SessionService.plannedSets(squat).every((e) => e.side == null),
        isTrue,
      );
    });
  });

  group('input kind', () {
    test('a loaded barbell lift asks for reps and load', () {
      final squat = tuesday().allPrescriptions.firstWhere(
        (p) => p.id == 'b-tue-1',
      );
      expect(SessionService.inputKindFor(squat), SetInputKind.repsAndLoad);
    });

    test('a bodyweight movement asks for reps only', () {
      final raise = tuesday().allPrescriptions.firstWhere(
        (p) => p.id == 'b-tue-3',
      );
      expect(raise.loadMode, LoadMode.bodyweight);
      expect(SessionService.inputKindFor(raise), SetInputKind.reps);
    });

    test('a timed prescription asks for a duration, not 30 reps', () {
      final plank = buildDay('b-sat').allPrescriptions
          .firstWhere((p) => p.exerciseId == 'side-plank');
      expect(plank.unit, RepUnit.sec);
      expect(SessionService.inputKindFor(plank), SetInputKind.duration);
    });

    test('the 5K asks for a distance', () {
      final tt = resolver
          .resolveDays(programme.blockById('test')!, 12)
          .firstWhere((d) => d.id == 't-sun')
          .allPrescriptions
          .first;
      expect(SessionService.inputKindFor(tt), SetInputKind.distance);
    });
  });

  group('finishing', () {
    test('completed vs partial are distinguished', () async {
      final a = await startTuesday(on: DateTime(2026, 11, 2));
      await svc.finish(a.id);
      expect((await db.sessionById(a.id))!.status, SessionStatus.completed);

      final b = await svc.start(
        programmeId: programme.id,
        blockId: 'build',
        day: tuesday(),
        weekNo: 5,
        date: DateTime(2026, 11, 9),
      );
      await svc.finish(b.id, partial: true, wasShortened: true);
      final done = (await db.sessionById(b.id))!;
      expect(done.status, SessionStatus.partial);
      expect(done.wasShortened, isTrue);
    });

    test('progress counts working sets against the plan', () async {
      final day = tuesday();
      final s = await startTuesday();
      final before = await svc.progress(s.id, day);
      expect(before.done, 0);
      // 3 squat + 3 incline press + 3 row + 2 knee raise = 11
      expect(before.planned, 11);

      await svc.logSet(
        s.id,
        const SetEntry(
          prescriptionId: 'b-tue-1',
          exerciseId: 'barbell-back-squat',
          setIndex: 1,
          reps: 5,
          loadKg: 21,
        ),
      );
      expect((await svc.progress(s.id, day)).done, 1);
    });
  });

  group('rescheduling', () {
    test('drawn on the new date, still counted in the old week', () async {
      final s = await startTuesday(on: DateTime(2026, 11, 2));
      await svc.reschedule(s.id, DateTime(2026, 11, 4));
      final moved = (await db.sessionById(s.id))!;
      expect(moved.scheduledDate, DateTime(2026, 11, 4));
      expect(
        moved.plannedDate,
        DateTime(2026, 11, 2),
        reason: 'adherence must still see the week it belonged to',
      );
      expect(moved.weekNo, 5);
    });
  });

  test('a niggle can be recorded mid-session', () async {
    final s = await startTuesday();
    await svc.logNiggle(
      site: NiggleSite.knee,
      severity: 2,
      exerciseId: 'bulgarian-split-squat',
      sessionId: s.id,
      note: 'left knee, only on the way down',
    );
    final rows = await db.select(db.niggles).get();
    expect(rows.single.site, NiggleSite.knee);
    expect(rows.single.sessionId, s.id);
  });
}
