import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart' show Session;
import '../data/db/tables.dart' as t;
import '../domain/calendar/adherence.dart';
import '../domain/calendar/day_markers.dart';
import '../domain/calendar/programme_calendar.dart';
import 'fuel_providers.dart';
import 'providers.dart';
import 'run_providers.dart';
import 'session_providers.dart';

/// Which month the calendar is showing.
class VisibleMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.watch(todayProvider);
    return DateTime(now.year, now.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);

  void jumpTo(DateTime date) => state = DateTime(date.year, date.month);
}

final visibleMonthProvider = NotifierProvider<VisibleMonthNotifier, DateTime>(
  VisibleMonthNotifier.new,
);

/// Maps a stored session onto the pure domain record the adherence rules use.
SessionRecord _toRecord(Session s) => SessionRecord(
  dayId: s.dayId,
  weekNo: s.weekNo,
  plannedDate: s.plannedDate,
  scheduledDate: s.scheduledDate,
  status: switch (s.status) {
    t.SessionStatus.completed => RecordStatus.completed,
    t.SessionStatus.partial => RecordStatus.partial,
    t.SessionStatus.skipped => RecordStatus.skipped,
    t.SessionStatus.inProgress => RecordStatus.inProgress,
    t.SessionStatus.planned => RecordStatus.planned,
  },
  loggedRetroactively: s.loggedRetroactively,
);

/// Every session ever logged, as domain records, LIVE.
///
/// A stream, not a one-off read: finish a session in the runner, come back,
/// and the calendar, the week and the streak already know. v2 read the table
/// once and showed yesterday's calendar until the app restarted.
final allRecordsProvider = StreamProvider<List<SessionRecord>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .select(db.sessions)
      .watch()
      .map((rows) => rows.map(_toRecord).toList());
});

final calendarMergeProvider = FutureProvider<CalendarMerge>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  return CalendarMerge(bundle.calendar);
});

/// Six weeks of cells covering [month], Monday-first.
///
/// One query per month, not thirty-one.
final monthEntriesProvider =
    FutureProvider.family<List<CalendarEntry>, DateTime>((ref, month) async {
      final merge = await ref.watch(calendarMergeProvider.future);
      final records = await ref.watch(allRecordsProvider.future);

      final first = DateTime(month.year, month.month);
      final gridStart = ProgrammeCalendar.addDays(
        first,
        -(first.weekday - DateTime.monday),
      );
      final gridEnd = ProgrammeCalendar.addDays(gridStart, 41); // 6 x 7

      return merge.entriesFor(gridStart, gridEnd, records);
    });

/// One programme week, for the agenda view.
final weekEntriesProvider = FutureProvider.family<List<CalendarEntry>, int>((
  ref,
  weekNo,
) async {
  final merge = await ref.watch(calendarMergeProvider.future);
  final records = await ref.watch(allRecordsProvider.future);
  final start = merge.calendar.startOfWeek(weekNo);
  return merge.entriesFor(start, ProgrammeCalendar.addDays(start, 6), records);
});

/// Adherence across the whole programme so far.
final programmeAdherenceProvider = FutureProvider<AdherenceStats>((ref) async {
  final merge = await ref.watch(calendarMergeProvider.future);
  final records = await ref.watch(allRecordsProvider.future);
  return merge.adherence(
    1,
    merge.calendar.programme.totalWeeks,
    records,
    ref.watch(todayProvider),
  );
});

/// Adherence for the current block only — the number that actually tells you
/// whether this phase is going well.
final blockAdherenceProvider = FutureProvider<AdherenceStats>((ref) async {
  final merge = await ref.watch(calendarMergeProvider.future);
  final records = await ref.watch(allRecordsProvider.future);
  final week = ref.watch(currentWeekProvider);
  final block = merge.calendar.programme.blockForWeek(week);
  if (block == null) return AdherenceStats.empty;
  return merge.adherence(
    block.firstWeek,
    block.lastWeek,
    records,
    ref.watch(todayProvider),
  );
});

/// Sessions done against sessions required, for one programme week.
///
/// "Done" counts partial sessions: a forty-minute version on a bad evening is
/// a session you turned up for.
final weekProgressProvider =
    FutureProvider.family<({int done, int planned}), int>((ref, weekNo) async {
      final merge = await ref.watch(calendarMergeProvider.future);
      final records = await ref.watch(allRecordsProvider.future);
      final stats = merge.adherence(
        weekNo,
        weekNo,
        records,
        ref.watch(todayProvider),
      );
      return (
        done: stats.completed + stats.partial,
        planned: merge.calendar.requiredSessionsInWeek(weekNo),
      );
    });

typedef DateRange = ({DateTime from, DateTime to});

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `from <= column < end`. Half-open, because `isBetweenValues` includes
/// both ends: a range ending at the next midnight took in the next day's
/// weigh-in and meals.
Expression<bool> _within(
  GeneratedColumn<DateTime> column,
  DateTime from,
  DateTime end,
) => column.isBiggerOrEqualValue(from) & column.isSmallerThanValue(end);

