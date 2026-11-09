import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_service.dart';
import '../domain/calendar/programme_calendar.dart';
import '../domain/planner/planner.dart';
import 'planner_providers.dart';
import 'providers.dart';
import 'session_providers.dart';

final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

/// The athlete's own switches. Small, and never training data.
class PreferencesNotifier extends AsyncNotifier<Preferences> {
  /// How far ahead reminders are laid.
  static const _days = 14;

  @override
  Future<Preferences> build() => ref.watch(preferencesServiceProvider).load();

  /// Deliberately not named `update` — that is taken by AsyncNotifier and
  /// means something else entirely.
  Future<void> set(Preferences next) async {
    state = AsyncData(await ref.read(preferencesServiceProvider).save(next));
    await _reschedule();
  }

  /// Re-lays the next two weeks of reminders from the planner: classes,
  /// work, sessions, his study and his own entries. Two, so a week without
  /// opening the app still rings.
  ///
  /// Called on every change, on launch and from the planner: a reminder laid
  /// a week ago for a class he has since skipped would still ring.
  Future<void> _reschedule() async {
    final prefs = state.asData?.value;
    final notifications = ref.read(notificationServiceProvider);
    // v3's fixed-time evening nudge is gone: the planner knows the time.
    await notifications.cancelSessionReminders();
    if (prefs == null ||
        !(prefs.remindClasses ||
            prefs.remindWork ||
            prefs.remindSessions ||
            prefs.remindStudy)) {
      await notifications.cancelPlannerReminders();
      return;
    }

    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final planner = await ref.read(dayPlannerProvider.future);
    final bundle = await ref.read(bundleProvider.future);
    final entries = await ref
        .read(plannerRepositoryProvider)
        .between(today, ProgrammeCalendar.addDays(today, _days));
    // Straight from the database, not a live provider: one nobody on
    // screen is listening to is paused, and its future never arrives.
    final db = ref.read(databaseProvider);
    final trained = {
      for (final r in await db.select(db.sessions).get())
        DateTime(
          r.scheduledDate.year,
          r.scheduledDate.month,
          r.scheduledDate.day,
        ),
    };

    final plans = [
      for (var i = 0; i < _days; i++)
        () {
          final day = ProgrammeCalendar.addDays(today, i);
          return planner.plan(
            day,
            session: bundle.calendar.forDate(day).day,
            entries: entries,
          );
        }(),
    ];
    final reminders = const PlannerReminders().build(
      plans,
      from: now,
      travelMinutes: planner.timetable.travelMinutes,
      classes: prefs.remindClasses,
      work: prefs.remindWork,
      sessions: prefs.remindSessions,
      study: prefs.remindStudy,
      trained: trained,
    );
    await notifications.schedulePlannerReminders(reminders);
  }

  /// Ticks a line of a week's shopping list. Saved without re-laying the
  /// reminders: nothing about the evening changed.
  Future<void> toggleShoppingTick(DateTime monday, String foodId) async {
    final current = await future;
    state = AsyncData(
      await ref
          .read(preferencesServiceProvider)
          .save(current.withShoppingTickToggled(monday, foodId)),
    );
  }

  /// Records that a full backup just landed somewhere.
  Future<void> markBackedUp(DateTime at) async {
    final current = state.asData?.value ?? const Preferences();
    state = AsyncData(
      await ref
          .read(preferencesServiceProvider)
          .save(current.copyWith(lastBackupAt: at)),
    );
  }

  /// Safe to call on every launch.
  Future<void> refreshSchedule() async {
    await future;
    await _reschedule();
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, Preferences>(
      PreferencesNotifier.new,
    );
