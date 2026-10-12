import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/fake_terrain.dart';
import '../support/screenshot.dart';
import 'qa_harness.dart';

/// J14: every screen on a small phone, at a large text size, and at the
/// largest, with real fonts — the layouts that only break for someone who
/// needs bigger text or has a cheaper phone.
///
///     flutter test --dart-define=QA=true test/qa/layout_stress_test.dart
const routes = <(String, String)>[
  ('today', '/'),
  ('history', '/history'),
  ('week', '/week'),
  ('calendar', '/week/calendar'),
  ('planner', '/week/planner'),
  ('day', '/week/3/day/f-mon'),
  ('fuel', '/fuel'),
  ('fuel-plan', '/fuel#plan'),
  ('progress', '/progress'),
  ('body', '/progress/body'),
  ('photos', '/progress/photos'),
  ('runs', '/progress/runs'),
  ('hikes', '/progress/hikes'),
  ('hike', '/progress/hikes/1'),
  ('lifts', '/progress/lifts'),
  ('more', '/more'),
  ('exercises', '/more/exercises'),
  ('squat', '/more/exercises/barbell-back-squat'),
  ('cardio', '/more/cardio'),
  ('settings', '/more/settings'),
  ('gym', '/more/settings/gym'),
  ('editor', '/more/settings/programme'),
  ('files', '/more/settings/files'),
  ('next-cycle', '/more/settings/next-cycle'),
  ('runner', '/run/3/f-mon'),
];

const configs = <(String, Size, double)>[
  ('small', Size(360, 640), 1.0),
  ('small-1.3x', Size(360, 640), 1.3),
  ('phone-2x', Size(412, 915), 2.0),
];

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  final today = DateTime(2026, 10, 28); // Wednesday, week 3
  final all = <QaIssue>[];

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_qa_layout_');
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
    // One line per problem, for the QA log.
    // ignore: avoid_print
    print('QA-SUMMARY ${all.length} issue(s)');
    for (final i in all) {
      // ignore: avoid_print
      print('QA-ISSUE $i');
    }
  });

  for (final (cfg, size, scale) in configs) {
    for (final (name, location) in routes) {
      testWidgets('$cfg: $name', skip: !qaEnabled, (tester) async {
        await tester.runAsync(
          () => Screenshot.seedHistory(db, repo: repo, today: today),
        );
        if (name.startsWith('hike')) await tester.runAsync(() => seedHike(db));
        final app = QaApp(db: db, repo: repo, tmp: tmp);
        app.collect('$cfg $name');
        try {
          await app.pump(tester, today: today, size: size, textScale: scale);
          final plan = location.endsWith('#plan');
          final to = plan ? location.replaceFirst('#plan', '') : location;
          if (to.startsWith('/run/')) {
            app.router.push(to);
          } else if (to != '/') {
            app.router.go(to);
          }
          await QaApp.settle(tester);
          if (plan) {
            await tester.tap(find.text('Plan'));
            await QaApp.settle(tester);
          }
          await app.sweep(tester);
          if (app.issues.isNotEmpty || cfg == 'small-1.3x') {
            await Screenshot.capture(tester, 'qa_${cfg}_$name');
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
}
