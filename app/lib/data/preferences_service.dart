import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The handful of things the athlete can switch on or off.
///
/// Deliberately tiny and deliberately not in the database: these are
/// conveniences, not training data. Losing them costs one toggle; a schema
/// migration to store a boolean would put twelve weeks of logs at risk for
/// nothing.
class Preferences {
  const Preferences({
    this.eveningReminder = false,
    this.reminderHour = 18,
    this.reminderMinute = 30,
    this.remindClasses = true,
    this.remindWork = true,
    this.remindSessions = true,
    this.lastBackupAt,
    this.athleteName = defaultAthleteName,
    this.launchQuote = true,
    this.recentQuoteIds = const [],
    this.quoteDay,
    this.quoteId,
    this.captureFront = true,
    this.captureTimerSec = 10,
    this.checkpointTicks = const [],
    this.shoppingTicks = const [],
  });

  static const defaultAthleteName = 'Saad';

  /// v3's fixed-time evening nudge. Replaced in v4.1 by the planner's
  /// reminders, which know when the session is; kept so an old file reads.
  final bool eveningReminder;

  final int reminderHour;
  final int reminderMinute;

  /// The planner's reminders (docs/12-semester-plan.md): a class 15 minutes
  /// before, work when it is time to leave, a session 30 minutes before. On
  /// by default: he asked for them.
  final bool remindClasses;
  final bool remindWork;
  final bool remindSessions;

  /// When a full backup was last written. Null means never.
  final DateTime? lastBackupAt;

  /// Who the launch screen and the greetings address.
  final String athleteName;

  /// Whether a quote greets you on a cold start.
  final bool launchQuote;

  /// The quotes shown in the current round, newest first. None comes back
  /// until every quote has had its day.
  final List<String> recentQuoteIds;

  /// The date [quoteId] was chosen for: the quote of that day.
  final DateTime? quoteDay;
  final String? quoteId;

  /// Progress photos on the front camera: he trains alone, and only the
  /// screen side lets him see the ghost he is lining up with. Remembered,
  /// because a shoot on the other lens frames him differently.
  final bool captureFront;

  /// The self-timer: long enough to prop the phone and step back.
  final int captureTimerSec;

  /// Checkpoint lines ticked by hand, as `week:index`. The lines the app
  /// can check itself are never stored here.
  final List<String> checkpointTicks;

  /// Shopping-list lines in the basket, as `yyyy-mm-dd:foodId` against the
  /// Monday of the week being shopped for.
  final List<String> shoppingTicks;

  /// The self-timer lengths offered.
  static const captureTimers = [3, 5, 10];

  /// Indices ticked by hand in [week]'s checkpoint.
  Set<int> ticksFor(int week) => {
    for (final k in checkpointTicks)
      if (k.split(':') case [final w, final i] when int.tryParse(w) == week)
        ?int.tryParse(i),
  };

  /// Ticks or unticks one line of [week]'s checkpoint.
  Preferences withTickToggled(int week, int index) {
    final key = '$week:$index';
    return copyWith(
      checkpointTicks: checkpointTicks.contains(key)
          ? [
              for (final k in checkpointTicks)
                if (k != key) k,
            ]
          : [...checkpointTicks, key],
    );
  }

  static String _weekKey(DateTime monday) =>
      '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';

  /// The foods ticked off the list for the week starting [monday].
  Set<String> shoppingTicksFor(DateTime monday) {
    final prefix = '${_weekKey(monday)}:';
    return {
      for (final k in shoppingTicks)
        if (k.startsWith(prefix)) k.substring(prefix.length),
    };
  }

  /// Ticks or unticks [foodId] on [monday]'s list. Weeks more than a
  /// fortnight before it are dropped: nobody shops last month's list.
  Preferences withShoppingTickToggled(DateTime monday, String foodId) {
    final key = '${_weekKey(monday)}:$foodId';
    final oldest = _weekKey(
      DateTime(monday.year, monday.month, monday.day - 14),
    );
    final kept = [
      for (final k in shoppingTicks)
        if (k != key && k.split(':').first.compareTo(oldest) >= 0) k,
    ];
    return copyWith(
      shoppingTicks: shoppingTicks.contains(key) ? kept : [...kept, key],
    );
  }

  /// How long the app stays quiet about backups.
  static const staleAfterDays = 14;

  /// True when there is training data worth losing and no recent copy of it.
  bool backupIsStale(DateTime now) {
    final last = lastBackupAt;
    if (last == null) return true;
    return now.difference(last).inDays >= staleAfterDays;
  }

  int? daysSinceBackup(DateTime now) =>
      lastBackupAt == null ? null : now.difference(lastBackupAt!).inDays;

