import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/plates/plate_solver.dart';
import 'package:keller_twelve/domain/progression/ramp_generator.dart';

import '../support/fixtures.dart';

/// Tests for algorithm D.
///
/// v1 prescribed "50% x 5, 70% x 3, 85% x 1" in free text. At a 20 kg bench
/// with a 9 kg bar, 50% is 10 kg — half a kilo per side, which does not
/// exist. Percentages break whenever the bar is a large fraction of the load,
/// which is every lift in this gym for the first two months.
void main() {
  final solver = PlateSolver(Fixtures.inventory);
  final ramp = RampGenerator(solver);

  group('a light working set needs no ramp', () {
    test('a gap under 4 kg is one empty-bar set', () {
      final sets = ramp.forWorkingSet(11.5, LoadMode.barbell);
      expect(sets, hasLength(1));
      expect(sets.single.loadKg, 9);
      expect(sets.single.reps, 8);
    });

    test('the empty bar itself ramps with itself', () {
      final sets = ramp.forWorkingSet(9, LoadMode.barbell);
      expect(sets, hasLength(1));
      expect(sets.single.loadKg, 9);
    });
  });

  group('a moderate working set gets one intermediate', () {
    test('17 kg bench: bar, then about half the gap', () {
      final sets = ramp.forWorkingSet(17, LoadMode.barbell);
      expect(sets, hasLength(2));
      expect(sets.first.loadKg, 9);
      expect(sets.first.reps, 8);
      expect(sets.last.loadKg, 13);
      expect(sets.last.reps, 5);
    });
  });

  group('a heavy working set gets two intermediates', () {
    test('39 kg deadlift ramps bar, 22.5, 31.5', () {
      // On the shipped 0.5 kg lattice. docs/02's worked examples were
      // computed on a coarser 1.0 kg one.
      final sets = ramp.forWorkingSet(39, LoadMode.barbell);
      expect(sets, hasLength(3));
      expect(sets.map((s) => s.loadKg).toList(), [9.0, 22.5, 31.5]);
      expect(sets.map((s) => s.reps).toList(), [8, 5, 3]);
    });

    test('69 kg deadlift ramps bar, 36, 54', () {
      final sets = ramp.forWorkingSet(69, LoadMode.barbell);
      expect(sets.map((s) => s.loadKg).toList(), [9.0, 36.0, 54.0]);
    });

    test('never more than three ramp sets — the clock is the constraint', () {
      for (final w in [20.0, 40.0, 60.0, 80.0, 100.0, 140.0]) {
        expect(
          ramp.forWorkingSet(w, LoadMode.barbell).length,
          lessThanOrEqualTo(3),
          reason: 'working set $w kg',
        );
      }
    });
  });

  group('every ramp weight is buildable', () {
    test('across the whole range the programme uses', () {
      for (var w = 9.0; w <= 90.0; w += 0.5) {
        for (final s in ramp.forWorkingSet(w, LoadMode.barbell)) {
          expect(
            solver.isValid(s.loadKg, LoadMode.barbell),
            isTrue,
            reason: 'ramp weight ${s.loadKg} for a $w kg working set',
          );
        }
      }
    });

    test('a percentage ramp would NOT be — the v1 bug', () {
      // 50% of a 20 kg bench is 10 kg: 0.5 kg per side.
      final coarse = PlateSolver(Fixtures.inventory);
      expect(
        coarse.isValid(10, LoadMode.barbell),
        isTrue,
        reason: 'with microplates 10 kg happens to work...',
      );
      // ...but the point stands for the real coarse case:
      final noMicro = PlateSolver(
        Fixtures.inventory.copyWith(
          plates: Fixtures.inventory.plates
              .where((p) => p.weightKg >= 1.25)
              .toList(),
        ),
      );
      expect(noMicro.isValid(10, LoadMode.barbell), isFalse);
      expect(noMicro.isValid(17, LoadMode.barbell), isFalse);
    });
  });

  group('ramp sets never reach the working weight', () {
    test('every ramp is strictly lighter', () {
      for (var w = 12.0; w <= 90.0; w += 1.0) {
        for (final s in ramp.forWorkingSet(w, LoadMode.barbell)) {
          expect(s.loadKg, lessThan(w), reason: 'working set $w kg');
        }
      }
    });

    test('and strictly increasing', () {
      final sets = ramp.forWorkingSet(69, LoadMode.barbell);
      for (var i = 1; i < sets.length; i++) {
        expect(sets[i].loadKg, greaterThan(sets[i - 1].loadKg));
        expect(sets[i].reps, lessThanOrEqualTo(sets[i - 1].reps));
      }
    });
  });

  group('rest between ramp sets', () {
    test('60 seconds normally', () {
      final sets = ramp.forWorkingSet(30, LoadMode.barbell);
      expect(sets.every((s) => s.restSec == 60), isTrue);
    });

    test('75 seconds when the lift is a deadlift', () {
      final sets = ramp.forWorkingSet(
        60,
        LoadMode.barbell,
        exerciseId: 'barbell-deadlift',
      );
      expect(sets.every((s) => s.restSec == 75), isTrue);
    });
  });

  group('non-barbell modes', () {
    test('dumbbells ramp on their own lattice', () {
      final sets = ramp.forWorkingSet(8, LoadMode.dumbbellPair);
      expect(sets, isNotEmpty);
      for (final s in sets) {
        expect(solver.isValid(s.loadKg, LoadMode.dumbbellPair), isTrue);
        expect(s.loadKg, lessThanOrEqualTo(8));
      }
    });

    test('bodyweight and banded work does not ramp', () {
      expect(ramp.forWorkingSet(0, LoadMode.bodyweight), isEmpty);
      expect(ramp.forWorkingSet(0, LoadMode.banded), isEmpty);
      expect(ramp.forWorkingSet(0, LoadMode.timed), isEmpty);
    });
  });

  group('the whole ramp is marked as warm-up', () {
    test('so it never feeds progression or volume', () {
      final sets = ramp.forWorkingSet(39, LoadMode.barbell);
      expect(sets.every((s) => s.isWarmup), isTrue);
    });

    test('and it reports how long it will take', () {
      final sets = ramp.forWorkingSet(39, LoadMode.barbell);
      final seconds = RampGenerator.estimatedSeconds(sets);
      expect(seconds, greaterThan(0));
      expect(seconds, lessThan(400), reason: 'a ramp is not a workout');
    });
  });
}
