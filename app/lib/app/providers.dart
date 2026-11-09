import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/programme_repository.dart';
import '../domain/calendar/programme_calendar.dart';
import '../domain/fuel/fuel_plan.dart';
import '../domain/models/exercise.dart';
import '../domain/models/inventory.dart';
import '../domain/models/programme.dart';
import '../domain/plates/lattice.dart';
import '../domain/programme/block_resolver.dart';

/// The repository. Overridden in tests with a temp directory.
final programmeRepositoryProvider = Provider<ProgrammeRepository>(
  (ref) => ProgrammeRepository(),
);

/// The active programme — user copy if edited, shipped asset otherwise.
final programmeProvider = FutureProvider<Programme>(
  (ref) => ref.watch(programmeRepositoryProvider).loadProgramme(),
);

final exerciseLibraryProvider = FutureProvider<ExerciseLibrary>(
  (ref) => ref.watch(programmeRepositoryProvider).loadLibrary(),
);

final inventoryProvider = FutureProvider<Inventory>(
  (ref) => ref.watch(programmeRepositoryProvider).loadInventory(),
);

/// The eating plan, generated and bundled.
final fuelPlanProvider = FutureProvider<FuelPlan>(
  (ref) => ref.watch(programmeRepositoryProvider).loadFuel(),
);

/// Everything the UI needs in one shot, so screens do not juggle three
/// separate async values.
typedef ProgrammeBundle = ({
  Programme programme,
  ExerciseLibrary library,
  Inventory inventory,
  ProgrammeCalendar calendar,
  BlockResolver resolver,
  Lattice lattice,
});

final bundleProvider = FutureProvider<ProgrammeBundle>((ref) async {
  final repo = ref.watch(programmeRepositoryProvider);
  final programme = await repo.loadProgramme();
  final library = await repo.loadLibrary();
  final inventory = await repo.loadInventory();
  return (
    programme: programme,
    library: library,
    inventory: inventory,
    calendar: ProgrammeCalendar(programme),
    resolver: BlockResolver(programme),
    lattice: Lattice(inventory),
  );
});

/// "Now", as a date. Overridable in tests and by the debug date picker, so a
/// screen never calls DateTime.now() directly.
class TodayNotifier extends Notifier<DateTime> {
  bool _pinned = false;

  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Pins the date by hand; [refresh] leaves it alone from then on.
  void set(DateTime d) {
    _pinned = true;
    state = DateTime(d.year, d.month, d.day);
  }

  /// Moves on to the new date once the clock has passed midnight. Android
  /// keeps the app in memory for days, and opened the next morning it must
  /// not still be showing yesterday. Called on resume and at midnight.
  void refresh([DateTime Function() now = DateTime.now]) {
    if (_pinned) return;
    final n = now();
    final d = DateTime(n.year, n.month, n.day);
    if (d != state) state = d;
  }
}

/// The time now, for what is laid against the clock — the reminders. The
/// real clock on the phone; a fixed one in a test, so a test about Monday 9
/// November still passes in December.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The midnight after [t], by the calendar rather than by adding 24 hours:
/// the night the clocks change is 23 or 25 hours long.
DateTime nextMidnight(DateTime t) => DateTime(t.year, t.month, t.day + 1);

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

/// The programme day for [todayProvider].
final todayPlannedProvider = FutureProvider<PlannedDay>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  return bundle.calendar.forDate(ref.watch(todayProvider));
});

/// Which programme week the Week screen is showing. Null means "follow the
/// current week"; paging pins it.
class SelectedWeekNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? week) => state = week;
}

final selectedWeekProvider = NotifierProvider<SelectedWeekNotifier, int?>(
  SelectedWeekNotifier.new,
);

/// The programme week containing "today", clamped into range.
///
/// Synchronous on purpose: as a FutureProvider this flashed week 1 for a frame
/// before resolving, which reads as a glitch every time the screen opens.
final currentWeekProvider = Provider<int>((ref) {
  final bundle = ref.watch(bundleProvider).asData?.value;
  if (bundle == null) return 1;
  final w = bundle.calendar.weekNumberFor(ref.watch(todayProvider));
  return w.clamp(1, bundle.programme.totalWeeks);
});

/// The week the Week screen is showing: pinned if the user paged, otherwise
/// whichever week today falls in.
final viewedWeekProvider = Provider<int>(
  (ref) => ref.watch(selectedWeekProvider) ?? ref.watch(currentWeekProvider),
);
