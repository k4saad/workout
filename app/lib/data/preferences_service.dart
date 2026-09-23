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
    this.lastBackupAt,
    this.athleteName = defaultAthleteName,
    this.launchQuote = true,
    this.recentQuoteIds = const [],
  });

  static const defaultAthleteName = 'Saad';

  /// How many recent quotes are remembered so the launch screen does not
  /// repeat itself.
  static const quoteMemory = 40;

  /// Off by default. An app that starts by nagging gets uninstalled.
  final bool eveningReminder;

  final int reminderHour;
  final int reminderMinute;

  /// When a full backup was last written. Null means never.
  final DateTime? lastBackupAt;

  /// Who the launch screen and the greetings address.
  final String athleteName;

  /// Whether a quote greets you on a cold start.
  final bool launchQuote;

  /// Quote ids shown recently, newest first, at most [quoteMemory].
  final List<String> recentQuoteIds;

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
    int? reminderHour,
    int? reminderMinute,
    DateTime? lastBackupAt,
    String? athleteName,
    bool? launchQuote,
    List<String>? recentQuoteIds,
  }) => Preferences(
    eveningReminder: eveningReminder ?? this.eveningReminder,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    athleteName: athleteName ?? this.athleteName,
    launchQuote: launchQuote ?? this.launchQuote,
    recentQuoteIds: recentQuoteIds ?? this.recentQuoteIds,
  );

  /// Remembers [id] as just shown, newest first, capped at [quoteMemory].
  Preferences withQuoteShown(String id) => copyWith(
    recentQuoteIds: [
      id,
      ...recentQuoteIds.where((q) => q != id),
    ].take(quoteMemory).toList(),
  );

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
    eveningReminder: j['eveningReminder'] as bool? ?? false,
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
  );

  Map<String, dynamic> toJson() => {
    'eveningReminder': eveningReminder,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'athleteName': athleteName,
    'launchQuote': launchQuote,
    'recentQuoteIds': recentQuoteIds,
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
