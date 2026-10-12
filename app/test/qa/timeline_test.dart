import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/screenshot.dart';
import 'qa_harness.dart';

/// J1 and J12: the app across the twelve weeks and past them — every tab and
/// the main drill-downs at the moments the programme changes shape, with
/// the history a real run would have by then.
///
///     flutter test --dart-define=QA=true test/qa/timeline_test.dart
final moments = <(String, DateTime)>[
  ('pre-start', DateTime(2026, 10, 11)), // Sunday before week 1
  ('day-1', DateTime(2026, 10, 12)), // Monday, week 1: the first session
  ('deload', DateTime(2026, 12, 2)), // Wednesday, week 8
  ('test-week', DateTime(2026, 12, 30)), // Wednesday, week 12
  ('last-day', DateTime(2027, 1, 3)), // Sunday, week 12
  ('after-end', DateTime(2027, 1, 20)), // two weeks on
];

const places = <(String, String)>[
  ('today', '/'),
  ('week', '/week'),
  ('calendar', '/week/calendar'),
  ('planner', '/week/planner'),
  ('fuel', '/fuel'),
  ('plan', '/fuel#plan'),
  ('progress', '/progress'),
  ('body', '/progress/body'),
  ('lifts', '/progress/lifts'),
  ('runs', '/progress/runs'),
  ('hikes', '/progress/hikes'),
  ('more', '/more'),
  ('cardio', '/more/cardio'),
  ('next-cycle', '/more/settings/next-cycle'),
  ('history', '/history'),
];

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  final all = <QaIssue>[];

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_qa_time_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('QA-SUMMARY ${all.length} issue(s)');
    for (final i in all) {
      // ignore: avoid_print
      print('QA-ISSUE $i');
    }
  });

  for (final (moment, today) in moments) {
    testWidgets(moment, skip: !qaEnabled, (tester) async {
      await tester.runAsync(
        () => Screenshot.seedHistory(db, repo: repo, today: today),
      );
      final app = QaApp(db: db, repo: repo, tmp: tmp);
      app.collect('$moment start');
      try {
        await app.pump(tester, today: today);
        for (final (name, location) in places) {
          app.collect('$moment $name');
          final plan = location.endsWith('#plan');
          final to = plan ? location.replaceFirst('#plan', '') : location;
          app.router.go(to);
          await QaApp.settle(tester);
          if (plan) {
            await tester.tap(find.text('Plan'));
            await QaApp.settle(tester);
          }
          if (moment != 'week-3') {
            await Screenshot.capture(tester, 'qa_t_${moment}_$name');
          }
          await app.sweep(tester);
          if (plan) {
            await tester.tap(find.text('Today').first);
            await QaApp.settle(tester);
          }
        }
      } catch (e) {
        app.harness(e);
      } finally {
        app.stopCollecting();
        all.addAll(app.issues);
      }
    });
  }
}
