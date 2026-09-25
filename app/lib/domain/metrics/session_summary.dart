/// One logged set, as the summary needs it.
typedef SummarySet = ({
  String exerciseId,
  double? loadKg,
  int? reps,
  int? durationSec,
  bool warmup,
});

/// What a finished session adds up to: shown once, on the screen that ends
/// it.
class SessionSummary {
  const SessionSummary({
    required this.workingSets,
    required this.movements,
    required this.volumeKg,
    this.duration,
  });

  /// Sets that were not warm-ups.
  final int workingSets;

  /// How many different exercises those sets were of.
  final int movements;

  /// Load times reps over the working sets that had a load. Bodyweight and
  /// timed work add nothing: it is kilos on the bar, not effort.
  final double volumeKg;

  /// Start to finish. Null for a session logged from memory, and for one
  /// left open so long it cannot have been one sitting.
  final Duration? duration;

  /// Longer than this, and the clock ran on after the session ended.
  static const longest = Duration(hours: 6);

  static SessionSummary of({
    required List<SummarySet> sets,
    required DateTime? startedAt,
    required DateTime finishedAt,
  }) {
    final working = [
      for (final s in sets)
        if (!s.warmup) s,
    ];
    var volume = 0.0;
    for (final s in working) {
      final kg = s.loadKg, reps = s.reps;
      if (kg != null && reps != null) volume += kg * reps;
    }
    final took = startedAt == null ? null : finishedAt.difference(startedAt);
    return SessionSummary(
      workingSets: working.length,
      movements: {for (final s in working) s.exerciseId}.length,
      volumeKg: volume,
      duration: took == null || took.isNegative || took > longest ? null : took,
    );
  }
}
