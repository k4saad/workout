import 'programme_calendar.dart';

/// What actually happened on a date, as far as adherence cares.
///
/// Deliberately not the Drift row: `lib/domain/` stays free of the data layer,
/// so these rules are testable without a database.
class SessionRecord {
  const SessionRecord({
    required this.dayId,
    required this.weekNo,
    required this.plannedDate,
    required this.scheduledDate,
    required this.status,
    this.loggedRetroactively = false,
  });

  final String dayId;
  final int weekNo;

  /// Where the programme said it belonged. Adherence counts against this.
  final DateTime plannedDate;

  /// Where it actually happened. The calendar draws it here.
  final DateTime scheduledDate;

  final RecordStatus status;
  final bool loggedRetroactively;

  bool get wasMoved =>
      plannedDate.year != scheduledDate.year ||
      plannedDate.month != scheduledDate.month ||
      plannedDate.day != scheduledDate.day;

  bool get counts =>
      status == RecordStatus.completed || status == RecordStatus.partial;
}

enum RecordStatus { planned, inProgress, completed, partial, skipped }

/// A calendar cell: what was planned, and what happened.
class CalendarEntry {
  const CalendarEntry({required this.planned, this.record});

  final PlannedDay planned;

  /// The session drawn on this date, if any. May have been moved here from
  /// another date.
  final SessionRecord? record;

  DateTime get date => planned.date;

  bool get isTrainingDay => planned.day?.isTrainingDay ?? false;
  bool get isOptional => planned.day?.optional ?? false;

  /// A required session that was planned, is in the past, and never happened.
  bool missed(DateTime today) =>
      isTrainingDay &&
      !isOptional &&
      record == null &&
      date.isBefore(DateTime(today.year, today.month, today.day));

  /// The glyph carries the state. Colour never does it alone — this gets read
  /// in a basement under a bare bulb.
  String glyph(DateTime today) {
    if (record != null) {
      if (record!.wasMoved) return '↷';
      return switch (record!.status) {
        RecordStatus.completed => '✓',
        RecordStatus.partial => '◐',
        RecordStatus.skipped => '✕',
        RecordStatus.inProgress => '▶',
        RecordStatus.planned => '',
      };
    }
    if (missed(today)) return '✕';
    return '';
  }
}

/// How much of the programme actually got done.
class AdherenceStats {
  const AdherenceStats({
    required this.planned,
    required this.completed,
    required this.partial,
    required this.skipped,
    required this.missed,
    required this.currentStreak,
    required this.longestStreak,
  });

  /// Required sessions only. Optional days never count against you — that is
  /// the whole point of marking them optional.
  final int planned;

  final int completed;
  final int partial;
  final int skipped;
  final int missed;

  final int currentStreak;
  final int longestStreak;

  /// Completed plus partial, over planned. A partial session is still a
  /// session you turned up for.
  double get rate =>
      planned == 0 ? 0 : ((completed + partial) / planned).clamp(0, 1);

  int get percent => (rate * 100).round();

  static const empty = AdherenceStats(
    planned: 0,
    completed: 0,
    partial: 0,
    skipped: 0,
    missed: 0,
    currentStreak: 0,
    longestStreak: 0,
  );
}

/// Merges what the programme planned with what the database recorded.
///
/// Pure. The calendar screen calls [entriesFor] once per month rather than
/// resolving 31 dates separately.
class CalendarMerge {
  const CalendarMerge(this.calendar);

  final ProgrammeCalendar calendar;

  /// Every date in the range, with its session attached.
  ///
  /// A session is drawn on its `scheduledDate`, which may differ from where
  /// the programme put it.
  List<CalendarEntry> entriesFor(
    DateTime from,
    DateTime to,
    List<SessionRecord> records,
  ) {
    final byDate = <String, SessionRecord>{};
    for (final r in records) {
      byDate[_key(r.scheduledDate)] = r;
    }
    return calendar
        .range(from, to)
        .map((p) => CalendarEntry(planned: p, record: byDate[_key(p.date)]))
        .toList();
  }

  /// Adherence over a range, measured against `plannedDate`.
  ///
  /// A session moved from Thursday to Saturday still counts for Thursday's
  /// week. Moving a session is life, not a failure.
  AdherenceStats adherence(
    int fromWeek,
    int toWeek,
    List<SessionRecord> records,
    DateTime today,
  ) {
    var planned = 0;
    for (var w = fromWeek; w <= toWeek; w++) {
      if (w < 1 || w > calendar.programme.totalWeeks) continue;
      planned += calendar.requiredSessionsInWeek(w);
    }

    final inRange = records
        .where((r) => r.weekNo >= fromWeek && r.weekNo <= toWeek)
        .toList();

    final completed = inRange
        .where((r) => r.status == RecordStatus.completed)
        .length;
    final partial = inRange
        .where((r) => r.status == RecordStatus.partial)
        .length;
    final skipped = inRange
        .where((r) => r.status == RecordStatus.skipped)
        .length;

    final accounted = completed + partial + skipped;
    final elapsed = _elapsedRequired(fromWeek, toWeek, today);
    final missed = (elapsed - accounted).clamp(0, planned);

    final streaks = _streaks(records, today);

    return AdherenceStats(
      planned: planned,
      completed: completed,
      partial: partial,
      skipped: skipped,
      missed: missed,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
    );
  }

  /// How many required sessions should have happened by [today].
  int _elapsedRequired(int fromWeek, int toWeek, DateTime today) {
    var count = 0;
    final cutoff = DateTime(today.year, today.month, today.day);
    for (var w = fromWeek; w <= toWeek; w++) {
      if (w < 1 || w > calendar.programme.totalWeeks) continue;
      for (final p in calendar.weekOf(w)) {
        final d = p.day;
        if (d == null || !d.isTrainingDay || d.optional) continue;
        if (p.date.isBefore(cutoff)) count++;
      }
    }
    return count;
  }

  /// Consecutive required sessions turned up for, counting backwards from the
  /// most recent one.
  ({int current, int longest}) _streaks(
    List<SessionRecord> records,
    DateTime today,
  ) {
    final cutoff = DateTime(today.year, today.month, today.day);
    final byDate = <String, SessionRecord>{
      for (final r in records) _key(r.plannedDate): r,
    };

    // Walk every required session date in order.
    final dates = <DateTime>[];
    for (var w = 1; w <= calendar.programme.totalWeeks; w++) {
      for (final p in calendar.weekOf(w)) {
        final d = p.day;
        if (d == null || !d.isTrainingDay || d.optional) continue;
        if (p.date.isAfter(cutoff)) continue;
        dates.add(p.date);
      }
    }

    var current = 0;
    var longest = 0;
    var run = 0;
    for (final date in dates) {
      final r = byDate[_key(date)];
      if (r != null && r.counts) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }
    current = run;

    return (current: current, longest: longest);
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
