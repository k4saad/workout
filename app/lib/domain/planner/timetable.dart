import '../models/enums.dart';

/// What a stretch of the day is.
enum PlanKind {
  lecture,
  job,
  prayer,

  /// One of his own: an exam, a meeting, an appointment.
  event,

  /// Getting from one place to the next: 30 minutes between campus and work.
  travel,
  session,
  meal;

  /// Something he has to be at, rather than something the plan fits in.
  bool get isCommitment =>
      this == lecture || this == job || this == prayer || this == event;
}

/// `HH:mm` to minutes after midnight.
int parseHhmm(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) throw FormatException('not HH:mm: $hhmm');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Minutes after midnight to `HH:mm`.
String formatHhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

DateTime _date(String iso) {
  final d = DateTime.parse(iso);
  return DateTime(d.year, d.month, d.day);
}

/// One thing in the week that happens at the same time every week.
class TimetableBlock {
  const TimetableBlock({
    required this.id,
    required this.weekday,
    required this.start,
    required this.end,
    required this.kind,
    required this.title,
    required this.place,
    this.room,
    this.who,
    this.optional = false,
    this.onlyWhenMarked = false,
    this.note,
  });

  factory TimetableBlock.fromJson(Map<String, dynamic> j) => TimetableBlock(
    id: j['id'] as String,
    weekday: Weekday.fromJson(j['weekday'] as String),
    start: parseHhmm(j['start'] as String),
    end: parseHhmm(j['end'] as String),
    kind: switch (j['kind'] as String) {
      'lecture' => PlanKind.lecture,
      'job' => PlanKind.job,
      'prayer' => PlanKind.prayer,
      final k => throw FormatException('unknown block kind: $k'),
    },
    title: j['title'] as String,
    place: j['place'] as String,
    room: j['room'] as String?,
    who: j['who'] as String?,
    optional: j['optional'] as bool? ?? false,
    onlyWhenMarked: j['onlyWhenMarked'] as bool? ?? false,
    note: j['note'] as String?,
  );

  final String id;
  final Weekday weekday;

  /// Minutes after midnight.
  final int start;
  final int end;
  final PlanKind kind;
  final String title;

  /// Where it is: `campus`, or a workplace. Moving between two places takes
  /// [Timetable.travelMinutes].
  final String place;
  final String? room;
  final String? who;

  /// A class he may skip. He goes; the planner lets him skip one with a tap.
  final bool optional;

  /// Happens only on a date he has marked: Friday's Job 2, every fifth week.
  final bool onlyWhenMarked;
  final String? note;
}

/// A stretch with no lectures.
class TimetableBreak {
  const TimetableBreak(this.name, this.from, this.to);

  final String name;
  final DateTime from;
  final DateTime to;

  bool covers(DateTime date) => !date.isBefore(from) && !date.isAfter(to);
}

/// The semester's week: `assets/content/timetable.json`, authored from his
/// timetable and checked by tools/validate.py (V22).
///
/// Lectures run only in the lecture period and never in a break. Work and
/// prayer run all year.
class Timetable {
  const Timetable({
    required this.name,
    required this.lecturesFrom,
    required this.lecturesTo,
    required this.breaks,
    required this.travelMinutes,
    required this.places,
    required this.blocks,
  });

  factory Timetable.fromJson(Map<String, dynamic> j) {
    final lectures = j['lectures'] as Map<String, dynamic>;
    return Timetable(
      name: j['name'] as String,
      lecturesFrom: _date(lectures['from'] as String),
      lecturesTo: _date(lectures['to'] as String),
      breaks: [
        for (final b in (j['breaks'] as List? ?? const []))
          TimetableBreak(
            (b as Map<String, dynamic>)['name'] as String,
            _date(b['from'] as String),
            _date(b['to'] as String),
          ),
      ],
      travelMinutes: (j['travelMinutes'] as num).toInt(),
      places: {
        for (final e in (j['places'] as Map<String, dynamic>).entries)
          e.key: e.value as String,
      },
      blocks: [
        for (final b in j['blocks'] as List)
          TimetableBlock.fromJson(b as Map<String, dynamic>),
      ],
    );
  }

  final String name;
  final DateTime lecturesFrom;
  final DateTime lecturesTo;
  final List<TimetableBreak> breaks;
  final int travelMinutes;
  final Map<String, String> places;
  final List<TimetableBlock> blocks;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The break [date] falls in, if any.
  String? breakOn(DateTime date) {
    final d = _day(date);
    for (final b in breaks) {
      if (b.covers(d)) return b.name;
    }
    return null;
  }

  /// Whether there are lectures on [date]: in the lecture period, not in a
  /// break.
  bool hasLectures(DateTime date) {
    final d = _day(date);
    return !d.isBefore(lecturesFrom) &&
        !d.isAfter(lecturesTo) &&
        breakOn(d) == null;
  }

  /// Every block on [weekday], earliest first.
  List<TimetableBlock> on(Weekday weekday) =>
      blocks.where((b) => b.weekday == weekday).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  TimetableBlock? block(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }
}