/// Runs, weigh-ins, photo shoots and fed days over a range, as markers.
///
/// Auto-disposed, so a month is recounted each time it comes back into view:
/// a weigh-in logged on the Body screen shows the next time the calendar
/// opens, with no invalidation to forget.
final dayMarkersProvider = FutureProvider.autoDispose
    .family<Map<DateTime, DayMarkers>, DateRange>((ref, range) async {
      final db = ref.watch(databaseProvider);
      final from = _dayOnly(range.from);
      final end = ProgrammeCalendar.addDays(_dayOnly(range.to), 1);

      final runs = await ref.watch(runsBetweenProvider(range).future);
      final weighs = await (db.select(
        db.bodyweights,
      )..where((b) => _within(b.measuredOn, from, end))).get();
      final shoots = await (db.select(
        db.photoShoots,
      )..where((s) => _within(s.shotOn, from, end))).get();
      final meals = await (db.select(
        db.mealLogs,
      )..where((m) => _within(m.loggedOn, from, end))).get();

      final eaten = <DateTime, double>{};
      for (final m in meals) {
        if (m.status == t.MealStatus.planned) continue;
        final d = _dayOnly(m.loggedOn);
        eaten[d] = (eaten[d] ?? 0) + m.portion;
      }
      final fed = <DateTime>[];
      for (final MapEntry(key: d, value: portions) in eaten.entries) {
        final day = await ref.watch(fuelDayProvider(d).future);
        if (mealsHit(eatenPortions: portions, plannedMeals: day.slots.length)) {
          fed.add(d);
        }
      }

      return markersFor(
        runDays: [for (final r in runs) r.runOn],
        weighDays: [for (final w in weighs) w.measuredOn],
        shootDays: [for (final s in shoots) s.shotOn],
        fedDays: fed,
      );
    });

/// A month in one line, for the card under the grid.
final monthSummaryProvider = FutureProvider.autoDispose
    .family<MonthSummary, DateTime>((ref, month) async {
      final entries = await ref.watch(monthEntriesProvider(month).future);
      final db = ref.watch(databaseProvider);
      final first = DateTime(month.year, month.month);
      final last = DateTime(month.year, month.month + 1, 0);
      final range = (from: first, to: last);
      final runs = await ref.watch(runsBetweenProvider(range).future);
      final markers = await ref.watch(dayMarkersProvider(range).future);
      final weighs =
          await (db.select(db.bodyweights)..where(
                (b) => _within(
                  b.measuredOn,
                  first,
                  DateTime(month.year, month.month + 1),
                ),
              ))
              .get();
      return MonthSummary.of(
        entries: entries,
        month: month,
        today: ref.watch(todayProvider),
        runKm: [for (final r in runs) r.distanceM / 1000],
        weighIns: [for (final w in weighs) (w.measuredOn, w.kg)],
        shoots: markers.values.where((m) => m.shoot).length,
        fedDays: markers.values.where((m) => m.fed).length,
      );
    });

/// The stored sessions drawn on one date — its own and any moved here —
/// live, so the sheet shows a correction the moment it is saved.
final sessionsOnProvider = StreamProvider.autoDispose
    .family<List<Session>, DateTime>((ref, date) {
      final db = ref.watch(databaseProvider);
      final d = _dayOnly(date);
      return (db.select(db.sessions)
            ..where(
              (s) =>
                  _within(s.scheduledDate, d, ProgrammeCalendar.addDays(d, 1)),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.plannedDate)]))
          .watch();
    });

/// Everything else that happened on one date, for its sheet.
typedef DayDetails = ({
  double? weighInKg,
  double kcalEaten,
  double kcalPlanned,
  int mealsEaten,
  int mealsPlanned,
  bool shoot,
});

final dayDetailsProvider = FutureProvider.autoDispose
    .family<DayDetails, DateTime>((ref, date) async {
      final db = ref.watch(databaseProvider);
      final d = _dayOnly(date);
      final next = ProgrammeCalendar.addDays(d, 1);
      final weigh =
          await (db.select(db.bodyweights)
                ..where((b) => _within(b.measuredOn, d, next))
                ..limit(1))
              .getSingleOrNull();
      final shoots = await (db.select(
        db.photoShoots,
      )..where((s) => _within(s.shotOn, d, next))).get();
      final eaten = await ref.watch(fuelServiceProvider).eatenOn(d);
      final meals = await ref.watch(fuelServiceProvider).mealsOn(d);
      final plan = await ref.watch(fuelDayProvider(d).future);
      return (
        weighInKg: weigh?.kg,
        kcalEaten: eaten.kcal,
        kcalPlanned: plan.totals.kcal,
        mealsEaten: meals
            .where(
              (m) =>
                  m.status == t.MealStatus.eaten ||
                  m.status == t.MealStatus.partial,
            )
            .length,
        mealsPlanned: plan.slots.length,
        shoot: shoots.isNotEmpty,
      );
    });
