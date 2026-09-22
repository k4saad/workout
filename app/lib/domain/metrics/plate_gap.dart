import '../models/enums.dart';
import '../models/inventory.dart';
import '../plates/lattice.dart';

/// How coarse the plates are for one movement at one working weight.
class PlateGap {
  const PlateGap({
    required this.exerciseId,
    required this.loadMode,
    required this.currentKg,
    required this.stepKg,
  });

  final String exerciseId;
  final LoadMode loadMode;
  final double currentKg;

  /// The smallest increase the plates can make from [currentKg].
  final double stepKg;

  /// That step as a fraction of the current load. This is the number that
  /// matters: 2.5 kg is nothing on a deadlift and 19% on an overhead press.
  double get fraction => currentKg <= 0 ? 0 : stepKg / currentKg;

  int get percent => (fraction * 100).round();

  /// Above this, the next jump is too big to train through and the engine
  /// rep-creeps instead. Useful progress stops until the plates get finer.
  bool get isCoarse => fraction > PlateGapReport.coarseThreshold;
}

/// What to buy, and why.
///
/// The honest version of "the app says you are stalling": sometimes you are
/// not stalling, the smallest plate you own is simply too big.
class PlateGapReport {
  const PlateGapReport({required this.gaps, required this.suggestedPlateKg});

  final List<PlateGap> gaps;

  /// The plate size that would bring every coarse lift back under the
  /// threshold, or null when nothing needs buying.
  final double? suggestedPlateKg;

  List<PlateGap> get coarse =>
      gaps.where((g) => g.isCoarse).toList(growable: false);

  bool get isClean => coarse.isEmpty;

  /// Fires when one lattice step is a bigger jump than this.
  static const double coarseThreshold = 0.10;

  /// Plate sizes worth suggesting. Anything finer than 0.25 kg is a rounding
  /// error on a barbell and anything coarser is already owned.
  static const List<double> candidatePlates = [1.0, 0.5, 0.25];

  /// [currentLoads] is exercise id -> the weight being used now.
  static PlateGapReport build({
    required Inventory inventory,
    required Map<String, ({double kg, LoadMode mode})> currentLoads,
  }) {
    final lattice = Lattice(inventory);
    final gaps = <PlateGap>[];

    currentLoads.forEach((exerciseId, load) {
      if (!load.mode.isPlateLoaded) return;
      final step = lattice.smallestStepAt(load.kg, load.mode);
      if (step == null) return;
      gaps.add(
        PlateGap(
          exerciseId: exerciseId,
          loadMode: load.mode,
          currentKg: load.kg,
          stepKg: step,
        ),
      );
    });

    gaps.sort((a, b) => b.fraction.compareTo(a.fraction));

    final worst = gaps.where((g) => g.isCoarse).toList();
    double? suggestion;
    if (worst.isNotEmpty) {
      // A pair of plates adds 2x their weight to the bar, so the step a size
      // buys is twice the plate.
      for (final plate in candidatePlates) {
        final step = plate * 2;
        if (worst.every((g) => step / g.currentKg <= coarseThreshold)) {
          suggestion = plate;
          break;
        }
      }
      // Nothing on the list is fine enough; recommend the finest anyway.
      suggestion ??= candidatePlates.last;
    }

    return PlateGapReport(gaps: gaps, suggestedPlateKg: suggestion);
  }
}
