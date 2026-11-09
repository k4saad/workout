import '../models/enums.dart';
import '../programme/programme_validator.dart' show Problem, ProblemSeverity;
import 'timetable.dart';

/// V22 on the phone: the week as he edits it.
///
/// tools/validate.py fails the authored file on any of these. Here, only
/// what the planner cannot use is an error: a block that ends before it
/// starts, on no day, at a place that does not exist, an id twice, a
/// semester that ends before it begins. Two things on top of each other,
/// or too little time to get from one place to the next, are warnings —
/// some weeks are like that, and the planner still lays the day out.
class TimetableValidator {
  const TimetableValidator();

  static const _gate = 'V22';

  static const _dayNames = {
    Weekday.mon: 'Mon',
    Weekday.tue: 'Tue',
    Weekday.wed: 'Wed',
    Weekday.thu: 'Thu',
    Weekday.fri: 'Fri',
    Weekday.sat: 'Sat',
    Weekday.sun: 'Sun',
  };

  static String _span(TimetableBlock b) =>
      '${formatHhmm(b.start)}–${formatHhmm(b.end)}';

  List<Problem> check(Timetable t) {
    final out = <Problem>[];
    void error(String where, String message) => out.add(
      Problem(
        severity: ProblemSeverity.error,
        gate: _gate,
        where: where,
        message: message,
      ),
    );
    void warning(String where, String message) => out.add(
      Problem(
        severity: ProblemSeverity.warning,
        gate: _gate,
        where: where,
        message: message,
      ),
    );

    if (t.lecturesTo.isBefore(t.lecturesFrom)) {
      error('lectures', 'the lecture period ends before it starts');
    }
    for (final b in t.breaks) {
      if (b.to.isBefore(b.from)) {
        error(b.name, 'the break ends before it starts');
      } else if (b.from.isBefore(t.lecturesFrom) ||
          b.to.isAfter(t.lecturesTo)) {
        warning(b.name, '${b.name} is not inside the lecture period');
      }
    }
    if (t.travelMinutes < 0 || t.travelMinutes > 120) {
      error('travel', '${t.travelMinutes} min of travel');
    }

    final seen = <String>{};
    for (final b in t.blocks) {
      if (!seen.add(b.id)) error(b.id, 'the id ${b.id} is used twice');
      if (b.title.trim().isEmpty) error(b.id, 'it has no title');
      if (b.days.isEmpty) error(b.id, '${b.title} is on no days');
      if (b.end <= b.start) {
        error(b.id, '${b.title} ends before it starts (${_span(b)})');
      }
      if (b.place != null && !t.places.containsKey(b.place)) {
        error(b.id, '${b.title} is at ${b.place}, which is not a place');
      }
    }

    for (final w in Weekday.values) {
      for (final m in _dayClashes(t, w)) {
        warning(_dayNames[w]!, m.$3);
      }
    }
    return out;
  }

  /// What [b] runs into in [t]: each block it is on top of, and each one
  /// too close to get to or from, on each of its days.
  List<String> clashes(Timetable t, TimetableBlock b) => [
    for (final w in b.days)
      for (final m in _dayClashes(t, w, only: b)) '${_dayNames[w]} · ${m.$3}',
  ];

  /// Pairs on [w] that cannot both be kept: on top of each other, or with
  /// too little time between two places. With [only], the pairs it is in;
  /// [only] stands in for the block of its id, so a block being edited is
  /// checked as it will be saved.
  List<(TimetableBlock, TimetableBlock, String)> _dayClashes(
    Timetable t,
    Weekday w, {
    TimetableBlock? only,
  }) {
    final day = [
      for (final x in t.blocks)
        if (x.id != only?.id && x.isOn(w) && x.end > x.start) x,
      if (only != null && only.end > only.start) only,
    ]..sort((a, c) => a.start.compareTo(c.start));
    final out = <(TimetableBlock, TimetableBlock, String)>[];
    bool wanted(TimetableBlock a, TimetableBlock c) =>
        only == null || identical(a, only) || identical(c, only);

    for (var i = 0; i < day.length; i++) {
      for (var j = i + 1; j < day.length; j++) {
        final a = day[i], c = day[j];
        if (c.start >= a.end) break;
        if (wanted(a, c)) {
          out.add((
            a,
            c,
            '${c.title} ${_span(c)} is on top of ${a.title} ${_span(a)}',
          ));
        }
      }
    }

    // Travel: between consecutive blocks that are somewhere.
    final placed = [
      for (final x in day)
        if (x.place != null) x,
    ];
    for (var i = 1; i < placed.length; i++) {
      final a = placed[i - 1], c = placed[i];
      final gap = c.start - a.end;
      if (a.place == c.place || gap < 0 || gap >= t.travelMinutes) continue;
      if (!wanted(a, c)) continue;
      out.add((
        a,
        c,
        '$gap min from ${a.title} to ${c.title}, under the '
            '${t.travelMinutes} min it takes to get there',
      ));
    }
    return out;
  }
}
