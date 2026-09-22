import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/inventory.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/plates/plate_solver.dart';
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
  final fine = Fixtures.inventory; // 0.25 kg microplates -> 0.5 kg step
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
      final p = squat(type: ProgressionType.timeOnly).copyWith(
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
