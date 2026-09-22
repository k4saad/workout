import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/preferences_service.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('kt_prefs_'));

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle open a moment longer.
    }
  });

  test('a fresh install reminds you of nothing', () async {
    final prefs = await PreferencesService(documentsDir: tmp).load();
    expect(prefs.eveningReminder, isFalse);
    expect(prefs.reminderLabel, '18:30');
  });

  test('a saved preference survives a restart', () async {
    await PreferencesService(documentsDir: tmp).save(
      const Preferences(
        eveningReminder: true,
        reminderHour: 17,
        reminderMinute: 5,
      ),
    );

    final reloaded = await PreferencesService(documentsDir: tmp).load();
    expect(reloaded.eveningReminder, isTrue);
    expect(reloaded.reminderLabel, '17:05');
  });

  test('a corrupt file falls back to defaults rather than crashing', () async {
    File('${tmp.path}/${PreferencesService.fileName}')
        .writeAsStringSync('{ not json');

    final prefs = await PreferencesService(documentsDir: tmp).load();
    expect(prefs.eveningReminder, isFalse);
  });

  test('copyWith changes one thing at a time', () {
    const base = Preferences(eveningReminder: true, reminderHour: 20);
    expect(base.copyWith(reminderHour: 7).eveningReminder, isTrue);
    expect(base.copyWith(eveningReminder: false).reminderHour, 20);
  });

  group('the backup reminder', () {
    final now = DateTime(2026, 11, 20);

    test('never backed up counts as stale', () {
      expect(const Preferences().backupIsStale(now), isTrue);
      expect(const Preferences().daysSinceBackup(now), isNull);
    });

    test('a backup last week is still fine', () {
      final prefs = Preferences(lastBackupAt: DateTime(2026, 11, 14));
      expect(prefs.backupIsStale(now), isFalse);
      expect(prefs.daysSinceBackup(now), 6);
    });

    test('a fortnight is the line', () {
      expect(
        Preferences(lastBackupAt: DateTime(2026, 11, 6)).backupIsStale(now),
        isTrue,
      );
      expect(
        Preferences(lastBackupAt: DateTime(2026, 11, 7)).backupIsStale(now),
        isFalse,
      );
    });

    test('the backup date round-trips through the file', () async {
      final at = DateTime(2026, 11, 14, 21, 30);
      await PreferencesService(documentsDir: tmp)
          .save(Preferences(lastBackupAt: at));

      final reloaded = await PreferencesService(documentsDir: tmp).load();
      expect(reloaded.lastBackupAt, at);
      expect(reloaded.backupIsStale(now), isFalse);
    });
  });
}