  String get reminderLabel =>
      '${reminderHour.toString().padLeft(2, '0')}:'
      '${reminderMinute.toString().padLeft(2, '0')}';

  Preferences copyWith({
    bool? eveningReminder,
    bool? remindClasses,
    bool? remindWork,
    bool? remindSessions,
    int? reminderHour,
    int? reminderMinute,
    DateTime? lastBackupAt,
    String? athleteName,
    bool? launchQuote,
    List<String>? recentQuoteIds,
    DateTime? quoteDay,
    String? quoteId,
    bool? captureFront,
    int? captureTimerSec,
    List<String>? checkpointTicks,
    List<String>? shoppingTicks,
  }) => Preferences(
    eveningReminder: eveningReminder ?? this.eveningReminder,
    remindClasses: remindClasses ?? this.remindClasses,
    remindWork: remindWork ?? this.remindWork,
    remindSessions: remindSessions ?? this.remindSessions,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    athleteName: athleteName ?? this.athleteName,
    launchQuote: launchQuote ?? this.launchQuote,
    recentQuoteIds: recentQuoteIds ?? this.recentQuoteIds,
    quoteDay: quoteDay ?? this.quoteDay,
    quoteId: quoteId ?? this.quoteId,
    captureFront: captureFront ?? this.captureFront,
    captureTimerSec: captureTimerSec ?? this.captureTimerSec,
    checkpointTicks: checkpointTicks ?? this.checkpointTicks,
    shoppingTicks: shoppingTicks ?? this.shoppingTicks,
  );

  /// Remembers [id] as the quote of [day], and the round it belongs to.
  Preferences withQuoteOfDay({
    required DateTime day,
    required String id,
    required List<String> cycle,
  }) => copyWith(
    quoteDay: DateTime(day.year, day.month, day.day),
    quoteId: id,
    recentQuoteIds: cycle,
  );

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
    eveningReminder: j['eveningReminder'] as bool? ?? false,
    remindClasses: j['remindClasses'] as bool? ?? true,
    remindWork: j['remindWork'] as bool? ?? true,
    remindSessions: j['remindSessions'] as bool? ?? true,
    reminderHour: (j['reminderHour'] as num?)?.toInt() ?? 18,
    reminderMinute: (j['reminderMinute'] as num?)?.toInt() ?? 30,
    lastBackupAt: j['lastBackupAt'] == null
        ? null
        : DateTime.tryParse(j['lastBackupAt'] as String),
    athleteName: switch (j['athleteName']) {
      final String n when n.trim().isNotEmpty => n.trim(),
      _ => defaultAthleteName,
    },
    launchQuote: j['launchQuote'] as bool? ?? true,
    recentQuoteIds: [
      for (final q in (j['recentQuoteIds'] as List?) ?? const [])
        if (q is String) q,
    ],
    quoteDay: switch (j['quoteDay']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    quoteId: j['quoteId'] as String?,
    captureFront: j['captureFront'] as bool? ?? true,
    captureTimerSec: switch (j['captureTimerSec']) {
      final num n when captureTimers.contains(n.toInt()) => n.toInt(),
      _ => 10,
    },
    checkpointTicks: [
      for (final k in (j['checkpointTicks'] as List?) ?? const [])
        if (k is String) k,
    ],
    shoppingTicks: [
      for (final k in (j['shoppingTicks'] as List?) ?? const [])
        if (k is String) k,
    ],
  );

  Map<String, dynamic> toJson() => {
    'eveningReminder': eveningReminder,
    'remindClasses': remindClasses,
    'remindWork': remindWork,
    'remindSessions': remindSessions,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'athleteName': athleteName,
    'launchQuote': launchQuote,
    'recentQuoteIds': recentQuoteIds,
    'quoteDay': quoteDay?.toIso8601String(),
    'quoteId': quoteId,
    'captureFront': captureFront,
    'captureTimerSec': captureTimerSec,
    'checkpointTicks': checkpointTicks,
    'shoppingTicks': shoppingTicks,
  };
}

/// Reads and writes `preferences.json` in the app documents directory.
class PreferencesService {
  PreferencesService({Directory? documentsDir}) : _override = documentsDir;

  static const fileName = 'preferences.json';

  final Directory? _override;
  Preferences? _cached;

  Future<File> _file() async {
    final dir = _override ?? await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File(p.join(dir.path, fileName));
  }

  Future<Preferences> load() async {
    if (_cached != null) return _cached!;
    final f = await _file();
    if (!f.existsSync()) return _cached = const Preferences();
    try {
      return _cached = Preferences.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      // A corrupt preferences file must never stop the app opening.
      return _cached = const Preferences();
    }
  }

  Future<Preferences> save(Preferences prefs) async {
    final f = await _file();
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(prefs.toJson()),
      flush: true,
    );
    return _cached = prefs;
  }
}
