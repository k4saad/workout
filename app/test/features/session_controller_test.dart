import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/session_service.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/session/session_controller.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late SessionController controller;
  late DateTime now;

  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);

  Day monday() => resolver
      .resolveDays(programme.blockById('build')!, 5)
      .firstWhere((d) => d.id == 'b-mon');

  Day tuesday() => resolver
      .resolveDays(programme.blockById('build')!, 5)
      .firstWhere((d) => d.id == 'b-tue');

  setUp(() {
    now = DateTime(2026, 11, 2, 18, 30);
    db = AppDatabase.memory();
    controller = SessionController(
      service: SessionService(db, clock: () => now),
      db: db,
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  Future<RunnerState> startOn(Day day) async {
    final session = await SessionService(db, clock: () => now).start(
      programmeId: programme.id,
      blockId: 'build',
      day: day,
      weekNo: 5,
      date: DateTime(2026, 11, 2),
    );
    return controller.load(session, day);
  }

  group('loading', () {
    test('builds one item per logged prescription', () async {
      final s = await startOn(monday());
      // squat, RDL, BSS, calf, knee raise, pull-up negative
      expect(s.items, hasLength(6));
      expect(s.items.first.prescription.id, 'b-mon-1');
      expect(s.focusIndex, 0);
    });

    test('per-side movements plan two entries per set', () async {
      final s = await startOn(monday());
      final bss = s.items.firstWhere((i) => i.prescription.id == 'b-mon-3a');
      expect(bss.totalCount, 6);
      expect(bss.doneCount, 0);
      expect(bss.nextSet?.side, 'L');
    });

    test('pre-fills the prescribed load when there is no history', () async {
      final s = await startOn(monday());
      expect(s.items.first.suggestedLoadKg, 21.0);
    });
  });

  group('logging a set', () {
    test('records it and starts the rest timer', () async {
      var s = await startOn(monday());
      final squat = s.items.first.prescription;

      s = await controller.logSet(
        s,
        prescription: squat,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        rir: 2,
        exerciseName: 'Barbell back squat',
      );

      expect(s.items.first.doneCount, 1);
      expect(s.isResting, isTrue);
      expect(s.restEndsAt, now.add(const Duration(seconds: 150)));
      expect(s.restLabel, 'Barbell back squat');
      expect(s.restSetNumber, 1);
    });

    test('the set survives a reload — nothing lives only in memory', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Barbell back squat',
      );

      final fresh = await controller.load(s.session, monday());
      expect(fresh.items.first.doneCount, 1);
      expect(fresh.items.first.logged.single.loadKg, 21);
    });

    test(
      'the next set pre-fills from what you actually used, not the plan',
      () async {
        var s = await startOn(monday());
        s = await controller.logSet(
          s,
          prescription: s.items.first.prescription,
          setIndex: 1,
          reps: 5,
          loadKg: 23.5, // heavier than prescribed
          exerciseName: 'Barbell back squat',
        );
        expect(s.items.first.suggestedLoadKg, 23.5);
      },
    );

    test('a ramp set does not consume a working set', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 0,
        reps: 8,
        loadKg: 9,
        isWarmup: true,
        exerciseName: 'Barbell back squat',
      );
      expect(s.items.first.doneCount, 0);
      expect(s.items.first.nextSet?.setIndex, 1);
    });

    test('undo removes the most recent set', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      expect(s.items.first.doneCount, 1);
      s = await controller.undoLast(s);
      expect(s.items.first.doneCount, 0);
    });
  });

  group('supersets and rest', () {
    test('the FIRST member of a superset carries no rest', () async {
      var s = await startOn(monday());
      final first = s.items.firstWhere((i) => i.prescription.id == 'b-mon-3a');
      expect(first.prescription.groupId, isNotNull);
      expect(first.prescription.restSec, 0);

      s = await controller.logSet(
        s,
        prescription: first.prescription,
        setIndex: 1,
        side: 'L',
        reps: 8,
        loadKg: 6,
        exerciseName: 'Bulgarian split squat',
      );
      expect(
        s.isResting,
        isFalse,
        reason: 'you go straight to the other movement, not to a rest',
      );
    });

    test('the LAST member carries the pair rest', () async {
      var s = await startOn(monday());
      final last = s.items.firstWhere((i) => i.prescription.id == 'b-mon-3b');
      s = await controller.logSet(
        s,
        prescription: last.prescription,
        setIndex: 1,
        side: 'R',
        reps: 15,
        exerciseName: 'Single-leg calf raise',
      );
      expect(s.isResting, isTrue);
      expect(s.restEndsAt, now.add(const Duration(seconds: 75)));
    });

    test('a straight set rests on its own prescription', () async {
      var s = await startOn(tuesday());
      final bench = s.items.first;
      expect(bench.prescription.groupId, isNull);
      s = await controller.logSet(
        s,
        prescription: bench.prescription,
        setIndex: 1,
        reps: 6,
        loadKg: 17,
        exerciseName: 'Bench press',
      );
      expect(s.restEndsAt, now.add(const Duration(seconds: 150)));
    });
  });

  group('rest adjustment', () {
    test('+15 s pushes the end out', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      final before = s.restEndsAt!;
      s = controller.adjustRest(s, 15);
      expect(s.restEndsAt, before.add(const Duration(seconds: 15)));
    });

    test('-15 s past the end simply ends the rest', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      now = now.add(const Duration(seconds: 140));
      s = controller.adjustRest(s, -15);
      expect(s.isResting, isFalse);
    });
  });

  group('the sixty-minute budget', () {
    test('does not nag before 45 minutes', () async {
      final s = await startOn(monday());
      expect(s.isRunningLong(now.add(const Duration(minutes: 30))), isFalse);
    });

    test('offers to cut once past 45 minutes with work left', () async {
      final s = await startOn(monday());
      expect(s.isRunningLong(now.add(const Duration(minutes: 50))), isTrue);
    });

    test('short mode drops the optional work, never the main lift', () async {
      var s = await startOn(
        resolver
            .resolveDays(programme.blockById('push')!, 9)
            .firstWhere((d) => d.id == 'b-thu'),
      );
      final before = s.visibleItems.length;
      s = controller.enterShortMode(s);
      // In Push the nordic curl is switched ON, so short mode has nothing
      // optional to drop on this day — the main lift must still be there.
      expect(s.visibleItems.first.prescription.id, 'b-thu-1');
      expect(s.visibleItems.length, lessThanOrEqualTo(before));
    });

    test('short mode hides optional prescriptions in Build', () async {
      var s = await startOn(
        resolver
            .resolveDays(programme.blockById('build')!, 5)
            .firstWhere((d) => d.id == 'b-thu'),
      );
      expect(s.items.any((i) => i.prescription.optional), isTrue);
      final fullCount = s.visibleItems.length;
      s = controller.enterShortMode(s);
      expect(s.visibleItems.length, lessThan(fullCount));
      expect(s.visibleItems.any((i) => i.prescription.optional), isFalse);
    });
  });

  group('finishing', () {
    test('an incomplete session is partial, not completed', () async {
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      await controller.finish(s);
      final row = await db.sessionById(s.session.id);
      expect(row!.status, SessionStatus.partial);
    });

    test('a session with every set logged is completed', () async {
      var s = await startOn(monday());
      for (final item in s.items) {
        for (final planned in item.planned) {
          s = await controller.logSet(
            s,
            prescription: item.prescription,
            setIndex: planned.setIndex,
            side: planned.side,
            reps: item.prescription.repsMax,
            loadKg: item.prescription.startLoadKg,
            exerciseName: item.prescription.exerciseId,
          );
        }
      }
      expect(s.visibleItems.every((i) => i.isComplete), isTrue);
      await controller.finish(s, bodyweightKg: 51.2, rpe: 8);

      final row = await db.sessionById(s.session.id);
      expect(row!.status, SessionStatus.completed);
      expect(row.bodyweightKg, 51.2);
      expect(row.rpeOverall, 8);
    });

    test('progress reaches 1.0 only when everything is logged', () async {
      var s = await startOn(monday());
      expect(s.progress, 0);
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      expect(s.progress, greaterThan(0));
      expect(s.progress, lessThan(1));
    });
  });

  test('a niggle is attached to the session', () async {
    final s = await startOn(monday());
    await controller.logNiggle(
      state: s,
      site: NiggleSite.knee,
      severity: 3,
      exerciseId: 'bulgarian-split-squat',
    );
    final rows = await db.select(db.niggles).get();
    expect(rows.single.sessionId, s.session.id);
    expect(rows.single.severity, 3);
  });
}
