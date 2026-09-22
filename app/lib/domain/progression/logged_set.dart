/// One previously recorded set, as the progression engine sees it.
///
/// Deliberately NOT the Drift row type: `lib/domain/` stays free of the data
/// layer, so the engine is testable without a database and the storage schema
/// can change without touching the rules.
class LoggedSet {
  const LoggedSet({
    required this.completedAt,
    this.reps,
    this.loadKg,
    this.durationSec,
    this.distanceM,
    this.rir,
    this.targetRepsMin,
    this.targetRepsMax,
    this.side,
    this.note,
  });

  final DateTime completedAt;
  final int? reps;
  final double? loadKg;
  final int? durationSec;
  final int? distanceM;
  final int? rir;

  /// What was being aimed at when this set was performed.
  ///
  /// Carried forward so a rep target that has already crept upward is not
  /// silently reset to the prescription's base range next session.
  final int? targetRepsMin;
  final int? targetRepsMax;

  final String? side;
  final String? note;

  /// The value the rep rule compares against: reps for normal work, seconds
  /// for timed work.
  int get achieved => reps ?? durationSec ?? distanceM ?? 0;
}
