/// What a planner entry does to its day.
enum EntryKind {
  /// One of his own: an exam, a meeting, an appointment.
  event,

  /// A weekly block that is not happening this time: a skipped class.
  skip,

  /// A block that happens only when marked: Friday's Job 2.
  mark,

  /// The session moved to a time of his choosing.
  sessionTime,
}

/// One change he made to one date in the planner. Stored in the app's
/// database; the planner reads them, the timetable itself never changes.
class PlannerEntry {
  const PlannerEntry._({
    required this.date,
    required this.kind,
    this.id,
    this.blockId,
    this.title,
    this.start,
    this.end,
    this.remind = false,
    this.category,
  });

  /// Something of his own on [date], [start] to [end] minutes after
  /// midnight.
  factory PlannerEntry.event({
    int? id,
    required DateTime date,
    required String title,
    required int start,
    required int end,
    bool remind = true,
    String? category,
  }) => PlannerEntry._(
    id: id,
    date: _day(date),
    kind: EntryKind.event,
    title: title,
    start: start,
    end: end,
    remind: remind,
    category: category,
  );

  /// [blockId] is not happening on [date].
  factory PlannerEntry.skip({
    int? id,
    required DateTime date,
    required String blockId,
  }) => PlannerEntry._(
    id: id,
    date: _day(date),
    kind: EntryKind.skip,
    blockId: blockId,
  );

  /// [blockId], which only happens when marked, is happening on [date].
  factory PlannerEntry.mark({
    int? id,
    required DateTime date,
    required String blockId,
  }) => PlannerEntry._(
    id: id,
    date: _day(date),
    kind: EntryKind.mark,
    blockId: blockId,
  );

  /// The session on [date] starts at [start].
  factory PlannerEntry.sessionAt({
    int? id,
    required DateTime date,
    required int start,
  }) => PlannerEntry._(
    id: id,
    date: _day(date),
    kind: EntryKind.sessionTime,
    start: start,
  );

  /// Rebuilt from storage; unknown kinds read as events, so a newer build's
  /// rows never crash an older one.
  factory PlannerEntry.stored({
    required int id,
    required DateTime date,
    required String kind,
    String? blockId,
    String? title,
    int? start,
    int? end,
    bool remind = false,
    String? category,
  }) => PlannerEntry._(
    id: id,
    date: _day(date),
    kind: EntryKind.values.firstWhere(
      (k) => k.name == kind,
      orElse: () => EntryKind.event,
    ),
    blockId: blockId,
    title: title,
    start: start,
    end: end,
    remind: remind,
    category: category,
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  final int? id;
  final DateTime date;
  final EntryKind kind;
  final String? blockId;
  final String? title;

  /// Minutes after midnight.
  final int? start;
  final int? end;

  /// Notify before it starts.
  final bool remind;

  /// Exam, meeting, appointment, study, other: picks its glyph.
  final String? category;

  bool isOn(DateTime d) =>
      date.year == d.year && date.month == d.month && date.day == d.day;
}
