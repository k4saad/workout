import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_service.dart';
import '../domain/calendar/session_reminders.dart';
import 'calendar_providers.dart';
import 'providers.dart';
import 'session_providers.dart';

final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

/// The athlete's own switches. Small, and never training data.
class PreferencesNotifier extends AsyncNotifier<Preferences> {
  @override
  Future<Preferences> build() => ref.watch(preferencesServiceProvider).load();

  /// Deliberately not named `update` — that is taken by AsyncNotifier and
  /// means something else entirely.
  Future<void> set(Preferences next) async {
    state = AsyncData(await ref.read(preferencesServiceProvider).save(next));
    await _reschedule();
  }

  /// Re-lays the next fortnight of reminders.
  ///
  /// Called on every change and on launch: a reminder scheduled two weeks ago
  /// against a programme that has since been edited would announce the wrong
  /// session.
  Future<void> _reschedule() async {
    final prefs = state.asData?.value;
    final notifications = ref.read(notificationServiceProvider);
    if (prefs == null || !prefs.eveningReminder) {
      await notifications.cancelSessionReminders();
      return;
    }

    final bundle = await ref.read(bundleProvider.future);
    final records = await ref.read(allRecordsProvider.future);
    final logged = {
      for (final r in records)
        DateTime(
          r.scheduledDate.year,
          r.scheduledDate.month,
          r.scheduledDate.day,
        ),
    };

    final reminders = SessionReminders(bundle.calendar).upcoming(
      from: DateTime.now(),
      loggedDates: logged,
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
    );
    await notifications.scheduleSessionReminders(reminders);
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
