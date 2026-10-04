import '../models/block.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/programme.dart';
import '../programme/block_resolver.dart';

/// Where a date sits relative to the programme.
enum ProgrammeStatus {
  /// Earlier than the programme's first week.
  before,

  /// Inside weeks 1..totalWeeks.
  active,

  /// Past the last week. The app must have something to say here — v1 returned
  /// null forever and the calendar simply went blank (audit C8).
  complete,
}

/// A date resolved against the programme.
class PlannedDay {
  const PlannedDay({
    required this.date,
    required this.status,
    this.weekNo,
    this.block,
    this.day,
  });

  final DateTime date;
  final ProgrammeStatus status;

  /// 1-based programme week. Null outside the programme.
  final int? weekNo;

  final Block? block;

  /// Null when the block defines no day for this weekday, or when the date
  /// falls before `startDate` inside week 1.
  final Day? day;

  bool get isActive => status == ProgrammeStatus.active;
  bool get hasSession => day != null && day!.isTrainingDay;
  bool get isRest => day != null && day!.kind == DayKind.rest;

  Weekday get weekday => Weekday.fromDateTime(date);

  @override
  String toString() =>
      'PlannedDay(${date.toIso8601String().substring(0, 10)}, '
      '${status.name}, week $weekNo, ${day?.id})';
}

/// Projects programme weeks onto real dates.
///
/// Pure. No I/O, no database. The calendar screen merges the output of this
/// with actual `sessions` rows; this half never needs to know what you did,
/// only what was planned.
class ProgrammeCalendar {
  ProgrammeCalendar(this.programme)
    : _resolver = BlockResolver(programme),
      _anchor = programme.anchorMonday;

  final Programme programme;
  final BlockResolver _resolver;
  final DateTime _anchor;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Calendar-day arithmetic.
  ///
  /// NOT `DateTime.add(Duration(days: n))`. Duration is absolute time, so on
  /// the night the clocks change a "day" is 23 or 25 hours and a midnight
  /// DateTime slides onto the previous or next date. Germany's DST transition
  /// falls inside every autumn run of this programme, which silently shifted
  /// the entire calendar by one day from week 5 onward.
  static DateTime addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// Whole calendar days from [a] to [b], DST-safe.
  static int daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Monday of the ISO week containing the programme start.
  ///
  /// Week 1 is Monday-anchored even when `startDate` falls mid-week, because
  /// the programme's days are keyed by weekday rather than by offset.
  DateTime get anchorMonday => _anchor;

  /// The 1-based programme week containing [date], which may be <1 or
  /// >totalWeeks.
  int weekNumberFor(DateTime date) {
    final diff = daysBetween(_anchor, date);
    // Floor division so dates before the anchor give week 0, -1, ...
    final weeks = diff >= 0 ? diff ~/ 7 : ((diff + 1) ~/ 7) - 1;
    return weeks + 1;
  }

  /// The first date of a programme week.
  DateTime startOfWeek(int weekNo) => addDays(_anchor, (weekNo - 1) * 7);

  /// Resolve a single date.
  PlannedDay forDate(DateTime date) {
    final d = _dateOnly(date);
    final weekNo = weekNumberFor(d);

    if (weekNo < 1) {
      return PlannedDay(date: d, status: ProgrammeStatus.before);
    }
    if (weekNo > programme.totalWeeks) {
      return PlannedDay(date: d, status: ProgrammeStatus.complete);
    }

    // Week 1 can start mid-week. Days before the real start date have no
    // session — you did not skip them, they simply were not scheduled.
    if (d.isBefore(_dateOnly(programme.startDate))) {
      return PlannedDay(
        date: d,
        status: ProgrammeStatus.active,
        weekNo: weekNo,
      );
    }

    final block = programme.blockForWeek(weekNo);
    if (block == null) {
      return PlannedDay(
        date: d,
        status: ProgrammeStatus.active,
        weekNo: weekNo,
      );
    }

    final day = _resolver.resolveDay(block, weekNo, Weekday.fromDateTime(d));
    return PlannedDay(
      date: d,
      status: ProgrammeStatus.active,
      weekNo: weekNo,
      block: block,
      day: day,
    );
  }

  /// Every date in [weekNo], Monday first. Always seven entries.
  List<PlannedDay> weekOf(int weekNo) {
    final start = startOfWeek(weekNo);
    return List.generate(7, (i) => forDate(addDays(start, i)));
  }

  /// Every date from [from] to [to] inclusive.
  ///
  /// The calendar screen calls this once per month rather than 31 times.
  List<PlannedDay> range(DateTime from, DateTime to) {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final out = <PlannedDay>[];
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      out.add(forDate(d));
    }
    return out;
  }

  /// The resolved days of [weekNo], in weekday order, excluding weekdays the
  /// block does not define.
  List<Day> sessionsInWeek(int weekNo) =>
      weekOf(weekNo).map((p) => p.day).whereType<Day>().toList();

  /// Number of required (non-optional) training sessions planned in [weekNo].
  int requiredSessionsInWeek(int weekNo) =>
      sessionsInWeek(weekNo)
          .where((d) => d.isTrainingDay && !d.optional)
          .length;

  /// The first training day strictly after [date], or null once the
  /// programme has none left. Optional days (the Sunday run) are skipped
  /// unless [includeOptional]: a rest day names the session that is due.
  PlannedDay? nextSession(DateTime date, {bool includeOptional = false}) {
    final from = _dateOnly(date).isBefore(_anchor)
        ? addDays(_anchor, -1)
        : _dateOnly(date);
    for (var d = addDays(from, 1); !d.isAfter(lastDate); d = addDays(d, 1)) {
      final p = forDate(d);
      if (p.hasSession && (includeOptional || !p.day!.optional)) return p;
    }
    return null;
  }

  /// The last date the programme covers.
  DateTime get lastDate => addDays(startOfWeek(programme.totalWeeks), 6);

  /// True once [date] is past the final week.
  bool isComplete(DateTime date) => weekNumberFor(date) > programme.totalWeeks;

  /// Shift the whole programme forward by [weeks], for when a week is
  /// genuinely lost to illness or travel.
  ///
  /// This is the honest alternative to a `rolling` schedule that never marks
  /// anything missed but silently desynchronises the week numbers from the
  /// cardio table.
  Programme shiftedBy(int weeks) => programme.copyWith(
    startDate: addDays(programme.startDate, weeks * 7),
    revision: programme.revision + 1,
  );
}
