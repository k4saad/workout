import '../models/enums.dart';
import '../models/inventory.dart';
import 'lattice.dart';

/// A count of one plate size on one side of the bar.
class PlateCount {
  const PlateCount(this.kg, this.count);

  final double kg;
  final int count;

  @override
  String toString() => count == 1 ? _fmt(kg) : '${_fmt(kg)} × $count';

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// What to actually put on the bar.
class PlateSolution {
  const PlateSolution({
    required this.targetKg,
    required this.achievableKg,
    required this.mode,
    required this.perSide,
    required this.breakdown,
    this.nextUpKg,
    this.smallestStepKg,
    this.microplateHint,
    this.warning,
    this.isBelowBar = false,
  });

  final double targetKg;

  /// The closest buildable weight at or BELOW the target.
  final double achievableKg;

  final LoadMode mode;
  final List<PlateCount> perSide;

  /// Readable while loading: "27 kg = bar 9 + (5 + 2.5 + 1.25) per side".
  final String breakdown;

  /// The next weight up, so the UI can offer both. Null at the top of what
  /// the plates can build.
  final double? nextUpKg;

  final double? smallestStepKg;

  /// Set when the smallest jump is more than 5% of the load. This is how the
  /// app tells you what to buy.
  final String? microplateHint;

  final String? warning;

  /// The target was lighter than the bare implement. You cannot deload an
  /// empty bar.
  final bool isBelowBar;

  bool get isExact => (achievableKg - targetKg).abs() < 1e-6;

  /// Negative when the solution is lighter than asked for.
  double get deltaFromTarget =>
      double.parse((achievableKg - targetKg).toStringAsFixed(3));

  @override
  String toString() => breakdown;
}

/// Which plate sizes cannot go round, given everything a session needs at once.
class ContentionReport {
  const ContentionReport({required this.shortfall, this.message});

  /// plate size -> how many more of that size would be needed.
  final Map<double, int> shortfall;
  final String? message;

  bool get isContended => shortfall.isNotEmpty;
}

/// Turns a target weight into plates you actually own.
///
/// Every commercial app assumes infinite Olympic plates and rounds to 2.5 kg.
/// This one knows the collection is finite, that a dumbbell PAIR eats four
/// plates of each size, and that a weight off the lattice does not exist.
///
/// Pure. No I/O.
class PlateSolver {
  PlateSolver(this.inventory) : lattice = Lattice(inventory);

  final Inventory inventory;
  final Lattice lattice;

  static const _eps = 1e-6;

  /// Fires the microplate hint above this fraction of the current load.
  static const microplateThreshold = 0.05;

  List<({double kg, int count})> budgetFor(LoadMode mode) =>
      inventory.budgetFor(mode);

  bool isValid(double kg, LoadMode mode) => lattice.isValid(kg, mode);

  double? smallestStepAt(double kg, LoadMode mode) =>
      lattice.smallestStepAt(kg, mode);

  double? maxFor(LoadMode mode) => lattice.maxFor(mode);

