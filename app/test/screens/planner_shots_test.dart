import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/planner_repository.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/screenshot.dart';

/// The planner and what it feeds, rendered: `build/screens/planner_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/planner_shots_test.dart
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  // The first week of term.
  final monday = DateTime(2026, 10, 12);

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_planner_shots_');
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

  List<Override> overrides() => [
    Screenshot.pinToday(monday),
    preferencesServiceProvider.overrideWithValue(
      PreferencesService(documentsDir: tmp),
    ),
  ];

  Future<void> openSheet(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await Screenshot.settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await Screenshot.settle(tester);
  }

  testWidgets('the planner, a week of term', skip: !_enabled, (tester) async {
    // An exam to plan around on the Saturday, and the Friday he works.
    await tester.runAsync(() async {
      final planner = PlannerRepository(db);
      await planner.addEvent(
        date: DateTime(2026, 10, 17),
        title: 'GIS exam prep',
        start: 14 * 60,
        end: 16 * 60,
        category: 'study',
      );
      await planner.setMarked(DateTime(2026, 10, 16), 'job2-fri', true);
    });
    Screenshot.phone(tester, height: 1700);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/week/planner',
      overrides: overrides(),
    );
    await Screenshot.settle(tester, rounds: 24);
    await Screenshot.capture(tester, 'planner_mon');

    await tester.tap(find.text('13'));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_tue');

    await tester.tap(find.text('16'));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_fri');

    await tester.tap(find.text('17'));
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_sat');

    Screenshot.phone(tester);
    await tester.tap(find.text('12'));
    await Screenshot.settle(tester);
    await openSheet(tester, find.text('Full Body A'));
    await Screenshot.capture(tester, 'planner_session_sheet');
    Navigator.of(tester.element(find.text('STARTS AT'))).pop();
    await Screenshot.settle(tester);

    await openSheet(tester, find.text('Geoinformation in Society'));
    await Screenshot.capture(tester, 'planner_class_sheet');
    Navigator.of(tester.element(find.text('Skip this one'))).pop();
    await Screenshot.settle(tester);

    await openSheet(tester, find.text('Add to this day'));
    await Screenshot.capture(tester, 'planner_add_sheet');
    Navigator.of(tester.element(find.text('HOW LONG'))).pop();
    await Screenshot.settle(tester);

    router.go('/');
    await Screenshot.settle(tester, rounds: 24);
    Screenshot.phone(tester, height: 1500);
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_today');

    router.go('/fuel');
    await Screenshot.settle(tester, rounds: 24);
    Screenshot.phone(tester, height: 1900);
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_fuel_mon');

    router.go('/more/settings');
    await Screenshot.settle(tester, rounds: 16);
    Screenshot.phone(tester);
    await Screenshot.settle(tester);
    await Screenshot.capture(tester, 'planner_settings');
  });
}
