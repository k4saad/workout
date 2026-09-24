import '../models/enums.dart';
import '../models/inventory.dart';
import 'lattice.dart';

/// What one plate-loaded implement can build with the kit.
class ImplementReach {
  const ImplementReach({
    required this.mode,
    required this.baseKg,
    required this.maxKg,
    required this.wholeKgToKg,
    required this.largestStepKg,
  });

  final LoadMode mode;

  /// The bare implement, collars included.
  final double baseKg;

  /// The heaviest it can be loaded to.
  final double maxKg;

  /// Every whole kilogram from the bare implement up to this is buildable.
  /// Equal to [baseKg] when even one kilogram more is not.
  final double wholeKgToKg;

  /// The biggest jump between two neighbouring buildable weights.
  final double largestStepKg;

  /// Every whole kilogram from bare to full.
  bool get everyWholeKg => maxKg - wholeKgToKg < 1 && maxKg > baseKg;
}

/// The kit, summarised for the athlete: how far each implement reaches, and
/// which small plates the whole-kilogram steps depend on.
///
/// Pure. No I/O. Computed from the inventory — never a list of plates to buy
/// typed into a widget.
abstract final class KitSummary {
  /// The implements plates go on.
  static const implements = [
    LoadMode.barbell,
    LoadMode.ezBar,
    LoadMode.dumbbellPair,
    LoadMode.dumbbellSingle,
  ];

  /// The light end: the first ten kilograms above a bare implement, where a
  /// novice lives for months and one missing kilogram is a 5–10 % jump.
  static const lightSpanKg = 10.0;

  static const _eps = 1e-6;

  static ImplementReach reach(
    Inventory inventory,
    LoadMode mode, {
    Lattice? lattice,
  }) {
    final values = (lattice ?? Lattice(inventory)).values(mode);
    final base = inventory.baseWeightFor(mode);
    if (values.isEmpty) {
      return ImplementReach(
        mode: mode,
        baseKg: base,
        maxKg: base,
        wholeKgToKg: base,
        largestStepKg: 0,
      );
    }
    var step = 0.0;
    for (var i = 1; i < values.length; i++) {
      final gap = values[i] - values[i - 1];
      if (gap > step) step = gap;
    }
    var to = base;
    while (_has(values, to + 1)) {
      to += 1;
    }
    return ImplementReach(
      mode: mode,
      baseKg: base,
      maxKg: values.last,
      wholeKgToKg: to,
      largestStepKg: double.parse(step.toStringAsFixed(3)),
    );
  }

  /// The plate sizes the light-end whole kilograms depend on: take one size
  /// away and, on some implement, a whole kilogram within [lightSpanKg] of
  /// the bare implement can no longer be built.
  ///
  /// With the shipped kit these are the 1 kg and 0.5 kg plates — the ones a
  /// standard spinlock set does not come with. Heaviest first.
  static List<PlateStock> wholeKgPlates(Inventory inventory) {
    final before = _lightGaps(inventory);
    final out = <PlateStock>[];
    for (final plate in inventory.plates) {
      final thinner = inventory.copyWith(
        plates: [
          for (final p in inventory.plates)
            if (p.weightKg != plate.weightKg) p,
        ],
      );
      if (_lightGaps(thinner).difference(before).isNotEmpty) out.add(plate);
    }
    out.sort((a, b) => b.weightKg.compareTo(a.weightKg));
    return out;
  }

  /// Every (implement, whole kg) in the light span that cannot be built.
  static Set<String> _lightGaps(Inventory inventory) {
    final lattice = Lattice(inventory);
    final gaps = <String>{};
    for (final mode in implements) {
      final values = lattice.values(mode);
      final base = inventory.baseWeightFor(mode);
      for (var kg = base + 1; kg <= base + lightSpanKg + _eps; kg++) {
        if (!_has(values, kg)) gaps.add('${mode.name}@$kg');
      }
    }
    return gaps;
  }

  static bool _has(List<double> values, double kg) {
    for (final v in values) {
      if ((v - kg).abs() < _eps) return true;
      if (v > kg) return false;
    }
    return false;
  }
}
