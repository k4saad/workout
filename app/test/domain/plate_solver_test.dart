import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/inventory.dart';
import 'package:keller_twelve/domain/plates/plate_solver.dart';

import '../support/fixtures.dart';

/// Tests B-1 .. B-12 from docs/02-data-model.md algorithm B.
///
/// Written before the implementation. The plate solver is the thing that
/// stops the app suggesting a weight this gym cannot build.
void main() {
  final inventory = Fixtures.inventory;
  final solver = PlateSolver(inventory);

  /// The coarse inventory v1 assumed: 1.25 kg smallest, so a 2.5 kg step.
  final coarse = Inventory(
    bars: inventory.bars,
    plates: inventory.plates.where((p) => p.weightKg >= 1.25).toList(),
    kettlebells: inventory.kettlebells,
  );
  final coarseSolver = PlateSolver(coarse);

  group('B-1 — an exact hit', () {
    test('21 kg barbell solves with no delta', () {
      final s = solver.solve(21, LoadMode.barbell);
      expect(s.achievableKg, 21);
      expect(s.deltaFromTarget, 0);
      expect(s.isExact, isTrue);
    });

    test('the breakdown names the bar and the per-side plates', () {
      final s = solver.solve(21, LoadMode.barbell);
      // 21 = bar 9 + 6 per side
      expect(s.breakdown, contains('bar 9'));
      expect(s.breakdown, contains('per side'));
      expect(s.perSide.fold<double>(0, (a, p) => a + p.kg * p.count), 6);
    });
  });

  group('B-2 — a target between lattice points', () {
    test('rounds DOWN and offers the one above', () {
      final s = coarseSolver.solve(20, LoadMode.barbell);
      // Coarse lattice: 9, 11.5, 14, 16.5, 19, 21.5 ...
      expect(s.achievableKg, 19);
      expect(s.nextUpKg, 21.5);
      expect(s.isExact, isFalse);
      expect(s.deltaFromTarget, -1);
    });

    test('never rounds up — suggesting more than you earned hurts people', () {
      for (final target in [10.0, 20.0, 25.0, 27.5, 45.0]) {
        final s = coarseSolver.solve(target, LoadMode.barbell);
        expect(
          s.achievableKg,
          lessThanOrEqualTo(target),
          reason: 'target $target',
        );
      }
    });
  });

  group('B-3 — a target below the bar', () {
    test('clamps to the bare bar and says so', () {
      final s = solver.solve(5, LoadMode.barbell);
      expect(s.achievableKg, 9);
      expect(s.deltaFromTarget, greaterThan(0));
      expect(s.isBelowBar, isTrue);
      expect(s.warning, contains('bare'));
    });

    test('a deloaded lateral raise hits this case', () {
      // 2 kg dumbbells at 70% = 1.4 kg, below the 2 kg bare handle.
      final s = solver.solve(1.4, LoadMode.dumbbellPair);
      expect(s.achievableKg, 2.0);
      expect(s.isBelowBar, isTrue);
    });
  });

  group('B-4 — inventory exhausted', () {
    test('returns the heaviest buildable weight rather than throwing', () {
      final s = solver.solve(500, LoadMode.barbell);
      expect(s.achievableKg, lessThan(500));
      expect(s.achievableKg, greaterThan(100));
      expect(s.nextUpKg, isNull);
      expect(s.warning, contains('heaviest'));
    });

    test('an empty plate collection still gives you the bar', () {
      final bare = Inventory(bars: inventory.bars, plates: const []);
      final s = PlateSolver(bare).solve(40, LoadMode.barbell);
      expect(s.achievableKg, 9);
      expect(s.perSide, isEmpty);
    });
  });

  group('B-5 — a dumbbell PAIR consumes four plates per size', () {
    test('the budget is count ~/ 4, not count ~/ 2', () {
      // 8 x 1.25 kg means 2 per side per handle for a pair, 4 for a single.
      final pair = solver.budgetFor(LoadMode.dumbbellPair);
      final single = solver.budgetFor(LoadMode.dumbbellSingle);
      final pair125 = pair.firstWhere((b) => b.kg == 1.25).count;
      final single125 = single.firstWhere((b) => b.kg == 1.25).count;
      expect(pair125, 2);
      expect(single125, 4);
    });

    test('a pair target is PER dumbbell, not the total', () {
      final s = solver.solve(7, LoadMode.dumbbellPair);
      expect(s.achievableKg, 7);
      // 7 = 2 kg handle + 2.5 per side
      expect(s.perSide.fold<double>(0, (a, p) => a + p.kg * p.count), 2.5);
    });
  });

  group('B-6 — single vs pair differ at the same target', () {
    test('a single dumbbell can reach weights a pair cannot', () {
      final heavy = 30.0;
      final single = solver.solve(heavy, LoadMode.dumbbellSingle);
      final pair = solver.solve(heavy, LoadMode.dumbbellPair);
      expect(single.achievableKg, greaterThanOrEqualTo(pair.achievableKg));
    });
  });

  group('B-7 — the empty bar', () {
    test('no plates, and the breakdown says bar only', () {
      final s = solver.solve(9, LoadMode.barbell);
      expect(s.achievableKg, 9);
      expect(s.perSide, isEmpty);
      expect(s.breakdown, contains('bar only'));
    });
  });

  group('B-8 — contention', () {
    test('a barbell and a dumbbell pair competing for the same plates', () {
      // Only four 5 kg plates: a 40 kg barbell wants two per side, and a
      // pair of 12 kg dumbbells wants one per side per handle.
      final scarce = Inventory(
        bars: inventory.bars,
        plates: const [
          PlateStock(weightKg: 5, count: 4),
          PlateStock(weightKg: 1.25, count: 4),
        ],
      );
      final s = PlateSolver(scarce);
      final report = s.contention([
        (kg: 29.0, mode: LoadMode.barbell),
        (kg: 12.0, mode: LoadMode.dumbbellPair),
      ]);
      expect(report.isContended, isTrue);
      expect(report.shortfall.keys, contains(5.0));
      expect(report.message, contains('5'));
    });

    test('no contention when the plates go round', () {
      final report = solver.contention([
        (kg: 21.0, mode: LoadMode.barbell),
        (kg: 6.0, mode: LoadMode.dumbbellPair),
      ]);
      expect(report.isContended, isFalse);
      expect(report.message, isNull);
    });
  });

  group('B-9 / B-10 — the smallest step', () {
    test('1.25 kg plates give a 2.5 kg barbell step', () {
      expect(coarseSolver.smallestStepAt(19, LoadMode.barbell), 2.5);
    });

    test('0.25 kg microplates give a 0.5 kg step', () {
      expect(solver.smallestStepAt(21, LoadMode.barbell), 0.5);
    });

    test('the step at the very top of the range is null', () {
      final max = solver.maxFor(LoadMode.barbell)!;
      expect(solver.smallestStepAt(max, LoadMode.barbell), isNull);
    });
  });

  group('B-11 / B-12 — lattice validity', () {
    test('20 kg is NOT loadable with 1.25 kg plates — the v1 bug', () {
      expect(coarseSolver.isValid(20, LoadMode.barbell), isFalse);
    });

    test('19 kg is', () {
      expect(coarseSolver.isValid(19, LoadMode.barbell), isTrue);
    });

    test('every one of v1\'s starting weights misses the coarse lattice', () {
      // The exact list from docs/00-audit.md A2.
      for (final kg in [20.0, 27.5, 45.0, 12.5, 22.5, 25.0, 32.5]) {
        expect(
          coarseSolver.isValid(kg, LoadMode.barbell),
          isFalse,
          reason: '$kg kg should not be loadable',
        );
      }
    });
  });

  group('the microplate hint', () {
    test('fires when a step is more than 5% of the load', () {
      // 2.5 kg on a 17 kg bench is 15%.
      final s = coarseSolver.solve(16.5, LoadMode.barbell);
      expect(s.microplateHint, isNotNull);
      expect(s.microplateHint, contains('%'));
      expect(s.microplateHint, contains('microplate'));
    });

    test('stays quiet when the step is fine', () {
      // 0.5 kg on 21 kg is 2.4%.
      final s = solver.solve(21, LoadMode.barbell);
      expect(s.microplateHint, isNull);
    });

    test('fires hardest on the overhead press, as predicted', () {
      // 13 kg OHP with a 2.5 kg step is 19%.
      final s = coarseSolver.solve(11.5, LoadMode.barbell);
      expect(s.microplateHint, isNotNull);
    });
  });

  group('non-plate modes pass through', () {
    test('bodyweight, banded, timed and distance do not solve', () {
      for (final mode in [
        LoadMode.bodyweight,
        LoadMode.banded,
        LoadMode.timed,
        LoadMode.distance,
        LoadMode.cable,
      ]) {
        final s = solver.solve(42, mode);
        expect(s.achievableKg, 42, reason: mode.name);
        expect(s.perSide, isEmpty, reason: mode.name);
      }
    });

    test('a kettlebell snaps to one you own', () {
      final s = solver.solve(10, LoadMode.kettlebell);
      expect(s.achievableKg, 8, reason: 'only an 8 kg bell in the inventory');
    });
  });

  group('every load in the shipped programme is buildable', () {
    test('and the breakdown reads like something you can follow', () {
      final programme = Fixtures.programme;
      var checked = 0;
      for (final b in programme.blocks.where((b) => !b.inherits)) {
        for (final d in b.days) {
          for (final p in d.allPrescriptions) {
            if (p.startLoadKg == null || !p.loadMode.isPlateLoaded) continue;
            checked++;
            final s = solver.solve(p.startLoadKg!, p.loadMode);
            expect(
              s.isExact,
              isTrue,
              reason: '${p.id}: ${p.startLoadKg} kg is not buildable',
            );
            expect(s.breakdown, isNotEmpty);
          }
        }
      }
      expect(checked, greaterThan(20));
    });
  });
}
