import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/screenshot.dart';

/// A walk through every tab and the main drill-downs, written to
/// `build/screens/*.png` so the app can be LOOKED at without a phone.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/
///
/// Off by default: it proves nothing a normal run needs, and writing PNGs on
/// every `flutter test` would be noise.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

/// Routes to capture, as (file name, location).
const routes = <(String, String)>[
  ('today', '/'),
  ('week', '/week'),
  ('calendar', '/week/calendar'),
  ('day-detail', '/week/1/day/f-mon'),
  ('fuel', '/fuel'),
  ('progress', '/progress'),
  ('progress-body', '/progress/body'),
  ('progress-photos', '/progress/photos'),
  ('progress-lifts', '/progress/lifts'),
  ('more', '/more'),
  ('exercises', '/more/exercises'),
  ('exercise-squat', '/more/exercises/barbell-back-squat'),
  ('exercise-pullup', '/more/exercises/pull-up'),
  ('runner', '/run/1/f-mon'),
  ('cardio', '/more/cardio'),
  ('settings', '/more/settings'),
  ('settings-gym', '/more/settings/gym'),
  ('history', '/history'),
];

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_tour_');
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

  // A phone before week 1: what Saad sees the day he installs it.
  for (final (name, location) in routes) {
    testWidgets('pre-start: $name', skip: !_enabled, (tester) async {
      Screenshot.phone(tester);
      await Screenshot.pumpApp(
        tester,
        db: db,
        repo: repo,
        location: location,
        overrides: [Screenshot.pinToday(DateTime(2026, 9, 23))],
      );
      await Screenshot.capture(tester, 'pre_$name');
    });
  }

  // Mid-programme: week 3, with three weeks of history behind it.
  for (final (name, location) in routes) {
    testWidgets('week 3: $name', skip: !_enabled, (tester) async {
      final today = DateTime(2026, 10, 14);
      await tester.runAsync(
        () => Screenshot.seedHistory(db, repo: repo, today: today),
      );
      Screenshot.phone(tester);
      await Screenshot.pumpApp(
        tester,
        db: db,
        repo: repo,
        location: location,
        overrides: [Screenshot.pinToday(today)],
      );
      await Screenshot.capture(tester, 'w3_$name');
    });
  }
}
