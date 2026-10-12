import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/session_service.dart';
import 'package:keller_twelve/data/suggestion_service.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/session/session_controller.dart';

import '../support/fixtures.dart';

/// The guard that the v1 deadlock never comes back.
///
/// Twelve weeks of the SHIPPED programme on the SHIPPED kit, through the real
/// path a set takes on the phone: the resolver, `SuggestionService` (history
/// precedence, deload exclusion), the engine, the runner's pre-fill and what
/// it logs as the target, the database. The athlete is perfect: every set at
/// the top of the suggested range, at exactly the target RIR, every session.
///
/// If a perfect athlete cannot reach the coach's floors, the programme is
/// lying to a real one. v2 could not: its 10% jump cap froze every barbell
/// lift near 17 kg, its week 9 progressed from the 70% deload week, and its
/// light dumbbell work crept to the same rep target forever.
void main() {
  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);

  /// exerciseId -> week -> working load (first working set of the week).
  final load = <String, Map<int, double>>{};

  /// prescriptionId -> every exposure outside deload and test weeks, in order.
  final exposures = <String, List<({int week, double kg, int reps})>>{};

  /// prescriptionId -> week -> target the runner logged (seconds for runs).
  final target = <String, Map<int, int>>{};

  final ran = <int, Set<String>>{}; // week -> day ids trained

  late AppDatabase db;

  setUpAll(() async {
    db = AppDatabase.memory();
    var clock = programme.anchorMonday;
    final sessions = SessionService(db, clock: () => clock);
    final controller = SessionController(
      service: sessions,
      db: db,
      clock: () => clock,
    );
    final suggestions = SuggestionService(
      db: db,
      inventory: Fixtures.inventory,
      programme: programme,
    );

    for (var week = 1; week <= programme.totalWeeks; week++) {
      final block = programme.blockForWeek(week)!;
      final counts = !block.isDeload && !block.isTest;
      for (final day in resolver.resolveDays(block, week)) {
        if (!day.isTrainingDay || day.loggedPrescriptions.isEmpty) continue;
        (ran[week] ??= {}).add(day.id);
        final date = programme.anchorMonday.add(
          Duration(days: 7 * (week - 1) + day.weekday.isoDay - 1),
        );
        clock = date.add(const Duration(hours: 18));

        final session = await sessions.start(
          programmeId: programme.id,
          blockId: block.id,
          day: day,
          weekNo: week,
          date: date,
        );
        var state = await controller.load(
          session,
          day,
          suggestions: await suggestions.forSession(session, day, now: clock),
        );

        for (var i = 0; i < state.items.length; i++) {
          final p = state.items[i].prescription;
          for (final planned in state.items[i].planned) {
            final item = state.items[i];
            final goal = item.suggestion?.repTargetMax ?? p.repsMax;
            final kind = SessionService.inputKindFor(p);
            final kg = kind == SetInputKind.repsAndLoad
                ? item.suggestedLoadKg
                : null;
            if (item.doneCount == 0) {
              (target[p.id] ??= {})[week] = goal;
              if (kg != null) {
                (load[p.exerciseId] ??= {}).putIfAbsent(week, () => kg);
                if (counts && p.progression.type.suggestsKilograms) {
                  (exposures[p.id] ??= []).add((
                    week: week,
                    kg: kg,
                    reps: goal,
                  ));
                }
              }
            }
            clock = clock.add(const Duration(minutes: 2));
            state = await controller.logSet(
              state,
              prescription: p,
              setIndex: planned.setIndex,
              side: planned.side,
              reps:
                  kind == SetInputKind.repsAndLoad || kind == SetInputKind.reps
                  ? goal
                  : null,
              loadKg: kg,
              durationSec: kind == SetInputKind.duration ? goal : null,
              distanceM: kind == SetInputKind.distance ? goal : null,
              rir: p.targetRir,
              exerciseName: p.exerciseId,
            );
          }
        }
        expect(state.visibleItems.every((i) => i.isComplete), isTrue);
        await controller.finish(state);
      }
    }
  });

  tearDownAll(() => db.close());

  String trace(String exerciseId) {
    final w = load[exerciseId] ?? const {};
    return '$exerciseId: ${[for (final k in w.keys.toList()..sort()) '$k:${w[k]}'].join(' ')}';
  }

  double at(String exerciseId, int week) {
    final v = load[exerciseId]?[week];
    if (v == null) fail('no ${trace(exerciseId)} in week $week');
    return v;
  }

  // The coach's simulated best case (review §5), weeks 9 and 11, with a
  // margin: squat 27/31, deadlift 45/55, bench 20/22, OHP 17/19, row 24/28.
  const floors = {
    'barbell-back-squat': 29.0,
    'barbell-deadlift': 50.0,
    'barbell-bench-press': 20.0,
    'barbell-overhead-press': 17.0,
    'barbell-bent-over-row': 24.0,
  };

  test('the main lifts reach the coach\'s week-11 floors', () {
    floors.forEach((ex, floor) {
      printOnFailure(trace(ex));
      expect(at(ex, 11), greaterThanOrEqualTo(floor), reason: trace(ex));
    });
  });

  test('Foundation climbs off the empty bar every week (the 10% cap)', () {
    for (final ex in floors.keys) {
      expect(at(ex, 1), 10, reason: trace(ex));
      for (var w = 2; w <= 4; w++) {
        expect(at(ex, w), greaterThan(at(ex, w - 1)), reason: trace(ex));
      }
    }
  });

  test('the engine delivers the programme\'s own week-4 targets', () {
    for (final t in programme.strengthTargets) {
      if (t.week4Kg == null) continue;
      expect(
        at(t.exerciseId, 4),
        t.week4Kg!.first,
        reason: trace(t.exerciseId),
      );
    }
  });

  test('a warm start in week 5 lands on the Build start load', () {
    // Build's startLoadKg is one earned session on from the week-4 log, so
    // the history path and a cold start agree.
    final build = programme.blockById('build')!;
    for (final d in build.days) {
      for (final p in d.allPrescriptions) {
        if (p.loadMode != LoadMode.barbell || p.startLoadKg == null) continue;
        expect(at(p.exerciseId, 5), p.startLoadKg, reason: trace(p.exerciseId));
      }
    }
  });

  test('a bodyweight Foundation variant does not load the Build one', () {
    // Foundation's split squat is bodyweight, Build's starts at 6 kg: the
    // exercise fallback finds the bodyweight sets, which earned nothing.
    final bss = programme
        .blockById('build')!
        .days
        .expand((d) => d.allPrescriptions)
        .firstWhere((p) => p.id == 'b-sat-3a');
    expect(
      at(bss.exerciseId, 5),
      bss.startLoadKg,
      reason: trace(bss.exerciseId),
    );
  });

  test('week 9 starts above the deload AND above week 7', () {
    for (final ex in floors.keys) {
      expect(at(ex, 8), lessThan(at(ex, 7)), reason: trace(ex));
      expect(at(ex, 9), greaterThan(at(ex, 8)), reason: trace(ex));
      expect(at(ex, 9), greaterThan(at(ex, 7)), reason: trace(ex));
    }
  });

  test('every week-12 test is a hard but honest 5 from week 11', () {
    // The test loads are read off this same projection (tools/gen.py): a
    // rested 5RM at most 10% over the week-11 working weight.
    final test = programme.blockById('test')!;
    for (final d in test.days) {
      for (final p in d.allPrescriptions) {
        if (p.loadMode != LoadMode.barbell || p.startLoadKg == null) continue;
        final w11 = at(p.exerciseId, 11);
        expect(p.startLoadKg, greaterThan(w11), reason: trace(p.exerciseId));
        expect(
          p.startLoadKg,
          lessThanOrEqualTo(w11 * 1.10 + 1e-9),
          reason: '${p.id} ${p.startLoadKg} kg: ${trace(p.exerciseId)}',
        );
      }
    }
  });

  test('no loaded accessory is stuck at the same load and reps', () {
    // The v1 A1 deadlock: 2 kg lateral raises, one plate step is 50% of the
    // load, rep creep to 17... and the log said 15, so 17 again, forever.
    var checked = 0;
    exposures.forEach((id, list) {
      if (list.length < 2) return;
      checked++;
      var run = 1;
      for (var i = 1; i < list.length; i++) {
        final same =
            list[i].kg == list[i - 1].kg && list[i].reps == list[i - 1].reps;
        run = same ? run + 1 : 1;
        expect(
          run,
          lessThanOrEqualTo(3),
          reason:
              '$id is stuck: ${list.map((e) => 'w${e.week} ${e.kg}x${e.reps}').join(', ')}',
        );
      }
      // And it goes somewhere: heavier, or the same weight for more reps.
      final a = list.first, b = list.last;
      expect(
        b.kg > a.kg || (b.kg == a.kg && b.reps > a.reps),
        isTrue,
        reason:
            '$id went nowhere: ${list.map((e) => 'w${e.week} ${e.kg}x${e.reps}').join(', ')}',
      );
    });
    expect(checked, greaterThan(10));
  });

  test('light dumbbell work actually gets heavier by week 11', () {
    for (final id in ['b-mon-2a', 'b-mon-2b', 'b-sat-3a']) {
      final list = exposures[id]!;
      expect(
        list.last.kg,
        greaterThan(list.first.kg),
        reason:
            '$id: ${list.map((e) => 'w${e.week} ${e.kg}x${e.reps}').join(', ')}',
      );
    }
  });

  test('the Sunday run follows the cardio table, deload week included', () {
    for (var week = 1; week <= 11; week++) {
      final row = programme.cardioForWeek(week)!;
      final long = week >= 5 ? 'b-sun-1' : 'f-sun-1';
      expect(target[long]?[week], row.longRunMin!.last * 60, reason: 'w$week');
    }
    expect(target['b-sun-1']?[8], 15 * 60, reason: 'the deload comes down');
  });

  test('a timed hold grows instead of resetting every week', () {
    // timeOnly logged the prescription's own seconds as the target, so the
    // plank added 5 s to 30 every week and never got past 35.
    final plank = target['f-mon-3']!;
    expect(plank[4], greaterThan(plank[2]!), reason: '$plank');
  });

  test('every suggested load was buildable', () {
    final solver = SuggestionService(
      db: db,
      inventory: Fixtures.inventory,
    ).solver;
    final modes = <String, LoadMode>{
      for (final b in programme.blocks.where((b) => !b.inherits))
        for (final d in b.days)
          for (final Prescription p in d.allPrescriptions)
            p.exerciseId: p.loadMode,
    };
    load.forEach((ex, weeks) {
      weeks.forEach((w, kg) {
        expect(
          solver.isValid(kg, modes[ex]!),
          isTrue,
          reason: '$ex week $w $kg kg',
        );
      });
    });
  });
}
