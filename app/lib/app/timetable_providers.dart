import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/planner/planner.dart';
import '../domain/programme/programme_validator.dart' show Problem;
import 'planner_providers.dart';
import 'providers.dart';
import 'settings_providers.dart';

const timetableValidator = TimetableValidator();

/// What is wrong with his week as it stands, shown above it in the editor:
/// V22, as the phone runs it.
final timetableProblemsProvider = FutureProvider<List<Problem>>(
  (ref) async =>
      timetableValidator.check(await ref.watch(timetableProvider.future)),
);

/// Whether the week is one he has changed, or still the shipped one.
final timetableEditedProvider = FutureProvider<bool>((ref) async {
  await ref.watch(timetableProvider.future);
  return ref.watch(programmeRepositoryProvider).timetableIsEdited;
});

/// Changes his week, then refreshes everything that reads it — the
/// planner, Fuel's meal times, Today's day — and re-lays the reminders, so
/// a class he deleted does not still ring.
class TimetableEditController extends Notifier<void> {
  @override
  void build() {}

  /// Applies [edit] to the week as it is on disk and saves the result.
  Future<Timetable> apply(Timetable Function(Timetable) edit) async {
    final repo = ref.read(programmeRepositoryProvider);
    final saved = await repo.saveTimetable(edit(await repo.loadTimetable()));
    await _refresh();
    return saved;
  }

  /// Puts [timetable] back exactly: the undo after a delete.
  Future<Timetable> restore(Timetable timetable) => apply((_) => timetable);

  /// Back to the shipped week.
  Future<Timetable> reset() async {
    final restored = await ref
        .read(programmeRepositoryProvider)
        .resetTimetable();
    await _refresh();
    return restored;
  }

  /// A backup was just restored, and may have brought a week with it.
  Future<void> refreshAfterRestore() async {
    ref.read(programmeRepositoryProvider).invalidateTimetable();
    await _refresh();
  }

  Future<void> _refresh() async {
    final schedule = ref.read(preferencesProvider.notifier);
    ref
      ..invalidate(timetableProvider)
      ..invalidate(timetableEditedProvider);
    await schedule.refreshSchedule();
  }
}

final timetableEditControllerProvider =
    NotifierProvider<TimetableEditController, void>(
      TimetableEditController.new,
    );
