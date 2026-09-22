import '../progression/logged_set.dart';

/// One estimated maximum, from one set.
class E1rmPoint {
  const E1rmPoint({
    required this.date,
    required this.e1rmKg,
    required this.weightKg,
    required this.reps,
  });

  final DateTime date;

  /// **An estimate.** Epley, from a working set. Every surface that shows
  /// this must say so — it has never been lifted, and above about eight reps
  /// the formula flatters you.
  final double e1rmKg;

  final double weightKg;
  final int reps;

  String get setLabel => '${_kg(weightKg)} x $reps';

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// One week of work on one exercise.
class WeeklyVolume {
  const WeeklyVolume({
    required this.weekNo,
    required this.workingSets,
    required this.reps,
    required this.tonnageKg,
  });

  final int weekNo;
  final int workingSets;
  final int reps;

  /// Reps x load, summed. A blunt instrument, but it is the only volume
  /// number that survives changing rep ranges.
  final double tonnageKg;
}

/// Pure arithmetic over logged sets.
///
/// Nothing here knows about Drift, Flutter or the programme. It takes sets
/// and gives back numbers, which is why it can be tested without a device.
class StrengthMetrics {
  const StrengthMetrics();

  /// Epley. Returns null for a set with no load or no reps — a bodyweight
  /// chin-up has no meaningful e1RM here and inventing one is worse than
  /// leaving the chart empty.
  static double? e1rm(double? weightKg, int? reps) {
    if (weightKg == null || reps == null) return null;
    if (weightKg <= 0 || reps < 1) return null;
    return weightKg * (1 + reps / 30);
  }

  /// The single best set in [sets], judged by estimated max.
  ///
  /// Deliberately not "heaviest": three reps at 40 kg beats one at 42.
  static E1rmPoint? best(Iterable<LoggedSet> sets) {
    E1rmPoint? bestSoFar;
    for (final s in sets) {
      final est = e1rm(s.loadKg, s.reps);
      if (est == null) continue;
      if (bestSoFar == null || est > bestSoFar.e1rmKg) {
        bestSoFar = E1rmPoint(
          date: s.completedAt,
          e1rmKg: est,
          weightKg: s.loadKg!,
          reps: s.reps!,
        );
      }
    }
    return bestSoFar;
  }

  /// The best set of each day, oldest first. This is the trend line.
  ///
  /// One point per day rather than per set, because five sets of the same
  /// weight make a flat cloud that hides the direction.
  static List<E1rmPoint> trend(Iterable<LoggedSet> sets) {
    final byDay = <DateTime, E1rmPoint>{};
    for (final s in sets) {
      final est = e1rm(s.loadKg, s.reps);
      if (est == null) continue;
      final day = DateTime(
        s.completedAt.year,
        s.completedAt.month,
        s.completedAt.day,
      );
      final prior = byDay[day];
      if (prior == null || est > prior.e1rmKg) {
        byDay[day] = E1rmPoint(
          date: day,
          e1rmKg: est,
          weightKg: s.loadKg!,
          reps: s.reps!,
        );
      }
    }
    final points = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// Reps x load, summed over [sets]. Sets with no load contribute nothing.
  static double tonnage(Iterable<LoggedSet> sets) {
    var total = 0.0;
    for (final s in sets) {
      final kg = s.loadKg, reps = s.reps;
      if (kg == null || reps == null) continue;
      total += kg * reps;
    }
    return total;
  }

  /// Change between the first and last point, as a fraction.
  ///
  /// Null when there is nothing to compare — two sessions is not a trend and
  /// the UI should say "not enough yet" rather than draw a line through one
  /// point.
  static double? changeFraction(List<E1rmPoint> trend) {
    if (trend.length < 2) return null;
    final first = trend.first.e1rmKg;
    if (first <= 0) return null;
    return (trend.last.e1rmKg - first) / first;
  }
}
