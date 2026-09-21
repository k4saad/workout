import '../models/enums.dart';
import '../models/inventory.dart';

/// The set of weights a finite plate collection can actually make.
///
/// This is the concept the whole app turns on. A barbell loads in PAIRS, so:
///
/// ```
/// achievable = baseWeight + 2 * (any sum of plates you can put on one side)
/// ```
///
/// With a 9 kg bar and 1.25 kg as the smallest plate, the achievable set is
/// `9, 11.5, 14, 16.5, 19, 21.5, 24 ...` — 2.5 kg apart and offset by 9. No
/// round number is on it. 20 kg, 25 kg, 27.5 kg and 45 kg simply do not exist
/// in this gym, which is why 19 of v1's 25 starting weights were unloadable
/// (docs/00-audit.md A2).
///
/// Every load the app suggests passes through here. Pure Dart, no I/O.
class Lattice {
  Lattice(this.inventory);

  final Inventory inventory;

  static const double _eps = 1e-6;

  final Map<LoadMode, List<double>> _cache = {};

  /// Every achievable total weight for [mode], ascending.
  ///
  /// Computed once per mode and cached — the plate combinations are a product
  /// over plate sizes and this gets called from the session runner.
  List<double> values(LoadMode mode) =>
      _cache.putIfAbsent(mode, () => _compute(mode));

  List<double> _compute(LoadMode mode) {
    if (!mode.isPlateLoaded) return const [];
    final base = inventory.baseWeightFor(mode);
    final budget = inventory.budgetFor(mode);

    // Distinct per-side sums, built by expanding one plate size at a time.
    var perSide = <double>{0.0};
    for (final stock in budget) {
      final next = <double>{};
      for (final sum in perSide) {
        for (var n = 0; n <= stock.count; n++) {
          next.add(_round(sum + stock.kg * n));
        }
      }
      perSide = next;
    }

    final totals = perSide.map((s) => _round(base + 2 * s)).toSet().toList()
      ..sort();
    return totals;
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  /// True when [kg] is a weight this gym can actually build.
  ///
  /// Gate V6 asserts this for every authored `startLoadKg`.
  bool isValid(double kg, LoadMode mode) {
    if (!mode.isPlateLoaded) return true;
    final vs = values(mode);
    for (final v in vs) {
      if ((v - kg).abs() < _eps) return true;
    }
    return false;
  }

  /// The closest achievable weight at or BELOW [target].
  ///
  /// Always rounds DOWN. Suggesting a weight heavier than earned is how people
  /// get hurt training alone.
  double snapDown(double target, LoadMode mode) {
    if (!mode.isPlateLoaded) return target;
    final vs = values(mode);
    if (vs.isEmpty) return target;
    double? best;
    for (final v in vs) {
      if (v <= target + _eps) {
        best = v;
      } else {
        break;
      }
    }
    // Below the bare implement: clamp to base and let the caller flag it.
    // You cannot deload an empty bar.
    return best ?? vs.first;
  }

  /// The closest achievable weight at or ABOVE [target], or null if [target]
  /// is beyond what the plates can reach.
  double? snapUp(double target, LoadMode mode) {
    if (!mode.isPlateLoaded) return target;
    for (final v in values(mode)) {
      if (v >= target - _eps) return v;
    }
    return null;
  }

  /// The smallest loadable increase from [kg], or null at the top of the
  /// range.
  ///
  /// This single number decides whether progression is smooth or unusable: on
  /// a 17 kg bench a 2.5 kg step is 15%, which is far too big a jump for a
  /// beginner and is exactly what deadlocked v1's engine.
  double? smallestStepAt(double kg, LoadMode mode) {
    if (!mode.isPlateLoaded) return null;
    for (final v in values(mode)) {
      if (v > kg + _eps) return _round(v - kg);
    }
    return null;
  }

  /// The uniform step between adjacent lattice points at the light end, which
  /// is where the athlete actually lives for the first two months.
  double? get nominalBarbellStep {
    final vs = values(LoadMode.barbell);
    if (vs.length < 2) return null;
    return _round(vs[1] - vs[0]);
  }

  /// True when one step from [kg] is a bigger jump than [maxJumpPct].
  ///
  /// When this fires, adding weight is the wrong move and the engine should
  /// rep-creep instead — extend the rep range before touching the plates.
  bool stepIsTooBig(double kg, LoadMode mode, double maxJumpPct) {
    final step = smallestStepAt(kg, mode);
    if (step == null) return false;
    return step > kg * maxJumpPct + _eps;
  }

  /// Highest weight this gym can build for [mode].
  double? maxFor(LoadMode mode) {
    final vs = values(mode);
    return vs.isEmpty ? null : vs.last;
  }
}
