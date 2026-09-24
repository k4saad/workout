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

/// What a calendar date says about its session, in one word.
///
/// The glyph carries it; colour never does it alone — this gets read in a
/// basement under a bare bulb.
enum EntryState {
  /// Nothing to say: the future, a rest day, or outside the programme.
  none(''),
  done('✓'),
  partial('◐'),

  /// Skipped on purpose. Not the same as missed.
  skipped('⊘'),

  /// A required session in the past that never happened.
  missed('✕'),
  inProgress('▶'),

  /// This date's session was done (or is to be done) on another date.
  movedAway('→'),

  /// Another date's session was done here.
  movedHere('↷');

  const EntryState(this.glyph);

  final String glyph;
}

/// A calendar cell: what was planned, and what happened.
class CalendarEntry {
  const CalendarEntry({
    required this.planned,
    this.records = const [],
    this.movedAway = const [],
  });

  final PlannedDay planned;

  /// Every session drawn on this date: its own, and any moved here from
  /// another date. v2 kept one per date, so a second session on a date
  /// simply vanished.
  final List<SessionRecord> records;

  /// Sessions planned for this date that were done (or are to be done) on
  /// another. This date is not missed: its session went somewhere.
  final List<SessionRecord> movedAway;

  /// The session to show first: this date's own, else one moved here.
  SessionRecord? get record {
    for (final r in records) {
      if (_sameDay(r.plannedDate, date)) return r;
    }
    return records.isEmpty ? null : records.first;
  }

  DateTime get date => planned.date;

  bool get isTrainingDay => planned.day?.isTrainingDay ?? false;
  bool get isOptional => planned.day?.optional ?? false;

  /// A required session that is in the past and never happened, here or
  /// anywhere it could have been moved to. A deliberate skip is not a miss.
  bool missed(DateTime today) =>
      isTrainingDay &&
      !isOptional &&
      movedAway.isEmpty &&
      !records.any((r) => _sameDay(r.plannedDate, date)) &&
      date.isBefore(DateTime(today.year, today.month, today.day));

  /// This date's own session, wherever it was done: here, or moved away.
  SessionRecord? get own {
    for (final r in records) {
      if (_sameDay(r.plannedDate, date)) return r;
    }
    return movedAway.isEmpty ? null : movedAway.first;
  }

  /// Sessions planned for other dates and done on this one.
  List<SessionRecord> get movedHere => [
    for (final r in records)
      if (!_sameDay(r.plannedDate, date)) r,
  ];

  /// What the date says, led by its own session; a session moved here
  /// speaks only when the date has none of its own.
  EntryState state(DateTime today) {
    final r = record;
    if (r != null) {
      if (!_sameDay(r.plannedDate, date)) return EntryState.movedHere;
      return switch (r.status) {
        RecordStatus.completed => EntryState.done,
        RecordStatus.partial => EntryState.partial,
        RecordStatus.skipped => EntryState.skipped,
        RecordStatus.inProgress => EntryState.inProgress,
        RecordStatus.planned => EntryState.none,
      };
    }
    if (movedAway.isNotEmpty) return EntryState.movedAway;
    if (missed(today)) return EntryState.missed;
    return EntryState.none;
  }

  /// ✓ done · ◐ partial · ⊘ skipped on purpose · ✕ missed · ▶ in progress ·
  /// ↷ moved here · → moved away.
  String glyph(DateTime today) => state(today).glyph;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Required sessions over a run of calendar dates — a week, a month —
/// counted against the date each was PLANNED for.
class SessionTally {
  const SessionTally({
    required this.required,
    required this.done,
    required this.skipped,
    required this.missed,
  });

  /// Required sessions planned in the range. Optional days never count.
  final int required;

  /// Turned up for: completed or partial, here or moved elsewhere.
  final int done;
  final int skipped;

  /// In the past and never dealt with. An abandoned session left open
  /// counts here too: it did not get done.
  final int missed;

  /// Due by now: the past ones, plus any already dealt with ahead of time.
  int get due => done + skipped + missed;

  /// Still to come.
  int get remaining => required - due;