  /// Snaps [target] down to a buildable weight and says how to build it.
  PlateSolution solve(double target, LoadMode mode) {
    if (mode == LoadMode.kettlebell) return _solveKettlebell(target);

    if (!mode.isPlateLoaded) {
      // Bodyweight, bands, cable, timed, distance: nothing to load.
      return PlateSolution(
        targetKg: target,
        achievableKg: target,
        mode: mode,
        perSide: const [],
        breakdown: _nonPlateLabel(mode),
      );
    }

    final base = inventory.baseWeightFor(mode);
    final values = lattice.values(mode);

    if (values.isEmpty) {
      return PlateSolution(
        targetKg: target,
        achievableKg: base,
        mode: mode,
        perSide: const [],
        breakdown: 'bar only — no plates configured',
        warning:
            'No plates in the inventory. Add the plates you own under '
            'Settings → Your equipment.',
      );
    }

    final max = values.last;
    String? warning;
    var isBelowBar = false;

    double achievable;
    if (target < base - _eps) {
      achievable = base;
      isBelowBar = true;
      warning =
          'That is lighter than the bare ${_implementName(mode)} '
          '(${PlateCount._fmt(base)} kg). You cannot go lighter than the bar.';
    } else if (target > max + _eps) {
      achievable = max;
      warning =
          'That is more than your plates can build. '
          '${PlateCount._fmt(max)} kg is the heaviest ${_implementName(mode)} '
          'in this gym.';
    } else {
      achievable = lattice.snapDown(target, mode);
    }

    final perSide = _perSide((achievable - base) / 2, mode);
    final step = lattice.smallestStepAt(achievable, mode);
    // Derived from the step rather than snapUp: snapUp is inclusive, so
    // snapping up from a value already on the lattice returns that value.
    final nextUp = step == null
        ? null
        : double.parse((achievable + step).toStringAsFixed(3));

    String? hint;
    if (step != null &&
        achievable > 0 &&
        step > achievable * microplateThreshold) {
      final pct = (step / achievable * 100).round();
      hint =
          'Smallest jump here is ${PlateCount._fmt(step)} kg — $pct% of '
          'the load. A pair of lighter microplates would fix that.';
    }

    return PlateSolution(
      targetKg: target,
      achievableKg: achievable,
      mode: mode,
      perSide: perSide,
      breakdown: _breakdown(achievable, base, perSide, mode),
      nextUpKg: nextUp,
      smallestStepKg: step,
      microplateHint: hint,
      warning: warning,
      isBelowBar: isBelowBar,
    );
  }

  PlateSolution _solveKettlebell(double target) {
    final bells = [...inventory.kettlebells]..sort();
    if (bells.isEmpty) {
      return PlateSolution(
        targetKg: target,
        achievableKg: target,
        mode: LoadMode.kettlebell,
        perSide: const [],
        breakdown: 'kettlebell',
        warning: 'No kettlebells configured.',
      );
    }
    final below = bells.where((b) => b <= target + _eps).toList();
    final chosen = below.isNotEmpty ? below.last : bells.first;
    final above = bells.where((b) => b > chosen + _eps).toList();
    return PlateSolution(
      targetKg: target,
      achievableKg: chosen,
      mode: LoadMode.kettlebell,
      perSide: const [],
      breakdown: '${PlateCount._fmt(chosen)} kg kettlebell',
      nextUpKg: above.isNotEmpty ? above.first : null,
      warning: bells.length == 1
          ? 'Only one kettlebell in the inventory, so this lift cannot '
                'progress by load. Add reps or use a dumbbell.'
          : null,
    );
  }

  final Map<LoadMode, Map<int, List<PlateCount>>> _perSideCache = {};

  /// The plates for one side: an EXACT search over what one side owns.
  ///
  /// Fewest plates first; among equally few, the most of the biggest size,
  /// then the next — the same rule as `breakdown()` in tools/gen.py, so the
  /// app and the programme doc list the same iron.
  ///
  /// Not greedy. Largest-first only works when every size divides the next
  /// one up, and 1.25 kg next to 1.0 kg does not: greedy loads a 2 kg side
  /// as 1.25 + 0.5 and is a quarter-kilo short, so the app said "14 kg" and
  /// listed 13.5 kg of plates.
  List<PlateCount> _perSide(double perSideKg, LoadMode mode) {
    final target = (perSideKg * 1000).round();
    if (target <= 0) return const [];
    return (_perSideCache[mode] ??= {}).putIfAbsent(
      target,
      () => _search(target, inventory.budgetFor(mode)),
    );
  }

