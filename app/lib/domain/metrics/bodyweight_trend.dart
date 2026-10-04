import '../models/programme.dart';

/// One weigh-in.
class WeightEntry {
  const WeightEntry({required this.date, required this.kg});

  final DateTime date;
  final double kg;
}

/// A rolling-average point.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.raw,
    required this.average,
    required this.sampleCount,
  });

  final DateTime date;

  /// What the scale actually said.
  final double raw;

  /// The rolling average over the window ending on this date.
  final double average;

  /// How many weigh-ins went into it. A one-sample average is just the
  /// reading, and the UI should not pretend otherwise.
  final int sampleCount;

  bool get isReliable => sampleCount >= 3;
}

/// What the nutrition rule says to do next.
enum NutritionVerdict {
  /// Not enough data, or too early in the block, to say anything.
  tooEarly,

  /// Gaining at roughly the target rate. Leave it alone.
  onTrack,

  /// The rolling average has not risen for long enough. Eat more.
  flat,

  /// Gaining faster than intended.
  tooFast,

  /// Losing weight while trying to gain.
  losing,

  /// The scale says eat more, but the plan is not being eaten: the calories
  /// are already on the plate. Eat the plan first.
  offPlan,

  /// A calorie change went in recently and has not had its weeks on the
  /// scale yet. Changing again now is chasing noise.
  settling,
}

class NutritionAdvice {
  const NutritionAdvice({
    required this.verdict,
    required this.message,
    this.kcalDelta = 0,
    this.flatWeeks = 0,
    this.weeklyChangeKg,
  });

  final NutritionVerdict verdict;
  final String message;

  /// How much to change the daily target by. Zero means no change.
  final int kcalDelta;

  final int flatWeeks;
  final double? weeklyChangeKg;

  bool get needsAction => kcalDelta != 0;
}

/// Bodyweight trend and the eat-more rule.
///
/// Everything here runs on the ROLLING AVERAGE, never the daily reading.
/// Bodyweight swings a kilo on water and gut content; a rule that reacts to
/// a single morning makes you chase noise, and at 50 kg trying to gain, that
/// is the difference between a programme that works and one that does not.
class BodyweightTrend {
  const BodyweightTrend({this.windowDays = 7});

  final int windowDays;

  /// Rolling average over [windowDays], one point per weigh-in.
  ///
  /// The window is by DATE, not by sample count: missing three days in a row
  /// should widen the uncertainty, not silently reach further back.
  List<TrendPoint> points(List<WeightEntry> entries) {
    if (entries.isEmpty) return const [];
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

    return [
      for (final e in sorted)
        () {
          final from = _daysBefore(_dateOnly(e.date), windowDays - 1);
          final window = sorted.where(
            (x) =>
                !_dateOnly(x.date).isBefore(from) &&
                !_dateOnly(x.date).isAfter(_dateOnly(e.date)),
          );
          final vals = window.map((x) => x.kg).toList();
          return TrendPoint(
            date: _dateOnly(e.date),
            raw: e.kg,
            average: vals.reduce((a, b) => a + b) / vals.length,
            sampleCount: vals.length,
          );
        }(),
    ];
  }

  /// The most recent rolling average, or null with no data.
  double? currentAverage(List<WeightEntry> entries) {
    final p = points(entries);
    return p.isEmpty ? null : p.last.average;
  }

  /// Change in the rolling average per week, over the last [overWeeks].
  double? weeklyChange(List<WeightEntry> entries, {int overWeeks = 2}) {
    final p = points(entries);
    if (p.length < 2) return null;

    final last = p.last;
    final cutoff = _daysBefore(last.date, overWeeks * 7);
    final earlier = p.where((x) => !x.date.isAfter(cutoff)).toList();
    final first = earlier.isNotEmpty ? earlier.last : p.first;

    final days = _daysBetween(first.date, last.date);
    if (days <= 0) return null;
    return (last.average - first.average) / days * 7;
  }

  /// How many consecutive weeks the rolling average has failed to rise.
  ///
  /// "Rise" allows a small tolerance so that scale noise inside a genuine
  /// plateau does not reset the counter and hide the plateau.
  ///
  /// With [since] — the day a calorie change went in — only the weeks after
  /// it count: the weeks that made the case for that change have been
  /// answered, and must not make it again.
  int flatWeeks(
    List<WeightEntry> entries, {
    double toleranceKg = 0.1,
    DateTime? since,
  }) {
    final p = points(entries);
    if (p.length < 2) return 0;

    final last = p.last;
    var weeks = 0;
    for (var w = 1; w <= 12; w++) {
      final at = _daysBefore(last.date, w * 7);
      if (since != null && at.isBefore(_dateOnly(since))) break;
      final earlier = p.where((x) => !x.date.isAfter(at)).toList();
      if (earlier.isEmpty) break;
      final ref = earlier.last;
      if (last.average - ref.average > toleranceKg) break;
      weeks = w;
    }
    return weeks;
  }

  /// The share of planned meals eaten below which "eat more" becomes "eat
  /// the plan".
  static const adherenceFloor = 0.85;

