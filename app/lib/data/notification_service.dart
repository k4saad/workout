import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Fires the rest timer while the screen is off.
///
/// The in-app countdown is cosmetic. THIS is what actually gets you back to
/// the bar, so it has to survive the screen locking, the app being swapped
/// out, and Android deciding your isolate is not important.
///
/// Two things v1's plan missed and that matter on a real phone:
///
///  * **Exact alarms.** On Android 12+ a scheduled notification without
///    `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` and
///    `AndroidScheduleMode.exactAllowWhileIdle` is batched by the OS. A 2:30
///    rest becomes "some time in the next ten minutes".
///  * **Battery optimisation.** Xiaomi, Realme and Samsung kill background
///    work aggressively. The app has to ask for an exemption once and say so
///    in the README, or the timer quietly stops working after a week.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const restChannelId = 'rest_timer';
  static const restChannelName = 'Rest timer';
  static const intervalChannelId = 'interval_timer';
  static const intervalChannelName = 'Interval timer';

  static const restNotificationId = 1001;
  static const intervalBaseId = 2000;

  static const reminderChannelId = 'session_reminder';
  static const reminderChannelName = 'Session reminder';
  static const reminderBaseId = 3000;

  /// Fourteen days of reminders is plenty — the app reschedules on every
  /// launch, and a phone that has not been opened in two weeks has bigger
  /// problems than a missing nudge.
  static const reminderHorizonDays = 14;

  /// The planner's reminders: classes, work, sessions, his own entries.
  static const plannerChannelId = 'planner';
  static const plannerChannelName = 'Planner reminders';
  static const plannerBaseId = 4000;

  /// Two weeks of a busy semester is about fifty; Android caps an app's
  /// alarms well above this.
  static const plannerMax = 64;

  bool _ready = false;
  bool _canScheduleExact = false;

  /// True once the OS has confirmed it will honour exact timings.
  ///
  /// When false the UI must say the timer may fire late rather than
  /// pretending it is accurate.
  bool get canScheduleExact => _canScheduleExact;

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (_ready) return;
    try {
      await _init(onTap);
    } catch (_) {
      // No platform (tests, desktop) or a plugin that failed to register.
      // The session must never fail because the phone would not buzz.
      _ready = true;
      _canScheduleExact = false;
    }
  }

  Future<void> _init(void Function(String? payload)? onTap) async {
    // zonedSchedule needs a real timezone, and it has to be the DEVICE's:
    // scheduling in UTC would fire an hour out either side of the clock
    // change, which is exactly when this programme is being run.
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(_zoneName(name)));
    } catch (_) {
      // Unknown or unavailable zone. UTC keeps every DURATION correct, which
      // is all a rest timer needs — it counts forward from now, it does not
      // care what the wall clock says.
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );

    final android13 = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android13 != null) {
      await android13.createNotificationChannel(
        const AndroidNotificationChannel(
          restChannelId,
          restChannelName,
          description: 'Tells you when a rest period is over.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await android13.createNotificationChannel(
        const AndroidNotificationChannel(
          intervalChannelId,
          intervalChannelName,
          description: 'Round changes for skipping and bag work.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Android 13+ runtime permission.
      await android13.requestNotificationsPermission();

      // Exact alarms. If this is refused the timer still works, it is just
      // imprecise — and the UI needs to know so it can be honest about it.
      _canScheduleExact =
          await android13.canScheduleExactNotifications() ?? false;
      if (!_canScheduleExact) {
        await android13.requestExactAlarmsPermission();
        _canScheduleExact =
            await android13.canScheduleExactNotifications() ?? false;
      }
    }

    _ready = true;
  }

  /// Schedules the end-of-rest notification for [at].
  ///
  /// Cancels any previous one first: there is only ever one rest running.
  Future<void> scheduleRestEnd(
    DateTime at, {
    required String exerciseName,
    required int setNumber,
    String? payload,
  }) async {
    await cancelRest();
    if (!at.isAfter(DateTime.now())) return;

    await _zonedSchedule(
      id: restNotificationId,
      at: at,
      channelId: restChannelId,
      channelName: restChannelName,
      title: 'Rest done',
      body: '$exerciseName · set $setNumber',
      payload: payload,
    );
  }

  /// Schedules a cue for each round change of an interval.
  ///
  /// Capped: Android limits how many alarms an app may hold, and a 20-round
  /// skipping session does not need 40 of them.
  Future<void> scheduleIntervalCues(
    List<({DateTime at, String title, String body})> cues, {
    int max = 24,
  }) async {
    await cancelIntervals();
    final now = DateTime.now();
    var i = 0;
    for (final cue in cues) {
      if (i >= max) break;
      if (!cue.at.isAfter(now)) continue;
      await _zonedSchedule(
        id: intervalBaseId + i,
        at: cue.at,
        channelId: intervalChannelId,
        channelName: intervalChannelName,
        title: cue.title,
        body: cue.body,
      );
      i++;
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required DateTime at,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        // Full-screen-ish urgency without hijacking the phone.
        fullScreenIntent: false,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 250, 120, 250]),
        timeoutAfter: 60000,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        details,
        // exactAllowWhileIdle is the whole point: it fires through Doze.
        androidScheduleMode: _canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Losing the notification must never take the session down with it.
      // The in-app countdown still runs; it just will not wake the phone.
    }
  }

  /// flutter_timezone has returned a bare String and a wrapper object across
  /// versions. Accept either rather than pinning to one.
  static String _zoneName(Object raw) {
    if (raw is String) return raw;
    try {
      return (raw as dynamic).identifier as String;
    } catch (_) {
      return raw.toString();
    }
  }

  /// Clears v3's evening nudges, which the planner's reminders replaced.
  Future<void> cancelSessionReminders() => _guard(_cancelReminders);

  /// "Spatial Justice · 14:15 — Room 147": the next week of the planner,
  /// replacing whatever was laid before. Re-laid on every launch and every
  /// change in the planner, so a skipped class goes quiet at once.
  Future<void> schedulePlannerReminders(
    List<({DateTime at, String title, String body})> reminders,
  ) => _guard(() async {
    await _cancelPlanner();
    final now = DateTime.now();
    var id = plannerBaseId;
    for (final r in reminders) {
      if (id >= plannerBaseId + plannerMax) break;
      if (!r.at.isAfter(now)) continue;
      await _zonedSchedule(
        id: id++,
        at: r.at,
        channelId: plannerChannelId,
        channelName: plannerChannelName,
        title: r.title,
        body: r.body,
      );
    }
  });

  Future<void> cancelPlannerReminders() => _guard(_cancelPlanner);

  Future<void> _cancelPlanner() async {
    for (var i = 0; i < plannerMax; i++) {
      await _plugin.cancel(plannerBaseId + i);
    }
  }

  Future<void> _cancelReminders() async {
    for (var i = 0; i < reminderHorizonDays + 2; i++) {
      await _plugin.cancel(reminderBaseId + i);
    }
  }

  Future<void> cancelRest() => _guard(() => _plugin.cancel(restNotificationId));

  Future<void> cancelIntervals() => _guard(() async {
    for (var i = 0; i < 40; i++) {
      await _plugin.cancel(intervalBaseId + i);
    }
  });

  Future<void> cancelAll() => _guard(_plugin.cancelAll);

  /// Runs a plugin call, swallowing platform absence.
  ///
  /// Losing a notification is a degraded timer. Losing the session because a
  /// notification could not be cancelled is a lost workout.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (_) {
      // Intentionally silent — see above.
    }
  }

  /// Whether the app is exempt from battery optimisation.
  ///
  /// Not exposed by the plugin, so the UI simply explains it once and links to
  /// settings; this is a placeholder for a platform channel if it becomes a
  /// real problem in the basement.
  bool get isAndroid => Platform.isAndroid;
}