  static List<PlateCount> _search(
    int target,
    List<({double kg, int count})> budget,
  ) {
    final grams = [for (final b in budget) (b.kg * 1000).round()];
    // What the sizes from i onwards can add at most: prunes dead branches.
    final reach = List<int>.filled(budget.length + 1, 0);
    for (var i = budget.length - 1; i >= 0; i--) {
      reach[i] = reach[i + 1] + grams[i] * budget[i].count;
    }

    List<int>? best;
    var bestPlates = 1 << 30;
    final counts = List<int>.filled(budget.length, 0);

    // Depth-first, largest size first, most plates of it first: the counts
    // come out in descending lexicographic order, so the first exact answer
    // found at a given plate count is the one that prefers bigger plates.
    void walk(int i, int remaining, int plates) {
      if (remaining == 0) {
        if (plates < bestPlates) {
          bestPlates = plates;
          best = [...counts];
        }
        return;
      }
      if (i == budget.length || plates >= bestPlates) return;
      if (remaining > reach[i]) return;
      final most = remaining ~/ grams[i];
      for (
        var n = most < budget[i].count ? most : budget[i].count;
        n >= 0;
        n--
      ) {
        counts[i] = n;
        walk(i + 1, remaining - n * grams[i], plates + n);
      }
      counts[i] = 0;
    }

    walk(0, target, 0);

    final found = best;
    if (found == null) return const []; // off the lattice: nothing exact
    return List.unmodifiable([
      for (var i = 0; i < budget.length; i++)
        if (found[i] > 0) PlateCount(budget[i].kg, found[i]),
    ]);
  }

  String _breakdown(
    double total,
    double base,
    List<PlateCount> perSide,
    LoadMode mode,
  ) {
    final t = PlateCount._fmt(total);
    final b = PlateCount._fmt(base);
    if (perSide.isEmpty) {
      return '$t kg = bar only ($b kg)';
    }
    final plates = perSide.map((p) => p.toString()).join(' + ');
    final per = mode == LoadMode.dumbbellPair
        ? 'per side, both dumbbells'
        : 'per side';
    return '$t kg = bar $b + ($plates) $per';
  }

  static String _implementName(LoadMode mode) => switch (mode) {
    LoadMode.barbell => 'barbell',
    LoadMode.ezBar => 'EZ bar',
    LoadMode.dumbbellPair || LoadMode.dumbbellSingle => 'dumbbell handle',
    _ => 'implement',
  };

  static String _nonPlateLabel(LoadMode mode) => switch (mode) {
    LoadMode.bodyweight || LoadMode.bodyweightLoaded => 'bodyweight',
    LoadMode.banded => 'band',
    LoadMode.cable => 'cable',
    LoadMode.timed => 'timed',
    LoadMode.distance => 'distance',
    _ => '—',
  };

  /// Whether everything a session needs can be loaded at the same time.
  ///
  /// You own one plate set. A day that loads the barbell AND a pair of
  /// dumbbells wants the same 5 kg plates in two places. Warn, never block —
  /// you will just re-plate between movements, but you should know before you
  /// start rather than discovering it mid-superset.
  ContentionReport contention(List<({double kg, LoadMode mode})> simultaneous) {
    final needed = <double, int>{};

    for (final item in simultaneous) {
      if (!item.mode.isPlateLoaded) continue;
      final base = inventory.baseWeightFor(item.mode);
      // What that load actually takes, not a nearby weight's plates: snap
      // first, so an off-lattice request still counts real iron.
      final kg = lattice.snapDown(item.kg, item.mode);
      final perSide = _perSide((kg - base) / 2, item.mode);
      final multiplier = inventory.platesConsumedPer(item.mode);
      for (final p in perSide) {
        needed[p.kg] = (needed[p.kg] ?? 0) + p.count * multiplier;
      }
    }

    final owned = {for (final p in inventory.plates) p.weightKg: p.count};

    final shortfall = <double, int>{};
    needed.forEach((kg, count) {
      final have = owned[kg] ?? 0;
      if (count > have) shortfall[kg] = count - have;
    });

    if (shortfall.isEmpty) return const ContentionReport(shortfall: {});

    final parts = shortfall.entries
        .map((e) => '${e.value} more ${PlateCount._fmt(e.key)} kg')
        .join(', ');
    return ContentionReport(
      shortfall: shortfall,
      message:
          'These cannot all be loaded at once — you are short $parts. '
          'Re-plate between movements, or drop one of them a notch.',
    );
  }
}
