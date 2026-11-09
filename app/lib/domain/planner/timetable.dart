import '../models/enums.dart';

/// What a stretch of the day is.
enum PlanKind {
  lecture,
  job,
  prayer,

  /// Time of his own he keeps every week: German, the library.
  study,

  /// One of his own: an exam, a meeting, an appointment.
  event,

  /// Getting from one place to the next: 30 minutes between campus and work.
  travel,
  session,
  meal;

  /// Something he has to be at, rather than something the plan fits in.
  bool get isCommitment =>
      this == lecture ||
      this == job ||
      this == prayer ||
      this == study ||
      this == event;

  /// What a weekly block can be, in the order the editor offers them.
  static const blockKinds = [lecture, job, study, prayer];
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

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// [title] as an id: lower case, ASCII, words joined by dashes.
String _slug(String title) {
  const folded = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'é': 'e',
    'è': 'e',
    'á': 'a',
    'à': 'a',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  final out = StringBuffer();
  for (final ch in title.toLowerCase().split('')) {
    out.write(folded[ch] ?? ch);
  }
  final s = out
      .toString()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return s.length > 24 ? s.substring(0, 24).replaceAll(RegExp('-+\$'), '') : s;
}

/// One thing that happens at the same time every week, on one day or
/// several.
class TimetableBlock {
  TimetableBlock({
    required this.id,
    required Iterable<Weekday> days,
    required this.start,
    required this.end,
    required this.kind,
    required this.title,
    this.place,
    this.room,
    this.who,
    this.optional = false,
    this.onlyWhenMarked = false,
    this.offInBreaks = false,
    this.note,
  }) : days = List.unmodifiable(Weekday.values.where((w) => days.contains(w)));

  /// v1 files name one `weekday`; v2 names `days`.
  factory TimetableBlock.fromJson(Map<String, dynamic> j) => TimetableBlock(
    id: j['id'] as String,
    days: j['days'] is List
        ? [for (final d in j['days'] as List) Weekday.fromJson(d as String)]
        : [Weekday.fromJson(j['weekday'] as String)],
    start: parseHhmm(j['start'] as String),
    end: parseHhmm(j['end'] as String),
    kind: switch (j['kind'] as String) {
      'lecture' => PlanKind.lecture,
      'job' => PlanKind.job,
      'prayer' => PlanKind.prayer,
      'study' => PlanKind.study,
      final k => throw FormatException('unknown block kind: $k'),
    },
    title: j['title'] as String,
    place: j['place'] as String?,
    room: j['room'] as String?,
    who: j['who'] as String?,
    optional: j['optional'] as bool? ?? false,
    onlyWhenMarked: j['onlyWhenMarked'] as bool? ?? false,
    offInBreaks: j['offInBreaks'] as bool? ?? false,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'days': [for (final d in days) d.toJson()],
    'start': formatHhmm(start),
    'end': formatHhmm(end),
    'kind': kind.name,
    'title': title,
    'place': ?place,
    'room': ?room,
    'who': ?who,
    if (optional) 'optional': true,
    if (onlyWhenMarked) 'onlyWhenMarked': true,
    if (offInBreaks) 'offInBreaks': true,
    'note': ?note,
  };

  final String id;

  /// The weekdays it is on, Monday first, each once.
  final List<Weekday> days;

  /// Minutes after midnight.
  final int start;
  final int end;
  final PlanKind kind;
  final String title;

  /// Where it is: `campus`, a workplace, the library. Moving between two
  /// places takes [Timetable.travelMinutes]. Null when it can be done
  /// anywhere — German — so it needs no travel.
  final String? place;
  final String? room;
  final String? who;

  /// One he may skip. He goes; the planner lets him skip one with a tap.
  final bool optional;

  /// Happens only on a date he has marked: Friday's Job 2, every fifth week.
  final bool onlyWhenMarked;

  /// Not in a break: the library over Christmas. Lectures never run in one
  /// anyway.
  final bool offInBreaks;
  final String? note;

  bool isOn(Weekday weekday) => days.contains(weekday);

  int get minutes => end - start;

  /// The same block under [id]: a new one gets its id when it is saved.
  TimetableBlock withId(String id) => TimetableBlock(
    id: id,
    days: days,
    start: start,
    end: end,
    kind: kind,
    title: title,
    place: place,
    room: room,
    who: who,
    optional: optional,
    onlyWhenMarked: onlyWhenMarked,
    offInBreaks: offInBreaks,
    note: note,
  );
}

/// A stretch with no lectures.
class TimetableBreak {
  const TimetableBreak(this.name, this.from, this.to);

  final String name;
  final DateTime from;
  final DateTime to;

  bool covers(DateTime date) => !date.isBefore(from) && !date.isAfter(to);

