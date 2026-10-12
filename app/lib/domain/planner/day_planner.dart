import 'dart:math' as math;

import '../models/day.dart';
import '../models/enums.dart';
import 'planner_entry.dart';
import 'timetable.dart';

/// One stretch of a planned day.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    this.room,
    this.who,
    this.place,
    this.note,
    this.optional = false,
    this.packed = false,
    this.quick = false,
    this.sessionFuel = false,
    this.moved = false,
    this.remind = false,
    this.blockId,
    this.entryId,
    this.category,
  });

  /// A timetable block's id; `event:<n>`, `travel:<n>`, `session` or
  /// `meal:<slot>` otherwise.
  final String id;
  final PlanKind kind;
  final String title;

  /// Minutes after midnight.
  final int start;
  final int end;
  final String? room;
  final String? who;
  final String? place;
  final String? note;

  /// An optional class, or the optional Sunday.
  final bool optional;

  /// A meal with nowhere free to eat it but a shift: take it to work.
  final bool packed;

  /// A meal squeezed into a short gap.
  final bool quick;

  /// The last meal before the session: its fuel.
  final bool sessionFuel;

  /// A session he moved to a time of his own.
  final bool moved;

  /// One of his own entries he wants a reminder for.
  final bool remind;

  /// The weekly block this came from.
  final String? blockId;

  /// The planner entry this came from.
  final int? entryId;
  final String? category;

  int get minutes => end - start;

  bool overlaps(int s, int e) => s < end && e > start;
}

/// One date, planned: what is on, the travel between, when to train, when to
/// eat — earliest first.
class DayPlan {
  const DayPlan({
    required this.date,
    required this.items,
    this.skipped = const [],
    this.breakName,
    this.lectures = false,
  });

  final DateTime date;
  final List<PlanItem> items;

  /// Weekly blocks not happening today: a class he skipped.
  final List<PlanItem> skipped;

  /// The break this date falls in, if any.
  final String? breakName;

  /// Whether it is a lecture day.
  final bool lectures;

  List<PlanItem> get commitments => [
    for (final i in items)
      if (i.kind.isCommitment) i,
  ];

  List<PlanItem> get travel => [
    for (final i in items)
      if (i.kind == PlanKind.travel) i,
  ];

  List<PlanItem> get meals => [
    for (final i in items)
      if (i.kind == PlanKind.meal) i,
  ];

  PlanItem? get session {
    for (final i in items) {
      if (i.kind == PlanKind.session) return i;
    }
    return null;
  }

  /// When each meal is today, by slot id: what Fuel shows.
  Map<String, String> get mealTimes => {
    for (final m in meals) m.id.substring('meal:'.length): formatHhmm(m.start),
  };

  /// What he is in at [minute] (a commitment or the session), and the next
  /// one to start. Travel and meals are neither: they fit around things.
  (PlanItem?, PlanItem?) nowAndNext(int minute) {
    bool counts(PlanItem i) =>
        i.kind.isCommitment || i.kind == PlanKind.session;
    PlanItem? now;
    PlanItem? next;
    for (final i in items) {
      if (!counts(i)) continue;
      if (now == null && i.start <= minute && minute < i.end) now = i;
      if (next == null && i.start > minute) next = i;
    }
    return (now, next);
  }
}

/// A meal's place in the day: from fuel.json's slots.
class MealTarget {
  const MealTarget({
    required this.id,
    required this.name,
    required this.target,
    required this.minutes,
    required this.quickMinutes,
  });

  /// A slot of [kcal]: a meal of 400 kcal or more takes 20 minutes (15 at
  /// a push), a snack 10 (5).
  factory MealTarget.sized({
    required String id,
    required String name,
    required String time,
    required num kcal,
  }) {
    final big = kcal >= 400;
    return MealTarget(
      id: id,
      name: name,
      target: parseHhmm(time),
      minutes: big ? 20 : 10,
      quickMinutes: big ? 15 : 5,
    );
  }

  /// The slots in `fuel.json`, in the order they are eaten.
  static List<MealTarget> fromFuelJson(Map<String, dynamic> fuel) => [
    for (final s in fuel['slots'] as List)
      MealTarget.sized(
        id: (s as Map<String, dynamic>)['id'] as String,
        name: s['name'] as String,
        time: s['time'] as String,
        kcal: s['kcal'] as num,
      ),
  ];

