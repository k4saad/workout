import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/planner_repository.dart';
import '../domain/calendar/programme_calendar.dart';
import '../domain/planner/planner.dart';
import 'providers.dart';
import 'session_providers.dart';

/// The semester's week, bundled.
final timetableProvider = FutureProvider<Timetable>(
  (ref) => ref.watch(programmeRepositoryProvider).loadTimetable(),
);

final plannerRepositoryProvider = Provider<PlannerRepository>(
  (ref) => PlannerRepository(ref.watch(databaseProvider)),
);

/// The planner, with the meal slots' targets from the eating plan.
final dayPlannerProvider = FutureProvider<DayPlanner>((ref) async {
  final timetable = await ref.watch(timetableProvider.future);
  final fuel = await ref.watch(fuelPlanProvider.future);
  return DayPlanner(
    timetable: timetable,
    meals: [
      for (final s in fuel.slots)
        MealTarget.sized(id: s.id, name: s.name, time: s.time, kcal: s.kcal),
    ],
  );
});

/// Monday of [date]'s week.
DateTime mondayOf(DateTime date) => ProgrammeCalendar.addDays(
  DateTime(date.year, date.month, date.day),
  1 - date.weekday,
);

/// His planner entries for the week starting [monday], live.
final plannerWeekEntriesProvider =
    StreamProvider.family<List<PlannerEntry>, DateTime>(
      (ref, monday) => ref
          .watch(plannerRepositoryProvider)
          .watch(monday, ProgrammeCalendar.addDays(monday, 6)),
    );

/// [date], planned: the timetable, his entries, the session, the meals.
final dayPlanProvider = FutureProvider.family<DayPlan, DateTime>((
  ref,
  date,
) async {
  final day = DateTime(date.year, date.month, date.day);
  final planner = await ref.watch(dayPlannerProvider.future);
  final bundle = await ref.watch(bundleProvider.future);
  final entries = await ref.watch(
    plannerWeekEntriesProvider(mondayOf(day)).future,
  );
  return planner.plan(
    day,
    session: bundle.calendar.forDate(day).day,
    entries: entries,
  );
});
