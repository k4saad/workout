/// Where the live pace sits against his own easy pace.
enum PaceZone {
  /// No band yet: too few easy runs to know what easy is for him.
  none,

  /// Faster than his easy pace. The programme's runs get longer, never
  /// faster.
  easeOff,
  onPace,

  /// Slower than easy: fine on a hill, a nudge on the flat.
  pickUp,
}

/// His own easy pace, from his own recent easy runs.
///
/// Deliberately not a number typed into the programme: "easy" is
/// conversational, and for a beginner that is whatever his last few easy
/// runs were. The band is the median, plus or minus 6 %.
class PaceBand {
  const PaceBand(this.fastSecPerKm, this.slowSecPerKm);

  final double fastSecPerKm;
  final double slowSecPerKm;

  /// Null with fewer than two runs: one run is not a habit.
  static PaceBand? fromHistory(List<double> easyPacesSecPerKm) {
    final paces = [
      for (final p in easyPacesSecPerKm)
        if (p.isFinite && p > 0) p,
    ]..sort();
    if (paces.length < 2) return null;
    final mid = paces.length ~/ 2;
    final median = paces.length.isOdd
        ? paces[mid]
        : (paces[mid - 1] + paces[mid]) / 2;
    return PaceBand(median * 0.94, median * 1.06);
  }

  PaceZone judge(double? paceSecPerKm) {
    if (paceSecPerKm == null || !paceSecPerKm.isFinite) return PaceZone.none;
    if (paceSecPerKm < fastSecPerKm) return PaceZone.easeOff;
    if (paceSecPerKm > slowSecPerKm) return PaceZone.pickUp;
    return PaceZone.onPace;
  }
}

/// What the programme asked for: so many minutes, or so many metres.
sealed class RunTarget {
  const RunTarget();

  const factory RunTarget.duration(int seconds) = DurationTarget;
  const factory RunTarget.distance(int metres) = DistanceTarget;

  /// 0..1.
  double progress({required int movingMs, required double distanceM});

  String remainingLabel({required int movingMs, required double distanceM});

  bool done({required int movingMs, required double distanceM}) =>
      progress(movingMs: movingMs, distanceM: distanceM) >= 1;
}

final class DurationTarget extends RunTarget {
  const DurationTarget(this.seconds);

  final int seconds;

  @override
  double progress({required int movingMs, required double distanceM}) =>
      seconds <= 0 ? 1 : (movingMs / 1000 / seconds).clamp(0.0, 1.0);

  @override
  String remainingLabel({required int movingMs, required double distanceM}) {
    final left = seconds * 1000 - movingMs;
    return left <= 0 ? 'Done' : '${formatClock(left)} to go';
  }
}

final class DistanceTarget extends RunTarget {
  const DistanceTarget(this.metres);

  final int metres;

  @override
  double progress({required int movingMs, required double distanceM}) =>
      metres <= 0 ? 1 : (distanceM / metres).clamp(0.0, 1.0);

  @override
  String remainingLabel({required int movingMs, required double distanceM}) {
    final left = metres - distanceM;
    return left <= 0 ? 'Done' : '${formatKm(left)} km to go';
  }
}

/// Minutes and seconds per kilometre: `5:32`.
String formatPace(double? secPerKm) {
  if (secPerKm == null || !secPerKm.isFinite || secPerKm <= 0) return '–:––';
  final total = secPerKm.round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// A stopwatch: `25:07`, or `1:02:05` past the hour.
String formatClock(int ms) {
  final s = (ms < 0 ? 0 : ms) ~/ 1000;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// Kilometres to two places: `3.42`.
String formatKm(double metres) => (metres / 1000).toStringAsFixed(2);
