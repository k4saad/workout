import 'adherence.dart';

/// The small signs a calendar day carries besides its session.
enum DayMarker { shoot, run, weighIn, fed }

/// What else happened on a date: a run, a weigh-in, the meals eaten, a
/// photo shoot.
class DayMarkers {
  const DayMarkers({
    this.ran = false,
    this.weighed = false,
    this.fed = false,
    this.shoot = false,
  });

  final bool ran;
  final bool weighed;

  /// Enough of the day's meals eaten (see [mealsHit]).
  final bool fed;
  final bool shoot;

  bool get isEmpty => !ran && !weighed && !fed && !shoot;

  /// In the order a small cell shows them: the rarest, most telling first.
  List<DayMarker> get ordered => [
    if (shoot) DayMarker.shoot,
    if (ran) DayMarker.run,
    if (weighed) DayMarker.weighIn,
    if (fed) DayMarker.fed,
  ];
}

/// A day counts as fed when the meals eaten — a half as a half — reach
/// [threshold] of the meals planned for it. The same 85 % the Fuel tab
/// calls good enough.
bool mealsHit({
  required double eatenPortions,
  required int plannedMeals,
  double threshold = 0.85,
}) => plannedMeals > 0 && eatenPortions >= plannedMeals * threshold - 1e-9;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The markers for every date that has any, keyed by the date alone.
Map<DateTime, DayMarkers> markersFor({
  Iterable<DateTime> runDays = const [],
  Iterable<DateTime> weighDays = const [],
  Iterable<DateTime> shootDays = const [],
  Iterable<DateTime> fedDays = const [],
}) {
  final ran = {for (final d in runDays) _day(d)};
  final weighed = {for (final d in weighDays) _day(d)};
  final shoot = {for (final d in shootDays) _day(d)};
  final fed = {for (final d in fedDays) _day(d)};
  return {
    for (final d in {...ran, ...weighed, ...shoot, ...fed})
      d: DayMarkers(
        ran: ran.contains(d),
        weighed: weighed.contains(d),
        fed: fed.contains(d),
        shoot: shoot.contains(d),
      ),
  };
}

/// A month in one line: sessions against what was due, and the rest.
class MonthSummary {
  const MonthSummary({
    required this.sessionsDone,
    required this.sessionsDue,
    required this.missed,
    required this.skipped,
    this.runs = 0,
    this.km = 0,
    this.weighIns = 0,
    this.weightChangeKg,
    this.shoots = 0,
    this.fedDays = 0,
  });

  /// Required sessions turned up for (a partial counts).
  final int sessionsDone;

  /// Required sessions that were due by now: the past ones, plus any
  /// already dealt with today or ahead of time.
  final int sessionsDue;
  final int missed;
  final int skipped;
  final int runs;
  final double km;
  final int weighIns;

  /// Last weigh-in of the month minus the first; null with fewer than two.
  final double? weightChangeKg;
  final int shoots;
  final int fedDays;

  static MonthSummary of({
    required List<CalendarEntry> entries,
    required DateTime month,
    required DateTime today,
    List<double> runKm = const [],
    List<(DateTime, double)> weighIns = const [],
    int shoots = 0,
    int fedDays = 0,
  }) {
    final tally = SessionTally.of(
      entries.where(
        (e) => e.date.year == month.year && e.date.month == month.month,
      ),
      today,
    );

    final weights = [...weighIns]..sort((a, b) => a.$1.compareTo(b.$1));
    return MonthSummary(
      sessionsDone: tally.done,
      sessionsDue: tally.due,
      missed: tally.missed,
      skipped: tally.skipped,
      runs: runKm.length,
      km: runKm.fold(0.0, (a, k) => a + k),
      weighIns: weights.length,
      weightChangeKg: weights.length < 2
          ? null
          : weights.last.$2 - weights.first.$2,
      shoots: shoots,
      fedDays: fedDays,
    );
  }
}
