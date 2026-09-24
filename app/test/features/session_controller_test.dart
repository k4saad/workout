import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/session_service.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/domain/progression/progression_engine.dart';
import 'package:keller_twelve/features/session/session_controller.dart';

import '../support/fixtures.dart';

LoadSuggestion suggestion({
  double? kg,
  required int min,
  required int max,
  bool creep = false,
  int stall = 0,
}) => LoadSuggestion(
  suggestedKg: kg,
  repTargetMin: min,
  repTargetMax: max,
  reason: 'test',
  isRepCreep: creep,
  isStalled: stall > 0,
  newStallCount: stall,
);

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
      // squat, RDL, BSS, calf, knee raise, pull-up negative, lateral raise
      expect(s.items, hasLength(7));
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

    test(
      'pre-fills the SUGGESTION, not the programme start (item 5)',
      () async {
        // v2 put startLoadKg on the stepper every week, so Saad saw 21 kg on
        // the squat in week 7 whatever the engine said.
        final day = monday();
        final session = await SessionService(db, clock: () => now).start(
          programmeId: programme.id,
          blockId: 'build',
          day: day,
          weekNo: 5,
          date: DateTime(2026, 11, 2),
        );
        final s = await controller.load(
          session,
          day,
          suggestions: {'b-mon-1': suggestion(kg: 25, min: 5, max: 5)},
        );
        expect(s.items.first.suggestion?.suggestedKg, 25);
        expect(s.items.first.suggestedLoadKg, 25);
        expect(
          s.items[1].suggestedLoadKg,
          s.items[1].prescription.startLoadKg,
          reason: 'no suggestion: the programme start',
        );
      },
    );
  });

  group('what gets logged as the target (item 3, rep creep)', () {
    Future<RunnerState> withSuggestions(
      Map<String, LoadSuggestion> suggestions,
    ) async {
      final day = monday();
      final session = await SessionService(db, clock: () => now).start(
        programmeId: programme.id,
        blockId: 'build',
        day: day,
        weekNo: 5,
        date: DateTime(2026, 11, 2),
      );
      return controller.load(session, day, suggestions: suggestions);
    }

    test('the suggestion\'s crept rep target and load are stored', () async {
      // The lateral raise at 2 kg crept to 17. v2 logged the prescription's
      // 12-15, so next week crept to 17 again, forever (the v1 A1 deadlock).
      var s = await withSuggestions({
        'b-mon-4c': suggestion(kg: 2, min: 12, max: 17, creep: true),
      });
      final lateral = s.items.firstWhere(
        (i) => i.prescription.id == 'b-mon-4c',
      );
      s = await controller.logSet(
        s,
        prescription: lateral.prescription,
        setIndex: 1,
        reps: 17,
        loadKg: 2,
        rir: 1,
        exerciseName: 'Lateral raise',
      );
      final row = (await db.setsForSession(s.session.id))
          .firstWhere((l) => l.prescriptionId == 'b-mon-4c');
      expect(row.targetRepsMin, 12);
      expect(row.targetRepsMax, 17);
      expect(row.targetLoadKg, 2);
      expect(
        s.suggestions['b-mon-4c'],
        isNotNull,
        reason: 'suggestions survive the reload after a set',
      );
    });

    test('with no suggestion the prescription is the target', () async {
      var s = await withSuggestions(const {});
      final squat = s.items.first.prescription;
      s = await controller.logSet(
        s,
        prescription: squat,
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      final row = (await db.setsForSession(s.session.id)).single;
      expect(row.targetRepsMin, squat.repsMin);
      expect(row.targetRepsMax, squat.repsMax);
      expect(row.targetLoadKg, squat.startLoadKg);
    });

    test('finishing records each trained movement\'s stall count', () async {
      var s = await withSuggestions({
        'b-mon-1': suggestion(kg: 21, min: 5, max: 5, stall: 1),
        'b-mon-2': suggestion(kg: 27, min: 8, max: 8, stall: 1),
      });
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription,
        setIndex: 1,
        reps: 4,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      await controller.finish(s);
      expect((await db.stallFor('barbell-back-squat', 'b-mon-1'))?.count, 1);
      expect(
        await db.stallFor('barbell-romanian-deadlift', 'b-mon-2'),
        isNull,
        reason: 'not trained today, so nothing to record',
      );
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

    test('undo removes the most recent set even in the same second', () async {
      // Drift stores seconds. Two sets logged inside one second tie, and the
      // tie must go to the one logged last, not the one sorted last.
      var s = await startOn(monday());
      s = await controller.logSet(
        s,
        prescription: s.items[1].prescription, // b-mon-2 first
        setIndex: 1,
        reps: 8,
        loadKg: 27,
        exerciseName: 'RDL',
      );
      s = await controller.logSet(
        s,
        prescription: s.items.first.prescription, // then b-mon-1
        setIndex: 1,
        reps: 5,
        loadKg: 21,
        exerciseName: 'Squat',
      );
      s = await controller.undoLast(s);
      expect(s.items.first.doneCount, 0, reason: 'the squat went last');
      expect(s.items[1].doneCount, 1);
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

    // Programme rule 7: "If you are over, cut the last superset — not the
    // main lift, not the warm-up." v3 has no optional prescriptions left, so
    // v2's "drop the optional work" dropped nothing.
    test('short mode cuts the last superset of the day', () async {
      var s = await startOn(monday());
      final lastGroup = s.items.last.prescription.groupId;
      expect(lastGroup, isNotNull);
      final members = s.items
          .where((i) => i.prescription.groupId == lastGroup)
          .map((i) => i.prescription.id)
          .toSet();
      expect(members, {'b-mon-4a', 'b-mon-4b', 'b-mon-4c'});

      s = controller.enterShortMode(s);
      final visible = s.visibleItems.map((i) => i.prescription.id).toList();
      expect(visible, ['b-mon-1', 'b-mon-2', 'b-mon-3a', 'b-mon-3b']);
      expect(s.shortModeCut.map((i) => i.prescription.id).toSet(), members);
      expect(
        s.plannedSets,
        s.visibleItems.fold<int>(0, (a, i) => a + i.totalCount),
      );
    });

    test('never the main lift, and only the LAST superset', () async {
      for (final id in ['b-mon', 'b-tue', 'b-thu', 'b-fri']) {
        final day = resolver
            .resolveDays(programme.blockById('push')!, 9)
            .firstWhere((d) => d.id == id);
        var s = await startOn(day);
        final groups = [
          for (final i in s.items)
            if (i.prescription.groupId != null) i.prescription.groupId,
        ];
        s = controller.enterShortMode(s);
        expect(s.visibleItems.first.prescription.id, '$id-1', reason: id);
        final cutGroups = s.shortModeCut
            .map((i) => i.prescription.groupId)
            .toSet();
        expect(cutGroups, {groups.last}, reason: id);
      }
    });

    test('a day without a superset has nothing to cut, so no nag', () async {
      // The deload unwinds every superset into straight sets.
      final day = resolver
          .resolveDays(programme.blockById('deload')!, 8)
          .firstWhere((d) => d.id == 'b-mon');
      var s = await startOn(day);
      expect(s.isRunningLong(now.add(const Duration(minutes: 50))), isFalse);
      final before = s.visibleItems.length;
      s = controller.enterShortMode(s);
      expect(s.shortModeCut, isEmpty);
      expect(s.visibleItems, hasLength(before));
    });

    test('a finished superset is not cut: there is nothing to save', () async {
      var s = await startOn(monday());
      for (final item in s.items.where(
        (i) => i.prescription.groupId == 'b-mon-ss2',
      )) {
        for (final planned in item.planned) {
          s = await controller.logSet(
            s,
            prescription: item.prescription,
            setIndex: planned.setIndex,
            side: planned.side,
            reps: item.prescription.repsMax,
            exerciseName: item.prescription.exerciseId,
          );
        }
      }
      s = controller.enterShortMode(s);
      expect(s.shortModeCut, isEmpty);
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