  final String id;
  final String name;

  /// The time it is eaten when nothing is in the way.
  final int target;
  final int minutes;
  final int quickMinutes;
}

/// Plans a date: the timetable's blocks for it, his own entries, the travel
/// between places, the session after the last commitment (or on a free
/// morning), and each meal at the free time nearest its target.
///
/// Pure: hand it a date, the programme's day and his entries; it touches
/// no clock, no database and no plugin.
class DayPlanner {
  const DayPlanner({
    required this.timetable,
    required this.meals,
    this.freeMorningSession = 10 * 60,
    this.settleMinutes = 30,
    this.mealGapMinutes = 90,
    this.earliestMeal = 6 * 60,
    this.latestSession = 20 * 60 + 30,
  });

  final Timetable timetable;
  final List<MealTarget> meals;

  /// On a day with nothing on: a morning session.
  final int freeMorningSession;

  /// Home, change, a snack: between the last commitment and the session.
  final int settleMinutes;

  /// Meals at least this far apart, start to start.
  final int mealGapMinutes;
  final int earliestMeal;
  final int latestSession;

  static int _roundUp15(int m) => (m + 14) ~/ 15 * 15;

  DayPlan plan(
    DateTime date, {
    Day? session,
    List<PlannerEntry> entries = const [],
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final weekday = Weekday.fromDateTime(day);
    final lectures = timetable.hasLectures(day);
    final mine = [
      for (final e in entries)
        if (e.isOn(day)) e,
    ];
    final skippedIds = {
      for (final e in mine)
        if (e.kind == EntryKind.skip) e.blockId,
    };
    final markedIds = {
      for (final e in mine)
        if (e.kind == EntryKind.mark) e.blockId,
    };

    PlanItem fromBlock(TimetableBlock b) => PlanItem(
      id: b.id,
      kind: b.kind,
      title: b.title,
      start: b.start,
      end: b.end,
      room: b.room,
      who: b.who,
      place: b.place,
      note: b.note,
      optional: b.optional,
      blockId: b.id,
    );

    final commitments = <PlanItem>[];
    final skipped = <PlanItem>[];
    for (final b in timetable.on(weekday)) {
      if (b.kind == PlanKind.lecture && !lectures) continue;
      if (b.onlyWhenMarked && !markedIds.contains(b.id)) continue;
      if (skippedIds.contains(b.id)) {
        skipped.add(fromBlock(b));
        continue;
      }
      commitments.add(fromBlock(b));
    }
    for (final e in mine) {
      if (e.kind != EntryKind.event || e.start == null || e.end == null) {
        continue;
      }
      commitments.add(
        PlanItem(
          id: 'event:${e.id ?? commitments.length}',
          kind: PlanKind.event,
          title: e.title ?? 'Plan',
          start: e.start!,
          end: math.max(e.end!, e.start! + 5),
          remind: e.remind,
          entryId: e.id,
          category: e.category,
        ),
      );
    }
    commitments.sort((a, b) => a.start.compareTo(b.start));

    // Travel: to the first place, between two places, and home.
    final t = timetable.travelMinutes;
    final placed = [
      for (final c in commitments)
        if (c.place != null) c,
    ];
    final travel = <PlanItem>[];
    PlanItem leg(int start, int end, String to) => PlanItem(
      id: 'travel:${travel.length}',
      kind: PlanKind.travel,
      title: to == 'home' ? 'Home' : 'To ${timetable.places[to] ?? to}',
      start: start,
      end: end,
      place: to,
    );
    if (placed.isNotEmpty) {
      travel.add(
        leg(placed.first.start - t, placed.first.start, placed.first.place!),
      );
      for (var i = 1; i < placed.length; i++) {
        final a = placed[i - 1], b = placed[i];
        if (a.place == b.place) continue;
        final from = math.max(a.end, b.start - t);
        if (b.start > from) travel.add(leg(from, b.start, b.place!));
      }
      travel.add(leg(placed.last.end, placed.last.end + t, 'home'));
    }

    // Hard: nothing else can happen in it. A shift is soft: a meal can be
    // taken to work when there is nowhere else to eat it.
    final hard = [
      for (final c in commitments)
        if (c.kind != PlanKind.job) c,
      ...travel,
    ];
    final jobs = [
      for (final c in commitments)
        if (c.kind == PlanKind.job) c,
    ];
    bool free(int s, int e, {bool allowJobs = false}) =>
        !hard.any((h) => h.overlaps(s, e)) &&
        (allowJobs || !jobs.any((j) => j.overlaps(s, e)));

    // The session.
    PlanItem? sessionItem;
    if (session != null && session.isTrainingDay) {
      final length = math.max(15, session.estMinutes);
      final moved = mine.where(
        (e) => e.kind == EntryKind.sessionTime && e.start != null,
      );
      int start;
      if (moved.isNotEmpty) {
        start = moved.last.start!;
      } else {
        final weekend = weekday == Weekday.sat || weekday == Weekday.sun;
        final morningFree = free(
          freeMorningSession,
          freeMorningSession + length + settleMinutes,
        );
        if (commitments.isEmpty || (weekend && morningFree)) {
          start = freeMorningSession;
        } else {
          final lastEnd = commitments
              .map((c) => c.end + (c.place != null ? t : 0))
              .reduce(math.max);
          start = math.min(_roundUp15(lastEnd + settleMinutes), latestSession);
        }
      }
      sessionItem = PlanItem(
        id: 'session',
        kind: PlanKind.session,
        title: session.title,
        start: start,
        end: start + length,
        optional: session.optional,
        moved: moved.isNotEmpty,
      );
      hard.add(sessionItem);
    }

    // The meals, in order, each at the free time nearest its target.
    final s = sessionItem;
    final morningSession = s != null && s.start < 12 * 60;
    final placedMeals = <PlanItem>[];
    int? previousStart;
    for (final m in meals) {
      var target = m.target;
      var earliest = earliestMeal;
      if (s != null) {
        if (m.id == meals.first.id && morningSession) {
          target = s.start - 90;
        }
        if (!morningSession) {
          if (m.id == 'snack') target = s.start - 45;
          if (m.id == meals.last.id) earliest = s.end + 20;
        }
      }
      earliest = math.max(earliest, target - 150);
      if (previousStart != null) {
        earliest = math.max(earliest, previousStart + mealGapMinutes);
      }
      final latest = math.max(earliest, target + 180);

      int? best(int length, {bool atWork = false}) {
        int? pick;
        for (var t0 = earliest; t0 <= latest; t0 += 5) {
          final t1 = t0 + length;
          final ok = atWork
              ? !hard.any((h) => h.overlaps(t0, t1)) &&
                    jobs.any((j) => t0 >= j.start && t1 <= j.end)
              : free(t0, t1);
          if (!ok) continue;
          if (pick == null || (t0 - target).abs() < (pick - target).abs()) {
            pick = t0;
          }
        }
        return pick;
      }

      var start = best(m.minutes);
      var length = m.minutes;
      var packed = false;
      var quick = false;
      if (start == null) {
        start = best(m.quickMinutes);
        if (start != null) {
          length = m.quickMinutes;
          quick = true;
        }
      }
      if (start == null) {
        start = best(m.minutes, atWork: true);
        packed = start != null;
      }
      start ??= target.clamp(earliest, latest);
      placedMeals.add(
        PlanItem(
          id: 'meal:${m.id}',
          kind: PlanKind.meal,
          title: m.name,
          start: start,
          end: start + length,
          packed: packed,
          quick: quick,
        ),
      );
      previousStart = start;
    }

    // The session's fuel: the last meal finished before it starts.
    if (s != null) {
      final fuelIndex = placedMeals.lastIndexWhere((m) => m.end <= s.start);
      if (fuelIndex >= 0) {
        final f = placedMeals[fuelIndex];
        placedMeals[fuelIndex] = PlanItem(
          id: f.id,
          kind: f.kind,
          title: f.title,
          start: f.start,
          end: f.end,
          packed: f.packed,
          quick: f.quick,
          sessionFuel: true,
        );
      }
    }

    const order = {
      PlanKind.travel: 0,
      PlanKind.lecture: 1,
      PlanKind.job: 1,
      PlanKind.prayer: 1,
      PlanKind.event: 1,
      PlanKind.session: 2,
      PlanKind.meal: 3,
    };
    final items = [...commitments, ...travel, ?sessionItem, ...placedMeals]
      ..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : order[a.kind]!.compareTo(order[b.kind]!);
      });

    return DayPlan(
      date: day,
      items: items,
      skipped: skipped,
      breakName: timetable.breakOn(day),
      lectures: lectures,
    );
  }
}
