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
    this.takeAlong = false,
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

  /// A meal in the middle of his own study away from home — the library —
  /// eaten on a break there: take it with you.
  final bool takeAlong;

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

/// One place a meal could go, and what it costs to eat it there.
class _MealSlot {
  _MealSlot(
    this.start,
    this.length,
    this.cost, {
    this.packed = false,
    this.quick = false,
    this.along = false,
  });

  final int start;
  final int length;

  /// Minutes from the meal's time, plus what eating it there is worth.
  final int cost;
  final bool packed;
  final bool quick;
  final bool along;

  /// The cheapest way to get here, the meals before it included.
  int total = 0;
  _MealSlot? before;
}

/// Plans a date: the timetable's blocks for it, his own entries, the travel
/// between places, the session after the day's commitments (or on a free
/// morning), and the day's meals as near their times as the day allows.
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
    this.homeMinutes = 60,
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

  /// The least time at home that makes going home between two things worth
  /// the two rides: with 30 minutes' travel, a gap of two hours.
  final int homeMinutes;

  /// What eating a meal somewhere other than at home or between things is
  /// worth, in minutes from its time. A short gap costs a little; a break
  /// in the library a little more; a meal packed for work is worth it only
  /// to save the day's meals an hour and a half of lateness between them.
  /// So Tuesday's breakfast is at 06:10, before the 07:00 shift (80 minutes
  /// early beats one at work), and Thursday's lunch is packed (eaten at
  /// 15:45 instead, it would push dinner past German).
  static const _quickCost = 15;
  static const _alongCost = 20;
  static const _packedCost = 90;

  /// A meal the day has no room for at all.
  static const _nowhereCost = 100000;

  static int _roundUp15(int m) => (m + 14) ~/ 15 * 15;
  static int _roundUp5(int m) => (m + 4) ~/ 5 * 5;

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
      if (!timetable.runsOn(b, day)) continue;
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

    // Travel: to the first place, between two places, and home. A gap long
    // enough to be worth the two rides is spent at home.
    final t = timetable.travelMinutes;
    final placed = [
      for (final c in commitments)
        if (c.place != null) c,
    ];
    final travel = <PlanItem>[];
    void leg(int start, int end, String to) {
      if (end <= start) return;
      travel.add(
        PlanItem(
          id: 'travel:${travel.length}',
          kind: PlanKind.travel,
          title: to == 'home' ? 'Home' : 'To ${timetable.places[to] ?? to}',
          start: start,
          end: end,
          place: to,
        ),
      );
    }

    if (placed.isNotEmpty) {
      leg(placed.first.start - t, placed.first.start, placed.first.place!);
      var at = placed.first;
      for (final next in placed.skip(1)) {
        final gap = next.start - at.end;
        if (gap >= 2 * t + homeMinutes) {
          leg(at.end, at.end + t, 'home');
          leg(next.start - t, next.start, next.place!);
        } else if (next.place != at.place) {
          leg(math.max(at.end, next.start - t), next.start, next.place!);
        }
        if (next.end > at.end) at = next;
      }
      leg(at.end, at.end + t, 'home');
    }

    // Out of the house: from leaving to getting back.
    final out = <(int, int)>[];
    int? leftAt;
    for (final l in travel) {
      if (l.place == 'home') {
        if (leftAt != null) out.add((leftAt, l.end));
        leftAt = null;
      } else {
        leftAt ??= l.start;
      }
    }

    // Hard: nothing else can happen in it. A shift is soft: a meal can be
    // taken to work when there is nowhere else to eat it. His own study
    // somewhere — the library — is open: a meal can be eaten on a break
    // there. German, anywhere, is his hour: hard.
    bool isOpen(PlanItem c) => c.kind == PlanKind.study && c.place != null;
    final hard = [
      for (final c in commitments)
        if (c.kind != PlanKind.job && !isOpen(c)) c,
      ...travel,
    ];
    final jobs = [
      for (final c in commitments)
        if (c.kind == PlanKind.job) c,
    ];
    final open = [
      for (final c in commitments)
        if (isOpen(c)) c,
    ];
    bool clear(List<PlanItem> xs, int s, int e) =>
        !xs.any((x) => x.overlaps(s, e));

    // The session: in the basement, so at home, with time to settle after
    // getting back.
    PlanItem? sessionItem;
    if (session != null && session.isTrainingDay) {
      final length = math.max(15, session.estMinutes);
      final moved = mine.where(
        (e) => e.kind == EntryKind.sessionTime && e.start != null,
      );
      bool atHome(int s, int e) =>
          out.every((o) => e <= o.$1 || s >= o.$2 + settleMinutes);
      bool fits(int s) =>
          clear(hard, s, s + length) &&
          clear(jobs, s, s + length) &&
          clear(open, s, s + length) &&
          atHome(s, s + length);
      int? first(int from, int to) {
        for (var s = from; s <= to; s += 15) {
          if (fits(s)) return s;
        }
        return null;
      }

      int start;
      if (moved.isNotEmpty) {
        start = moved.last.start!;
      } else {
        final weekend = weekday == Weekday.sat || weekday == Weekday.sun;
        // What the day is built around: classes, work, prayer, his own
        // entries. His weekly study is not: German in the evening comes
        // after the session, it does not push it later.
        final obligations = [
          for (final c in commitments)
            if (c.kind != PlanKind.study) c,
        ];
        final m = freeMorningSession;
        final morningFree =
            fits(m) &&
            clear([...hard, ...jobs, ...open], m, m + length + settleMinutes);
        if ((obligations.isEmpty || weekend) && morningFree) {
          start = m;
        } else {
          final base = obligations.isEmpty
              ? m
              : _roundUp15(
                  obligations
                          .map((c) => c.end + (c.place != null ? t : 0))
                          .reduce(math.max) +
                      settleMinutes,
                );
          // The first free time after them; later than usual rather than
          // on top of anything; where it always went when nothing is free.
          start =
              first(base, latestSession) ??
              first(math.max(base, latestSession + 15), 23 * 60 - length) ??
              math.min(base, latestSession);
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

    // The meals: the day's four as near their times as it allows, chosen
    // together. One at a time, a late lunch pushed the snack and the snack
    // pushed dinner past German.
    final s = sessionItem;
    final morningSession = s != null && s.start < 12 * 60;
    List<_MealSlot>? previous;
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
      final lo = _roundUp5(math.max(earliest, target - 150));
      final hi = math.max(lo, target + 180);

      _MealSlot? slotAt(int t0) {
        final full = t0 + m.minutes, short = t0 + m.quickMinutes;
        final dev = (t0 - target).abs();
        final calm = clear(hard, t0, full);
        if (calm && clear(jobs, t0, full) && clear(open, t0, full)) {
          return _MealSlot(t0, m.minutes, dev);
        }
        if (clear(hard, t0, short) &&
            clear(jobs, t0, short) &&
            clear(open, t0, short)) {
          return _MealSlot(t0, m.quickMinutes, dev + _quickCost, quick: true);
        }
        if (calm &&
            clear(jobs, t0, full) &&
            open.any((o) => t0 >= o.start && full <= o.end)) {
          return _MealSlot(t0, m.minutes, dev + _alongCost, along: true);
        }
        if (calm && jobs.any((j) => t0 >= j.start && full <= j.end)) {
          return _MealSlot(t0, m.minutes, dev + _packedCost, packed: true);
        }
        return null;
      }

      final options = [
        for (var t0 = lo; t0 <= hi; t0 += 5) ?slotAt(t0),
        // Nowhere free at all: its time anyway. The day is simply full.
        _MealSlot(target.clamp(lo, hi), m.minutes, _nowhereCost),
      ];
      final layer = <_MealSlot>[];
      if (previous == null) {
        for (final o in options) {
          layer.add(o..total = o.cost);
        }
      } else {
        for (final o in options) {
          _MealSlot? best;
          for (final p in previous) {
            if (p.start + mealGapMinutes > o.start) continue;
            if (best == null || p.total < best.total) best = p;
          }
          if (best == null) continue;
          layer.add(
            o
              ..before = best
              ..total = best.total + o.cost,
          );
        }
        if (layer.isEmpty) {
          // Nothing in its window comes late enough after the meal before:
          // the first minute that does.
          for (final p in previous) {
            final at = p.start + mealGapMinutes;
            final cost = _nowhereCost + (at - target).abs();
            layer.add(
              _MealSlot(at, m.minutes, cost)
                ..before = p
                ..total = p.total + cost,
            );
          }
        }
      }
      previous = layer;
    }

    final chosen = <_MealSlot>[];
    if (previous != null && previous.isNotEmpty) {
      _MealSlot? cheapest;
      for (final o in previous) {
        if (cheapest == null || o.total < cheapest.total) cheapest = o;
      }
      for (_MealSlot? o = cheapest; o != null; o = o.before) {
        chosen.insert(0, o);
      }
    }
    final placedMeals = [
      for (var i = 0; i < chosen.length; i++)
        PlanItem(
          id: 'meal:${meals[i].id}',
          kind: PlanKind.meal,
          title: meals[i].name,
          start: chosen[i].start,
          end: chosen[i].start + chosen[i].length,
          packed: chosen[i].packed,
          quick: chosen[i].quick,
          takeAlong: chosen[i].along,
        ),
    ];

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
          takeAlong: f.takeAlong,
          sessionFuel: true,
        );
      }
    }

    const order = {
      PlanKind.travel: 0,
      PlanKind.lecture: 1,
      PlanKind.job: 1,
      PlanKind.prayer: 1,
      PlanKind.study: 1,
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