  Map<String, dynamic> toJson() => {
    'name': name,
    'from': _iso(from),
    'to': _iso(to),
  };
}

/// The semester's week. A fresh install starts from
/// `assets/content/timetable.json` (authored, V22); after that the phone's
/// copy is his, changed in the planner (docs/13-your-week-plan.md).
///
/// Lectures run only in the lecture period and never in a break. Work,
/// prayer and study run all year, unless a block is off in the breaks.
class Timetable {
  const Timetable({
    required this.name,
    required this.lecturesFrom,
    required this.lecturesTo,
    required this.breaks,
    required this.travelMinutes,
    required this.places,
    required this.blocks,
    this.note,
  });

  factory Timetable.fromJson(Map<String, dynamic> j) {
    final lectures = j['lectures'] as Map<String, dynamic>;
    return Timetable(
      name: j['name'] as String,
      note: j['note'] as String?,
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

  /// The version this build writes: `days` lists, `study`, places optional.
  static const schemaVersion = 2;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'name': name,
    'note': ?note,
    'lectures': {'from': _iso(lecturesFrom), 'to': _iso(lecturesTo)},
    'breaks': [for (final b in breaks) b.toJson()],
    'travelMinutes': travelMinutes,
    'places': places,
    'blocks': [for (final b in blocks) b.toJson()],
  };

  final String name;
  final String? note;
  final DateTime lecturesFrom;
  final DateTime lecturesTo;
  final List<TimetableBreak> breaks;
  final int travelMinutes;
  final Map<String, String> places;
  final List<TimetableBlock> blocks;

  Timetable copyWith({
    String? name,
    DateTime? lecturesFrom,
    DateTime? lecturesTo,
    List<TimetableBreak>? breaks,
    int? travelMinutes,
    Map<String, String>? places,
    List<TimetableBlock>? blocks,
  }) => Timetable(
    name: name ?? this.name,
    note: note,
    lecturesFrom: lecturesFrom ?? this.lecturesFrom,
    lecturesTo: lecturesTo ?? this.lecturesTo,
    breaks: breaks ?? this.breaks,
    travelMinutes: travelMinutes ?? this.travelMinutes,
    places: places ?? this.places,
    blocks: blocks ?? this.blocks,
  );

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

  /// Whether [b] runs on [date] at all, before any skip or mark of his: a
  /// lecture only on a lecture day, a block off in the breaks not in one.
  bool runsOn(TimetableBlock b, DateTime date) {
    if (!b.isOn(Weekday.fromDateTime(date))) return false;
    if (b.kind == PlanKind.lecture) return hasLectures(date);
    if (b.offInBreaks) return breakOn(date) == null;
    return true;
  }

  /// Every block on [weekday], earliest first.
  List<TimetableBlock> on(Weekday weekday) =>
      blocks.where((b) => b.isOn(weekday)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  TimetableBlock? block(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// [b] in place of the block with its id, or added after the rest.
  Timetable withBlock(TimetableBlock b) {
    final i = blocks.indexWhere((x) => x.id == b.id);
    return copyWith(
      blocks: i < 0
          ? [...blocks, b]
          : [...blocks.sublist(0, i), b, ...blocks.sublist(i + 1)],
    );
  }

  Timetable withoutBlock(String id) => copyWith(
    blocks: [
      for (final b in blocks)
        if (b.id != id) b,
    ],
  );

  /// Adds the place [id], or renames it.
  Timetable withPlace(String id, String name) =>
      copyWith(places: {...places, id: name});

  /// Removes the place [id]. A place a block is at cannot go: move the
  /// block first.
  Timetable withoutPlace(String id) {
    if (usesOf(id).isNotEmpty) {
      throw StateError('$id is where ${usesOf(id).first.title} is');
    }
    return copyWith(
      places: {
        for (final e in places.entries)
          if (e.key != id) e.key: e.value,
      },
    );
  }

  /// The blocks at [placeId].
  List<TimetableBlock> usesOf(String placeId) => [
    for (final b in blocks)
      if (b.place == placeId) b,
  ];

  static String _unique(String base, bool Function(String) taken) {
    if (!taken(base)) return base;
    for (var n = 2; ; n++) {
      if (!taken('$base-$n')) return '$base-$n';
    }
  }

  /// An id for a new block called [title] that no block has: `german`,
  /// then `german-2`.
  String newBlockId(String title) {
    final base = _slug(title);
    return _unique(base.isEmpty ? 'block' : base, (id) => block(id) != null);
  }

  /// An id for a new place called [name].
  String newPlaceId(String name) {
    final base = _slug(name);
    return _unique(base.isEmpty ? 'place' : base, places.containsKey);
  }
}
