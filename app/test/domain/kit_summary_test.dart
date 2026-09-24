import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/inventory.dart';
import 'package:keller_twelve/domain/plates/kit_summary.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';

import '../support/fixtures.dart';

void main() {
  final shipped = Fixtures.inventory;

  Inventory without(Inventory inv, List<double> sizes) => inv.copyWith(
    plates: [
      for (final p in inv.plates)
        if (!sizes.contains(p.weightKg)) p,
    ],
  );

  group('reach', () {
    test('the shipped kit builds every whole kilogram on every implement', () {
      for (final mode in KitSummary.implements) {
        final r = KitSummary.reach(shipped, mode);
        expect(r.baseKg, shipped.baseWeightFor(mode), reason: mode.name);
        expect(r.maxKg, Lattice(shipped).maxFor(mode), reason: mode.name);
        expect(r.everyWholeKg, isTrue, reason: mode.name);
        expect(r.largestStepKg, lessThanOrEqualTo(1.0), reason: mode.name);
      }
    });

    test('the whole-kilogram run is checked, not assumed', () {
      // Every whole kilogram up to the run's end must be on the lattice.
      final lattice = Lattice(shipped);
      final r = KitSummary.reach(shipped, LoadMode.barbell, lattice: lattice);
      for (var kg = r.baseKg; kg <= r.wholeKgToKg; kg++) {
        expect(lattice.isValid(kg, LoadMode.barbell), isTrue, reason: '$kg');
      }
    });

    test('without the small plates the barbell jumps 2.5 kg at a time', () {
      final coarse = without(shipped, [1.0, 0.5]);
      final r = KitSummary.reach(coarse, LoadMode.barbell);
      expect(r.everyWholeKg, isFalse);
      expect(r.wholeKgToKg, r.baseKg, reason: 'bar + 1 kg is not buildable');
      expect(r.largestStepKg, 2.5);
    });

    test('an implement with no plates reaches only its own weight', () {
      final bare = shipped.copyWith(plates: const []);
      final r = KitSummary.reach(bare, LoadMode.ezBar);
      expect(r.maxKg, shipped.baseWeightFor(LoadMode.ezBar));
      expect(r.wholeKgToKg, r.baseKg);
      expect(r.everyWholeKg, isFalse);
    });
  });

  group('wholeKgPlates', () {
    test('names the 1 kg and 0.5 kg plates in the shipped kit', () {
      final small = KitSummary.wholeKgPlates(shipped);
      expect(small.map((p) => p.weightKg), [1.0, 0.5]);
      expect(small.map((p) => p.count), [
        shipped.plates.firstWhere((p) => p.weightKg == 1.0).count,
        shipped.plates.firstWhere((p) => p.weightKg == 0.5).count,
      ]);
    });

    test('taking any one of them away opens a whole-kilogram gap', () {
      for (final p in KitSummary.wholeKgPlates(shipped)) {
        final thinner = without(shipped, [p.weightKg]);
        final opened = KitSummary.implements.any(
          (m) => !KitSummary.reach(thinner, m).everyWholeKg,
        );
        expect(opened, isTrue, reason: '${p.weightKg} kg');
      }
    });

    test('the big plates are not counted as small ones', () {
      final sizes = KitSummary.wholeKgPlates(shipped).map((p) => p.weightKg);
      expect(sizes, isNot(contains(1.25)));
      expect(sizes, isNot(contains(20.0)));
    });

    test('the v2 kit leaned on every size from 2.5 kg down', () {
      // A dumbbell pair gets a quarter of each size: two a side. With no
      // 1 kg plates, even the 2.5s were needed for an 11 kg pair.
      expect(
        KitSummary.wholeKgPlates(Fixtures.legacyInventory)
            .map((p) => p.weightKg),
        [2.5, 1.25, 0.5, 0.25],
      );
    });

    test('a kit with nothing small names nothing', () {
      final coarse = without(shipped, [1.0, 0.5]);
      expect(KitSummary.wholeKgPlates(coarse), isEmpty);
    });
  });
}
