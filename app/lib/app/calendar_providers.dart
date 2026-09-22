import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart' show Session;
import '../data/db/tables.dart' as t;
import '../domain/calendar/adherence.dart';
import '../domain/calendar/programme_calendar.dart';
import 'providers.dart';
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

/// Every session ever logged, as domain records.
final allRecordsProvider = FutureProvider<List<SessionRecord>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.sessions).get();
  return rows.map(_toRecord).toList();
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
