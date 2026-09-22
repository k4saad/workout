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
}
