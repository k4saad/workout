import '../models/enums.dart';
import '../plates/plate_solver.dart';

/// One warm-up set on the way to a working weight.
class RampSet {
  const RampSet({
    required this.loadKg,
    required this.reps,
    required this.restSec,
    this.isWarmup = true,
  });

  final double loadKg;
  final int reps;
  final int restSec;

  /// Always true. Ramp sets are logged so the history is honest, but they are
  /// excluded from every progression decision and every volume statistic.
  final bool isWarmup;

  @override
  String toString() => '${_fmt(loadKg)} kg × $reps';

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Builds the warm-up ramp for a working set.
///
/// **Absolute, not percentage-based.** v1 prescribed "50% x 5, 70% x 3,
/// 85% x 1", which is unloadable whenever the bar is a large fraction of the
/// load: 50% of a 20 kg bench is 10 kg, or half a kilo per side
/// (docs/00-audit.md C1). Every weight here is snapped onto the lattice, so
/// every ramp set is something you can actually build.
///
/// Pure. No I/O.
class RampGenerator {
  const RampGenerator(this.solver);

  final PlateSolver solver;

  /// Below this gap there is nothing worth ramping — just pull the bar out.
  static const minGapKg = 4.0;

  /// Above this gap, two intermediates instead of one.
  static const twoStepGapKg = 15.0;

  /// The clock is the constraint. Three is the ceiling.
  static const maxRampSets = 3;

  List<RampSet> forWorkingSet(
    double workingKg,
    LoadMode mode, {
    String? exerciseId,
  }) {
    if (!mode.isPlateLoaded) return const [];

    final base = solver.inventory.baseWeightFor(mode);
    final gap = workingKg - base;
    final rest = _restFor(exerciseId);

    if (gap <= 0) {
      return [RampSet(loadKg: base, reps: 8, restSec: rest)];
    }

    if (gap < minGapKg) {
      // The bar itself IS the warm-up at these loads.
      return [RampSet(loadKg: base, reps: 8, restSec: rest)];
    }

    final out = <RampSet>[RampSet(loadKg: base, reps: 8, restSec: rest)];

    if (gap < twoStepGapKg) {
      final mid = _snapBetween(base, workingKg, base + gap * 0.5, mode);
      if (mid != null) {
        out.add(RampSet(loadKg: mid, reps: 5, restSec: rest));
      }
    } else {
      final first = _snapBetween(base, workingKg, base + gap * 0.45, mode);
      if (first != null) {
        out.add(RampSet(loadKg: first, reps: 5, restSec: rest));
      }
      final second = _snapBetween(
        first ?? base,
        workingKg,
        base + gap * 0.75,
        mode,
      );
      if (second != null) {
        out.add(RampSet(loadKg: second, reps: 3, restSec: rest));
      }
    }

    return out.length > maxRampSets ? out.sublist(0, maxRampSets) : out;
  }

  /// Snaps a candidate onto the lattice, rejecting anything that is not
  /// strictly between [lower] and [working].
  ///
  /// A ramp set at the working weight is not a ramp set, and one at or below
  /// the previous rung is wasted time.
  double? _snapBetween(
    double lower,
    double working,
    double candidate,
    LoadMode mode,
  ) {
    final snapped = solver.solve(candidate, mode).achievableKg;
    if (snapped <= lower + 1e-6) return null;
    if (snapped >= working - 1e-6) return null;
    return snapped;
  }

  /// Deadlifts get a little longer between ramp sets: they are the heaviest
  /// thing in the room and the setup takes longer.
  static int _restFor(String? exerciseId) =>
      (exerciseId != null && exerciseId.contains('deadlift')) ? 75 : 60;

  /// Roughly how long the ramp will take, for the session time budget.
  static int estimatedSeconds(List<RampSet> sets) =>
      sets.fold(0, (a, s) => a + (s.reps * 3) + s.restSec);
}
