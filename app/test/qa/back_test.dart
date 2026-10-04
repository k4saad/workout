import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import 'qa_harness.dart';

/// J15: back from every page opened inside a tab walks up to that page's
/// parent, in the same tab — never out of the app, never to another tab.
///
///     flutter test --dart-define=QA=true test/qa/back_test.dart
const drillDowns = <(String, String, int)>[
  // (page, the parent it must come back to, its tab)
  ('/history', '/', 0),
  ('/week/calendar', '/week', 1),
  ('/week/3/day/f-tue', '/week', 1),
  ('/progress/body', '/progress', 3),
  ('/progress/photos', '/progress', 3),
  ('/progress/runs', '/progress', 3),
  ('/progress/hikes', '/progress', 3),
  ('/progress/lifts', '/progress', 3),
  ('/more/exercises', '/more', 4),
  ('/more/exercises/barbell-back-squat', '/more/exercises', 4),
  ('/more/cardio', '/more', 4),
  ('/more/settings', '/more', 4),
  ('/more/settings/gym', '/more/settings', 4),
  ('/more/settings/programme', '/more/settings', 4),
  ('/more/settings/files', '/more/settings', 4),
  ('/more/settings/next-cycle', '/more/settings', 4),
];

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  final all = <QaIssue>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kt_qa_back_');
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

  for (final (page, parent, tab) in drillDowns) {
    testWidgets('back from $page', skip: !qaEnabled, (tester) async {
      final app = QaApp(db: db, repo: repo, tmp: tmp);
      app.collect('back $page');
      try {
        await app.pump(tester, today: DateTime(2026, 10, 28));
        app.router.go(page);
        await QaApp.settle(tester);

        await tester.binding.handlePopRoute();
        await QaApp.settle(tester);

        final here = app.router.routerDelegate.currentConfiguration.uri.path;
        final bar = tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .selectedIndex;
        if (here != parent) {
          app.harness('back from $page landed on $here, not $parent');
        }
        if (bar != tab) {
          app.harness('back from $page switched to tab $bar, not $tab');
        }
        if (find.text('Close the app?').evaluate().isNotEmpty) {
          app.harness('back from $page offered to close the app');
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
