import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/inventory.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/plates/plate_solver.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/domain/progression/logged_set.dart';
import 'package:keller_twelve/domain/progression/progression_engine.dart';

import '../support/fixtures.dart';

/// Tests A-1 .. A-17 from docs/02-data-model.md algorithm A.
///
/// Written before the implementation. A-4 and A-14 are the two that catch
/// v1's deadlock and must never be deleted: on a 17 kg bench with a 2.5 kg
/// lattice, v1 would earn a jump, clamp it to 10%, round that down to zero,
/// and report "earned the jump" while suggesting the same weight forever.
void main() {
  // The pinned v2 inventory these cases were written for: a 9 kg bar and
  // 0.25 kg microplates -> a 0.5 kg step. Engine behaviour, not shipped data.
  final fine = Fixtures.legacyInventory;
  final coarse = Inventory(
    bars: fine.bars,
    plates: fine.plates.where((p) => p.weightKg >= 1.25).toList(),
    kettlebells: fine.kettlebells,
  );

  final fineEngine = ProgressionEngine(PlateSolver(fine));
  final coarseEngine = ProgressionEngine(PlateSolver(coarse));

  final now = DateTime(2026, 11, 2);

  Prescription squat({
    int sets = 4,
    int repsMin = 6,
    int repsMax = 8,
    int? creep = 12,
    double start = 30,
    double increment = 2.5,
    int? rir = 2,
    ProgressionType type = ProgressionType.doubleProgression,
  }) => Prescription(
    id: 'b-mon-1',
    exerciseId: 'barbell-back-squat',
    order: 1,
    sets: sets,
    repsMin: repsMin,
    repsMax: repsMax,
    repsCreepMax: creep,
    restSec: 150,
    targetRir: rir,
    loadMode: LoadMode.barbell,
    startLoadKg: start,
    progression: Progression(
      type: type,
      incrementKg: increment,
      deloadPct: 0.10,
      stallLimit: 2,
      historyWindowDays: 21,
      maxJumpPct: 0.10,
    ),
  );

  List<LoggedSet> sets(
    List<int> reps, {
    double load = 30,
    int rir = 2,
    int targetMin = 6,
    int targetMax = 8,
    int daysAgo = 7,
  }) => [
    for (var i = 0; i < reps.length; i++)
      LoggedSet(
        reps: reps[i],
        loadKg: load,
        rir: rir,
        targetRepsMin: targetMin,
        targetRepsMax: targetMax,
        completedAt: DateTime(2026, 11, 2 - daysAgo, 18, 40 + i),
      ),
  ];

  group('a load of nothing', () {
    // The load stepper goes down to 0 kg, and a set logged there (an empty
    // hand, a slip of the thumb) used to divide by zero in the next
    // suggestion — `step / lastLoad * 100` — and throw as the session opened.
    test('top of the range at 0 kg suggests a real load, not a crash', () {
      for (final engine in [fineEngine, coarseEngine]) {
        final s = engine.suggest(
          prescription: squat(),
          history: sets([8, 8, 8, 8], load: 0),
          now: now,
        );
        expect(s.suggestedKg, isNotNull);
        expect(s.suggestedKg!.isFinite, isTrue);
        expect(s.reason, isNot(contains('Infinity')));
        expect(s.reason, isNot(contains('NaN')));
      }
    });

    test('falling short at 0 kg repeats, without a crash', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([3, 3, 3, 3], load: 0),
        now: now,
      );
      expect(s.reason, isNot(contains('NaN')));
    });
  });

  group('A-1 — no history at all', () {
    test('suggests the programme start', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: const [],
        now: now,
      );
      expect(s.suggestedKg, 30);
      expect(s.reason.toLowerCase(), contains('programme start'));
      expect(s.repTargetMin, 6);
      expect(s.repTargetMax, 8);
    });
  });

  group('A-2 — stale history', () {
    test('30-day-old history is ignored in favour of the start load', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 45, daysAgo: 30),
        now: now,
      );
      expect(s.suggestedKg, 30);
      expect(s.reason.toLowerCase(), contains('programme start'));
    });

    test('20-day-old history is still inside the window', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 45, daysAgo: 20),
        now: now,
      );
      expect(s.suggestedKg, greaterThan(45));
    });
  });

  group('A-3 — an earned jump on a fine lattice', () {
    test('all sets at the top with RIR met adds the increment', () {
      final s = fineEngine.suggest(
        prescription: squat(increment: 1),
        history: sets([8, 8, 8, 8], load: 30, rir: 2),
        now: now,
      );
      expect(s.suggestedKg, 31);
      expect(s.reason.toLowerCase(), contains('earned'));
      expect(s.isRepCreep, isFalse);
      expect(s.repTargetMax, 8, reason: 'reps reset to the base range');
    });

    test('the increment is capped at 10% of the load', () {
      // 2.5 kg on 30 kg is 8.3%, so it goes through untouched.
      final s = fineEngine.suggest(
        prescription: squat(increment: 2.5),
        history: sets([8, 8, 8, 8], load: 30),
        now: now,
      );
      expect(s.suggestedKg, 32.5);
    });
  });

  group('A-4 — THE v1 DEADLOCK: a coarse lattice on a light bar', () {
    test('rep-creeps instead of jumping when one step is >10%', () {
      // 17 kg bench, 2.5 kg step = 15%. v1 clamped to 10% (1.7 kg), rounded
      // that down to zero, and suggested the same weight forever.
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, increment: 2.5),
        history: sets([8, 8, 8, 8], load: 16.5),
        now: now,
      );
      expect(s.isRepCreep, isTrue);
      expect(s.suggestedKg, 16.5, reason: 'the load holds');
      expect(s.repTargetMax, 10, reason: 'but the rep target grows');
      expect(s.repTargetMin, 6);
      expect(s.reason.toLowerCase(), contains('coarse'));
    });

    test('it never returns "earned the jump" with no change', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, increment: 2.5),
        history: sets([8, 8, 8, 8], load: 16.5),
        now: now,
      );
      final nothingChanged = s.suggestedKg == 16.5 && s.repTargetMax == 8;
      expect(
        nothingChanged,
        isFalse,
        reason: 'an earned jump must produce weight OR reps',
      );
    });
  });

  group('A-5 — rep creep has a ceiling', () {
    test('at repsCreepMax the load finally moves', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, increment: 2.5, creep: 12),
        history: sets(
          [12, 12, 12, 12],
          load: 16.5,
          targetMin: 6,
          targetMax: 12,
        ),
        now: now,
      );
      expect(s.isRepCreep, isFalse);
      expect(s.suggestedKg, 19, reason: 'one lattice step up from 16.5');
      expect(s.repTargetMax, 8, reason: 'and the range resets');
      expect(s.reason.toLowerCase(), contains('ceiling'));
    });

    test('rep creep disabled means the load jumps immediately', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, increment: 2.5, creep: null),
        history: sets([8, 8, 8, 8], load: 16.5),
        now: now,
      );
      expect(s.isRepCreep, isFalse);
      expect(s.suggestedKg, 19);
    });
  });

  group('A-6 — inside the range but not at the top', () {
    test('same weight, add reps', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 7, 6], load: 30),
        now: now,
      );
      expect(s.suggestedKg, 30);
      expect(s.reason.toLowerCase(), contains('add reps'));
      expect(s.isStalled, isFalse);
    });

    test('RIR missed means the jump is not earned even at the top', () {
      // Every set at 8 reps, but RIR 0 — that was a grind, not a clean top.
      final s = fineEngine.suggest(
        prescription: squat(rir: 2),
        history: sets([8, 8, 8, 8], load: 30, rir: 0),
        now: now,
      );
      expect(s.suggestedKg, 30, reason: 'the load must not move');
      expect(s.isRepCreep, isFalse);
      expect(s.reason.toLowerCase(), contains('grind'));
    });
  });

  group('A-7 / A-8 — stalling', () {
    test('a set below the range is stall one, same weight', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 6, 5, 5], load: 30),
        stallCount: 0,
        now: now,
      );
      expect(s.suggestedKg, 30);
      expect(s.isStalled, isTrue);
      expect(s.newStallCount, 1);
      expect(s.reason.toLowerCase(), contains('stall 1 of 2'));
    });

    test('a second stall backs off 10%, snapped down, counter reset', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 6, 5, 5], load: 30),
        stallCount: 1,
        now: now,
      );
      // 30 * 0.9 = 27, which is on the 0.5 kg lattice.
      expect(s.suggestedKg, 27);
      expect(s.newStallCount, 0);
      expect(s.reason.toLowerCase(), contains('back off'));
    });

    test('the back-off lands on the lattice even when 90% does not', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 26.5),
        history: sets([8, 6, 5, 5], load: 26.5),
        stallCount: 1,
        now: now,
      );
      // 26.5 * 0.9 = 23.85 -> snaps down to 21.5 on the coarse lattice.
      expect(
        coarseEngine.solver.isValid(s.suggestedKg!, LoadMode.barbell),
        isTrue,
      );
      expect(s.suggestedKg, lessThan(26.5));
    });
  });

  group('A-9 — the deload multiplier', () {
    test('70% is applied and still lands on the lattice', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 30),
        blockLoadMultiplier: 0.7,
        now: now,
      );
      expect(s.suggestedKg, lessThan(30));
      expect(
        fineEngine.solver.isValid(s.suggestedKg!, LoadMode.barbell),
        isTrue,
      );
      expect(s.reason.toLowerCase(), contains('deload'));
    });

    test('a deload below the bare bar clamps to the bar', () {
      final s = fineEngine.suggest(
        prescription: squat(start: 9.5),
        history: sets([8, 8, 8, 8], load: 9.5),
        blockLoadMultiplier: 0.5,
        now: now,
      );
      expect(s.suggestedKg, 9);
      expect(s.plates?.isBelowBar, isTrue);
    });
  });

  group('A-10 — never round up', () {
    test('every suggestion lands on a weight the plates can build', () {
      for (final load in [11.5, 16.5, 19.0, 26.5, 44.0]) {
        final s = coarseEngine.suggest(
          prescription: squat(start: load, increment: 2.5, creep: null),
          history: sets([8, 8, 8, 8], load: load),
          now: now,
        );
        expect(
          coarseEngine.solver.isValid(s.suggestedKg!, LoadMode.barbell),
          isTrue,
          reason: 'from $load kg the engine suggested ${s.suggestedKg}',
        );
      }
    });

    test('a back-off never lands above where it started', () {
      for (final load in [16.5, 19.0, 26.5, 44.0]) {
        final s = coarseEngine.suggest(
          prescription: squat(start: load),
          history: sets([8, 6, 5, 5], load: load),
          stallCount: 1,
          now: now,
        );
        expect(s.suggestedKg, lessThan(load), reason: 'from $load kg');
      }
    });
  });

  group('A-11 / A-12 — substitutes', () {
    test('a substitute with no history of its own starts at its own load', () {
      final s = fineEngine.suggest(
        prescription: squat(start: 12)
            .copyWith(id: 'b-mon-1-sub', exerciseId: 'barbell-front-squat'),
        history: const [],
        now: now,
      );
      expect(
        s.suggestedKg,
        12,
        reason: 'a 30 kg back squat is not a 30 kg front squat',
      );
    });

    test('a substitute WITH history uses it', () {
      final s = fineEngine.suggest(
        prescription: squat(start: 12)
            .copyWith(id: 'b-mon-1-sub', exerciseId: 'barbell-front-squat'),
        history: sets([8, 8, 8, 8], load: 16),
        now: now,
      );
      expect(s.suggestedKg, greaterThan(16));
    });
  });

  group('A-13 — non-kilogram progression types', () {
    test('repsOnly targets one more rep and never a weight', () {
      final s = fineEngine.suggest(
        prescription: squat(
          type: ProgressionType.repsOnly,
          rir: null,
        ).copyWith(loadMode: LoadMode.bodyweight, startLoadKg: null),
        history: sets([10, 10, 10], load: 0),
        now: now,
      );
      expect(s.suggestedKg, isNull);
      expect(s.repTargetMax, greaterThan(8));
      expect(s.reason.toLowerCase(), contains('rep'));
    });

    test('timeOnly adds seconds', () {
      // creep: null on purpose. The squat fixture's default is a 12-REP
      // creep ceiling, and on a hold measured in seconds that would read as
      // a 12-second ceiling on a 30-second plank. tools/validate.py gate V14
      // rejects that shape in authored data.
      final p = squat(type: ProgressionType.timeOnly, creep: null).copyWith(
        loadMode: LoadMode.timed,
        unit: RepUnit.sec,
        startLoadKg: null,
        progression: const Progression(
          type: ProgressionType.timeOnly,
          incrementSec: 5,
        ),
      );
      final s = fineEngine.suggest(
        prescription: p,
        history: [
          LoggedSet(
            durationSec: 30,
            targetRepsMin: 30,
            targetRepsMax: 30,
            completedAt: DateTime(2026, 10, 26),
          ),
        ],
        now: now,
      );
      expect(s.suggestedKg, isNull);
      expect(s.repTargetMax, 35);
    });

    test('bandProgression suggests a thinner band, never a number', () {
      final p = squat(type: ProgressionType.bandProgression)
          .copyWith(loadMode: LoadMode.banded, startLoadKg: null);
      final s = fineEngine.suggest(
        prescription: p,
        history: sets([8, 8, 8, 8], load: 0),
        now: now,
      );
      expect(s.suggestedKg, isNull);
      expect(s.reason.toLowerCase(), contains('band'));
    });

    test('cardioTable defers to the programme table', () {
      final p = squat(type: ProgressionType.cardioTable)
          .copyWith(loadMode: LoadMode.timed, startLoadKg: null);
      final s = fineEngine.suggest(
        prescription: p,
        history: const [],
        now: now,
      );
      expect(s.suggestedKg, isNull);
      expect(s.reason.toLowerCase(), contains('cardio'));
    });

    test('none suggests nothing at all', () {
      final p = squat(type: ProgressionType.none);
      final s = fineEngine.suggest(
        prescription: p,
        history: sets([5], load: 36),
        now: now,
      );
      expect(s.suggestedKg, isNull);
    });
  });

  group('A-14 — the final guard', () {
    test('an earned jump that snaps to no change becomes rep creep', () {
      // Contrive it: a huge maxJumpPct so rule 3a is taken, but an increment
      // smaller than the lattice step, so snapping would land back on the
      // same weight.
      final p = squat(start: 19, increment: 0.1).copyWith(
        progression: const Progression(
          type: ProgressionType.doubleProgression,
          incrementKg: 0.1,
          deloadPct: 0.10,
          stallLimit: 2,
          historyWindowDays: 21,
          maxJumpPct: 0.9,
        ),
      );
      final s = coarseEngine.suggest(
        prescription: p,
        history: sets([8, 8, 8, 8], load: 19),
        now: now,
      );
      final nothingChanged = s.suggestedKg == 19 && s.repTargetMax == 8;
      expect(
        nothingChanged,
        isFalse,
        reason: 'weight OR reps must move when a jump is earned',
      );
    });
  });

  group('A-15 / A-16 / A-17 — history precedence', () {
    test('the rep target carries over from the last session', () {
      // Already crept to 6-10 last time; hitting 10s creeps again.
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, increment: 2.5, creep: 14),
        history: sets(
          [10, 10, 10, 10],
          load: 16.5,
          targetMin: 6,
          targetMax: 10,
        ),
        now: now,
      );
      expect(s.repTargetMax, 12);
      expect(s.isRepCreep, isTrue);
    });

    test('falling short of a CREPT target is a stall, not a reset', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5, creep: 14),
        history: sets([10, 8, 5, 5], load: 16.5, targetMin: 6, targetMax: 10),
        stallCount: 0,
        now: now,
      );
      expect(s.isStalled, isTrue);
      expect(s.repTargetMax, 10, reason: 'the crept target is kept');
    });
  });

  group('v3: the shipped kit and programme (coach review §0)', () {
    final programme = Fixtures.programme;
    final resolver = BlockResolver(programme);
    final shipped = ProgressionEngine(PlateSolver(Fixtures.inventory));

    Prescription resolved(String blockId, int week, String id) => resolver
        .resolveDays(programme.blockById(blockId)!, week)
        .expand((d) => d.allPrescriptions)
        .firstWhere((p) => p.id == id);

    List<LoggedSet> topOfRange(Prescription p, double load) => [
      for (var i = 0; i < p.sets; i++)
        LoggedSet(
          reps: p.repsMax,
          loadKg: load,
          rir: p.targetRir,
          targetRepsMin: p.repsMin,
          targetRepsMax: p.repsMax,
          completedAt: DateTime(2026, 10, 26, 18, i),
        ),
    ];

    test('an empty bar takes the whole Foundation increment', () {
      // At 10 kg a 10% cap is 1 kg; the data widens maxJumpPct in
      // Foundation so the empty-bar lifts can actually climb (item 1).
      for (final id in [
        'f-tue-1',
        'f-thu-1',
        'f-thu-2',
        'f-sat-1',
        'f-sat-2',
      ]) {
        final p = resolved('foundation', 1, id);
        expect(p.startLoadKg, 10, reason: id);
        final s = shipped.suggest(
          prescription: p,
          history: topOfRange(p, 10),
          now: now,
        );
        expect(
          s.suggestedKg,
          10 + p.progression.incrementKg,
          reason: '$id: ${s.reason}',
        );
        expect(s.isRepCreep, isFalse, reason: id);
      }
    });

    test('logging RIR 3 in Foundation earns the jump (item 6)', () {
      final p = resolved('foundation', 2, 'f-tue-1');
      expect(p.targetRir, 3);
      final s = shipped.suggest(
        prescription: p,
        history: topOfRange(p, 13),
        now: now,
      );
      expect(s.suggestedKg, 16);
    });

    test('a deload cold start is scaled once, not 0.7 x 0.7 (minor)', () {
      // The resolver has already put the 70% into startLoadKg.
      final p = resolved('deload', 8, 'b-tue-1');
      final build = resolved('build', 5, 'b-tue-1');
      expect(p.startLoadKg, closeTo(build.startLoadKg! * 0.7, 1e-9));
      final s = shipped.suggest(
        prescription: p,
        history: const [],
        blockLoadMultiplier: 0.7,
        now: now,
      );
      expect(
        s.suggestedKg,
        shipped.solver.solve(p.startLoadKg!, p.loadMode).achievableKg,
      );
      expect(s.reason.toLowerCase(), contains('deload'));
    });

    test('an unloaded history cannot earn a loaded jump', () {
      // Foundation's split squat is bodyweight; Build's is loaded from 6 kg.
      // Twelve bodyweight reps say nothing about 6 kg dumbbells, so week 5
      // starts at the programme's 6, not one jump past a weight never lifted.
      final p = resolved('build', 5, 'b-sat-3a');
      expect(p.loadMode, LoadMode.dumbbellPair);
      final s = shipped.suggest(
        prescription: p,
        history: [
          for (var i = 0; i < 6; i++)
            LoggedSet(
              reps: 12,
              rir: 3,
              targetRepsMin: 8,
              targetRepsMax: 12,
              side: i.isEven ? 'L' : 'R',
              completedAt: DateTime(2026, 10, 30, 18, i),
            ),
        ],
        now: now,
      );
      expect(s.suggestedKg, p.startLoadKg);
      expect(s.repTargetMin, p.repsMin);
      expect(s.repTargetMax, p.repsMax);
    });

    test('a cardio table run targets its resolved week, in seconds', () {
      final p = resolved('push', 11, 'b-sun-1');
      final s = shipped.suggest(prescription: p, history: const [], now: now);
      expect(s.suggestedKg, isNull);
      expect(s.repTargetMin, p.repsMin);
      expect(s.repTargetMax, p.repsMax);
      expect(s.reason, contains('30 min'));
    });
  });

  group('the history window judges a whole session, by the calendar', () {
    // Week 6 Monday at 18:40, and week 9 Monday opened at 19:00: exactly 21
    // days apart, but 21 days and 20 minutes by the clock. Per set and by
    // the hour, those sets fell out of the window and week 9 went back to
    // the programme start (Phase 1 review).
    final week9 = DateTime(2026, 11, 2, 19);

    test('a session 21 calendar days ago is in a 21-day window', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 40, daysAgo: 21),
        now: week9,
      );
      expect(s.suggestedKg, greaterThan(40), reason: s.reason);
    });

    test('22 days is outside it', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 40, daysAgo: 22),
        now: week9,
      );
      expect(s.suggestedKg, 30);
      expect(s.reason.toLowerCase(), contains('programme start'));
    });

    test('training in between (the deload) keeps older history live', () {
      // Week 7 missed, week 8 trained (the deload: not history, but he was
      // under the bar a week ago), week 9: the week-6 sets are what to
      // progress from, even 25 days on.
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 40, daysAgo: 25),
        lastTrainedAt: DateTime(2026, 10, 26, 18),
        now: week9,
      );
      expect(s.suggestedKg, 42.5, reason: s.reason);
    });

    test('a session straddling the cutoff is judged on all of its sets', () {
      // The first two sets land before midnight 21 days back, the last two
      // after it. Judged on its later sets only, 8, 8 at the top would earn
      // a jump the whole session did not.
      final history = [
        for (final (i, reps) in [5, 5, 8, 8].indexed)
          LoggedSet(
            reps: reps,
            loadKg: 40,
            rir: 2,
            targetRepsMin: 6,
            targetRepsMax: 8,
            completedAt: DateTime(2026, 10, 11, 23, 50 + i * 5),
          ),
      ];
      final s = fineEngine.suggest(
        prescription: squat(),
        history: history,
        now: week9,
      );
      expect(s.isStalled, isTrue, reason: s.reason);
      expect(s.suggestedKg, 40);
    });
  });

  group('rule 3a never takes less than one loadable step', () {
    // The shipped kit before its 1.0 and 0.5 kg plates are bought: the
    // barbell moves in 2.5 kg steps.
    final unbought = Inventory(
      bars: Fixtures.inventory.bars,
      plates: Fixtures.inventory.plates
          .where((p) => p.weightKg >= 1.25)
          .toList(),
      fixedDumbbells: Fixtures.inventory.fixedDumbbells,
      kettlebells: Fixtures.inventory.kettlebells,
    );
    final engine = ProgressionEngine(PlateSolver(unbought));

    Prescription bench({
      required int repsMin,
      required int repsMax,
      int? creep,
      required double increment,
      required double maxJumpPct,
    }) => squat(repsMin: repsMin, repsMax: repsMax, creep: creep).copyWith(
      id: 'b-tue-1',
      exerciseId: 'barbell-bench-press',
      progression: Progression(
        type: ProgressionType.doubleProgression,
        incrementKg: increment,
        deloadPct: 0.10,
        stallLimit: 2,
        historyWindowDays: 21,
        maxJumpPct: maxJumpPct,
      ),
    );

    test('at the rep-creep ceiling the load moves (no deadlock)', () {
      // 1 kg wanted, 2.5 kg is the smallest step and exactly 10%: v2 took
      // 1 kg, snapped back to 25, and at the creep ceiling returned
      // 25 x 6 "Earned the jump." forever.
      final s = engine.suggest(
        prescription: bench(
          repsMin: 6,
          repsMax: 6,
          creep: 10,
          increment: 1.0,
          maxJumpPct: 0.10,
        ),
        history: sets([10, 10, 10, 10], load: 25, targetMin: 6, targetMax: 10),
        now: now,
      );
      expect(s.suggestedKg, 27.5, reason: s.reason);
      expect(s.repTargetMax, 6);
      expect(s.isRepCreep, isFalse);
    });

    test('without rep creep the load moves too', () {
      final s = engine.suggest(
        prescription: bench(
          repsMin: 8,
          repsMax: 8,
          increment: 2.0,
          maxJumpPct: 0.25,
        ),
        history: sets([8, 8, 8], load: 10, targetMin: 8, targetMax: 8),
        now: now,
      );
      expect(s.suggestedKg, 12.5, reason: s.reason);
    });
  });

  group('timed holds have a ceiling', () {
    Prescription hold({int? ceiling = 40}) =>
        squat(type: ProgressionType.timeOnly).copyWith(
          loadMode: LoadMode.timed,
          unit: RepUnit.sec,
          startLoadKg: null,
          repsMin: 30,
          repsMax: 30,
          repsCreepMax: ceiling,
          progression: const Progression(
            type: ProgressionType.timeOnly,
            incrementSec: 5,
          ),
        );

    List<LoggedSet> held(int sec) => [
      for (var i = 0; i < 3; i++)
        LoggedSet(
          durationSec: sec,
          targetRepsMin: sec,
          targetRepsMax: sec,
          completedAt: DateTime(2026, 10, 26, 18, i),
        ),
    ];

    test('a hold at its ceiling stays there', () {
      final s = fineEngine.suggest(
        prescription: hold(),
        history: held(40),
        now: now,
      );
      expect(s.repTargetMin, 40);
      expect(s.repTargetMax, 40);
      expect(s.reason.toLowerCase(), contains('ceiling'));
    });

    test('growth stops at the ceiling, not past it', () {
      final s = fineEngine.suggest(
        prescription: hold(),
        history: held(38),
        now: now,
      );
      expect(s.repTargetMax, 40);
    });

    test('below the ceiling it still adds the increment', () {
      final s = fineEngine.suggest(
        prescription: hold(),
        history: held(30),
        now: now,
      );
      expect(s.repTargetMax, 35);
      expect(s.reason, contains('add 5 seconds'));
    });
  });

  group('a deload never asks for more reps', () {
    final programme = Fixtures.programme;
    final resolver = BlockResolver(programme);
    final shipped = ProgressionEngine(PlateSolver(Fixtures.inventory));

    Prescription deload(String id) => resolver
        .resolveDays(programme.blockById('deload')!, 8)
        .expand((d) => d.allPrescriptions)
        .firstWhere((p) => p.id == id);

    List<LoggedSet> week7(int sets, int reps, double kg, int min, int max) => [
      for (var i = 0; i < sets; i++)
        LoggedSet(
          reps: reps,
          loadKg: kg,
          rir: 1,
          targetRepsMin: min,
          targetRepsMax: max,
          completedAt: DateTime(2026, 10, 30, 18, i),
        ),
    ];

    test('the overhead press is 70% of the earned load at 6 reps', () {
      // Earned 17; 70% is 11.9 -> 11, the same plates as 70% of 16. That
      // used to trip rule 8 and creep the DELOAD to 6-8.
      final p = deload('b-thu-2');
      final s = shipped.suggest(
        prescription: p,
        history: week7(3, 6, 16, 6, 6),
        blockLoadMultiplier: 0.7,
        now: now,
      );
      expect(s.suggestedKg, 11, reason: s.reason);
      expect(s.repTargetMin, p.repsMin);
      expect(s.repTargetMax, 6);
      expect(s.isRepCreep, isFalse);
      expect(s.reason, contains('Deload'));
      expect(s.reason, isNot(contains('not loadable')));
      expect(s.reason, contains('17 kg'));
    });

    test('light dumbbell work holds its range in the deload', () {
      // 6 kg split-squat dumbbells, top of the range: in a normal week a
      // coarse step means rep creep. In the deload it is 70% at 8 reps.
      final p = deload('b-sat-3a');
      final s = shipped.suggest(
        prescription: p,
        history: week7(3, 8, 6, 8, 8),
        blockLoadMultiplier: 0.7,
        now: now,
      );
      expect(s.repTargetMax, p.repsMax, reason: s.reason);
      expect(s.suggestedKg, lessThan(6));
      expect(s.isRepCreep, isFalse);
      expect(s.reason, contains('Deload'));
      expect(s.reason.toLowerCase(), isNot(contains('coarse')));
    });
  });

  group('the suggestion carries how to load it', () {
    test('plates and a readable breakdown come with the number', () {
      final s = fineEngine.suggest(
        prescription: squat(),
        history: sets([8, 8, 8, 8], load: 30),
        now: now,
      );
      expect(s.plates, isNotNull);
      expect(s.plates!.breakdown, contains('bar 9'));
      expect(s.smallestStepKg, 0.5);
    });

    test('a coarse lattice surfaces the microplate hint', () {
      final s = coarseEngine.suggest(
        prescription: squat(start: 16.5),
        history: const [],
        now: now,
      );
      expect(s.plates!.microplateHint, isNotNull);
    });
  });
}