  /// What to do about the food, given the programme's own rules.
  ///
  /// [adherence] is the share of the logged meals actually eaten over the
  /// last fortnight (null when nothing was logged: then the scale alone
  /// decides). [lastAdjustedOn] is the day the most recent calorie change
  /// went in: for the programme's flat-weeks span after it, no new change
  /// is asked for, and the flat count starts again from it.
  NutritionAdvice advise(
    List<WeightEntry> entries,
    NutritionRules rules, {
    double? waistChangeCm,
    double? adherence,
    DateTime? lastAdjustedOn,
  }) {
    final p = points(entries);
    final settled = lastAdjustedOn == null
        ? null
        : DateTime(
            lastAdjustedOn.year,
            lastAdjustedOn.month,
            lastAdjustedOn.day + rules.flatWeeksBeforeBump * 7,
          );
    final settling =
        settled != null && p.isNotEmpty && p.last.date.isBefore(settled);

    // While settling, ask the whole history whether the scale wants a
    // change; after, count only from the change that answered the last one.
    final advice = _advise(
      entries,
      rules,
      waistChangeCm: waistChangeCm,
      since: settling ? null : lastAdjustedOn,
    );
    if (!advice.needsAction) return advice;

    if (settling) {
      final weeks = rules.flatWeeksBeforeBump;
      return NutritionAdvice(
        verdict: NutritionVerdict.settling,
        message:
            'The last calorie change is still settling in. Give it '
            '$weeks week${weeks == 1 ? '' : 's'} on the scale before '
            'changing the food again.',
        flatWeeks: advice.flatWeeks,
        weeklyChangeKg: advice.weeklyChangeKg,
      );
    }
    if (advice.kcalDelta > 0 &&
        adherence != null &&
        adherence < adherenceFloor) {
      final pct = (adherence * 100).round();
      return NutritionAdvice(
        verdict: NutritionVerdict.offPlan,
        message:
            'You ate $pct% of the planned meals over the last two weeks. '
            'The calories are already in the plan: eat it before adding '
            'more.',
        flatWeeks: advice.flatWeeks,
        weeklyChangeKg: advice.weeklyChangeKg,
      );
    }
    return advice;
  }

  NutritionAdvice _advise(
    List<WeightEntry> entries,
    NutritionRules rules, {
    double? waistChangeCm,
    DateTime? since,
  }) {
    final p = points(entries);
    if (p.length < 4) {
      return const NutritionAdvice(
        verdict: NutritionVerdict.tooEarly,
        message:
            'Weigh in most mornings for a couple of weeks. A single reading '
            'says nothing; the rolling average is what decides anything.',
      );
    }

    // The waist rule is the counterweight to the flat rule: gaining is the
    // goal, but not if it is mostly going on the waist.
    if (waistChangeCm != null && waistChangeCm > rules.waistGrowthLimitCm) {
      return NutritionAdvice(
        verdict: NutritionVerdict.tooFast,
        message:
            'Waist is up ${waistChangeCm.toStringAsFixed(1)} cm, past the '
            '${rules.waistGrowthLimitCm.toStringAsFixed(0)} cm limit. That is '
            'the surplus running ahead of what you can build. '
            'Cut ${rules.kcalCutWhenWaistGrows} kcal.',
        kcalDelta: -rules.kcalCutWhenWaistGrows,
        weeklyChangeKg: weeklyChange(entries),
      );
    }

    final flat = flatWeeks(entries, since: since);
    final change = weeklyChange(entries);

    // Losing is checked BEFORE flat. Going backwards also reads as "not
    // rising", so flat would otherwise swallow it — and "you are losing
    // weight" is the more useful sentence than "you are flat".
    if (change != null && change < -0.1) {
      return NutritionAdvice(
        verdict: NutritionVerdict.losing,
        message:
            'Losing ${change.abs().toStringAsFixed(2)} kg a week. At your '
            'weight that is the four meals not all happening — a long day '
            'that skipped lunch is the usual culprit.',
        kcalDelta: rules.kcalBumpWhenFlat,
        flatWeeks: flat,
        weeklyChangeKg: change,
      );
    }

    if (flat >= rules.flatWeeksBeforeBump) {
      return NutritionAdvice(
        verdict: NutritionVerdict.flat,
        message:
            'Flat for $flat weeks. At your bodyweight that is a food problem '
            '100% of the time, never a training one. '
            'Add ${rules.kcalBumpWhenFlat} kcal a day.',
        kcalDelta: rules.kcalBumpWhenFlat,
        flatWeeks: flat,
        weeklyChangeKg: change,
      );
    }

    if (change != null && change > rules.gainKgPerWeek * 2) {
      return NutritionAdvice(
        verdict: NutritionVerdict.tooFast,
        message:
            'Up ${change.toStringAsFixed(2)} kg a week, against a target of '
            '${rules.gainKgPerWeek}. Not a disaster, but check the waist at '
            'the next checkpoint.',
        weeklyChangeKg: change,
      );
    }

    return NutritionAdvice(
      verdict: NutritionVerdict.onTrack,
      message: change == null
          ? 'Keep weighing in.'
          : 'Up ${change.toStringAsFixed(2)} kg a week. That is the plan — '
                'leave the food alone.',
      weeklyChangeKg: change,
    );
  }

  /// Projected bodyweight at [weeks] from now, at the current rate.
  double? project(List<WeightEntry> entries, int weeks) {
    final avg = currentAverage(entries);
    final rate = weeklyChange(entries);
    if (avg == null || rate == null) return null;
    return avg + rate * weeks;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [n] calendar days before [d]. Not `subtract(Duration(days: n))`: a
  /// Duration is hours, and the weekend the clocks change has a 23- or
  /// 25-hour day, which lands the result an hour off midnight — and drops
  /// or adds a weigh-in at the edge of the window.
  static DateTime _daysBefore(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day - n);

  /// Calendar days from [a] to [b], counted in UTC so a clock change in
  /// between is not an hour short of a day.
  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
