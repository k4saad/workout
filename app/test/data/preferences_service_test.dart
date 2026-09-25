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

  group('who the app is talking to', () {
    test('it greets Saad out of the box', () {
      expect(const Preferences().athleteName, 'Saad');
      expect(const Preferences().launchQuote, isTrue);
      expect(const Preferences().recentQuoteIds, isEmpty);
    });

    test(
      'a v2 preferences file with none of the new keys still loads',
      () async {
        File('${tmp.path}/${PreferencesService.fileName}').writeAsStringSync(
          '{"eveningReminder": true, "reminderHour": 19, "reminderMinute": 0}',
        );
        final p = await PreferencesService(documentsDir: tmp).load();
        expect(p.eveningReminder, isTrue);
        expect(p.reminderHour, 19);
        expect(p.athleteName, 'Saad');
        expect(p.launchQuote, isTrue);
        expect(p.recentQuoteIds, isEmpty);
      },
    );

    test('a blank name falls back rather than greeting nobody', () {
      final p = Preferences.fromJson({'athleteName': '   '});
      expect(p.athleteName, 'Saad');
    });

    test('name, switch and quote history round-trip', () async {
      await PreferencesService(documentsDir: tmp).save(
        const Preferences(
          athleteName: 'Saad K.',
          launchQuote: false,
          recentQuoteIds: ['q2', 'q1'],
        ),
      );
      final p = await PreferencesService(documentsDir: tmp).load();
      expect(p.athleteName, 'Saad K.');
      expect(p.launchQuote, isFalse);
      expect(p.recentQuoteIds, ['q2', 'q1']);
    });

    test('remembers the quote of the day and its round', () {
      final p = const Preferences().withQuoteOfDay(
        day: DateTime(2026, 10, 19, 7, 30),
        id: 'q2',
        cycle: const ['q2', 'q1'],
      );
      expect(p.quoteDay, DateTime(2026, 10, 19));
      expect(p.quoteId, 'q2');
      expect(p.recentQuoteIds, ['q2', 'q1']);
      final back = Preferences.fromJson(p.toJson());
      expect(back.quoteDay, DateTime(2026, 10, 19));
      expect(back.quoteId, 'q2');
      expect(back.recentQuoteIds, ['q2', 'q1']);
    });

    test('a round is not cut short: every quote shown stays in it', () {
      final cycle = [for (var i = 0; i < 80; i++) 'q$i'];
      final p = const Preferences().withQuoteOfDay(
        day: DateTime(2026, 12, 1),
        id: 'q0',
        cycle: cycle,
      );
      expect(Preferences.fromJson(p.toJson()).recentQuoteIds, hasLength(80));
    });
  });

  group('capture and checkpoints', () {
    test('front camera and a ten-second timer by default', () {
      const p = Preferences();
      expect(p.captureFront, isTrue);
      expect(p.captureTimerSec, 10);
    });

    test('a hand tick toggles, and belongs to its week only', () {
      var p = const Preferences().withTickToggled(4, 2);
      expect(p.ticksFor(4), {2});
      expect(p.ticksFor(8), isEmpty);
      p = p.withTickToggled(8, 2).withTickToggled(4, 2);
      expect(p.ticksFor(4), isEmpty);
      expect(p.ticksFor(8), {2});
    });

    test('survives a round trip, and a bad timer falls back', () {
      final p = const Preferences(
        captureFront: false,
        captureTimerSec: 5,
      ).withTickToggled(1, 3);
      final back = Preferences.fromJson(p.toJson());
      expect(back.captureFront, isFalse);
      expect(back.captureTimerSec, 5);
      expect(back.ticksFor(1), {3});
      expect(Preferences.fromJson({'captureTimerSec': 7}).captureTimerSec, 10);
    });
  });
}