  static SessionTally of(Iterable<CalendarEntry> entries, DateTime today) {
    final cutoff = DateTime(today.year, today.month, today.day);
    var required = 0, done = 0, skipped = 0, missed = 0;
    for (final e in entries) {
      if (!e.isTrainingDay || e.isOptional) continue;
      required++;
      final r = e.own;
      if (r != null && r.counts) {
        done++;
      } else if (r != null && r.status == RecordStatus.skipped) {
        skipped++;
      } else if (e.date.isBefore(cutoff)) {
        missed++;
      }
    }
    return SessionTally(
      required: required,
      done: done,
      skipped: skipped,
      missed: missed,
    );
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
    this.due = 0,
  });

  /// Required sessions only. Optional days never count against you — that is
  /// the whole point of marking them optional.
  final int planned;

  /// Required sessions that should have happened by now: every one before
  /// today, plus today's once it has been logged. Adherence is measured
  /// against this. v2 measured against [planned] — the whole programme — so
  /// a perfect first fortnight read as 17 %.
  final int due;

  final int completed;
  final int partial;
  final int skipped;
  final int missed;

  final int currentStreak;
  final int longestStreak;

  bool get hasDue => due > 0;

  /// Adherence: completed plus partial, over what was due. A partial
  /// session is still a session you turned up for.
  double get rate => due == 0 ? 0 : ((completed + partial) / due).clamp(0, 1);

  int get percent => (rate * 100).round();

  /// Progress: completed plus partial, over the whole range planned.
  double get progress =>
      planned == 0 ? 0 : ((completed + partial) / planned).clamp(0, 1);

  int get progressPercent => (progress * 100).round();

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
    final here = <String, List<SessionRecord>>{};
    final away = <String, List<SessionRecord>>{};
    for (final r in records) {
      (here[_key(r.scheduledDate)] ??= []).add(r);
      if (r.wasMoved) (away[_key(r.plannedDate)] ??= []).add(r);
    }
    return calendar
        .range(from, to)
        .map(
          (p) => CalendarEntry(
            planned: p,
            records: here[_key(p.date)] ?? const [],
            movedAway: away[_key(p.date)] ?? const [],
          ),
        )
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

    // Only sessions of REQUIRED days count: an optional run done is a bonus,
    // not a way to paper over a missed squat day.
    final inRange = records
        .where(
          (r) => r.weekNo >= fromWeek && r.weekNo <= toWeek && _required(r),
        )
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

    final cutoff = DateTime(today.year, today.month, today.day);
    bool accounted(SessionRecord r) =>
        r.status == RecordStatus.completed ||
        r.status == RecordStatus.partial ||
        r.status == RecordStatus.skipped;
    final accountedBefore = inRange
        .where((r) => accounted(r) && r.plannedDate.isBefore(cutoff))
        .length;
    final accountedFromToday = inRange
        .where((r) => accounted(r) && !r.plannedDate.isBefore(cutoff))
        .length;

    final elapsed = _elapsedRequired(fromWeek, toWeek, today);
    final missed = (elapsed - accountedBefore).clamp(0, planned);
    final due = (elapsed + accountedFromToday).clamp(0, planned);

    final streaks = _streaks(records, today);

    return AdherenceStats(
      planned: planned,
      due: due,
      completed: completed,
      partial: partial,
      skipped: skipped,
      missed: missed,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
    );
  }

  bool _required(SessionRecord r) {
    final d = calendar.forDate(r.plannedDate).day;
    return d != null && d.isTrainingDay && !d.optional;
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

    // Walk every required session date in order, up to today. Today's
    // session counts once it is logged, and until then is not a break: the
    // streak must not reset at midnight and come back at seven.
    final dates = <DateTime>[];
    for (var w = 1; w <= calendar.programme.totalWeeks; w++) {
      for (final p in calendar.weekOf(w)) {
        final d = p.day;
        if (d == null || !d.isTrainingDay || d.optional) continue;
        if (p.date.isAfter(cutoff)) continue;
        if (p.date == cutoff && !(byDate[_key(p.date)]?.counts ?? false)) {
          continue;
        }
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
