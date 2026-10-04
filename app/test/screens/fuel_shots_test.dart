import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/fuel/fuel_week_view.dart';

import '../support/screenshot.dart';

/// Fuel today and the Plan: `build/screens/fuel_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/fuel_shots_test.dart
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  // A Friday: the Plan opens on next week, the one about to be shopped for.
  final today = DateTime(2026, 10, 16);

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_fuel_shots_');
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

  testWidgets(
    'fuel: today, the plan, a day, the shopping list',
    (tester) async {
      Screenshot.phone(tester);
      await Screenshot.pumpApp(
        tester,
        db: db,
        repo: repo,
        location: '/fuel',
        overrides: [
          Screenshot.pinToday(today),
          preferencesServiceProvider.overrideWithValue(
            PreferencesService(documentsDir: tmp),
          ),
        ],
      );
      await Screenshot.settle(tester);
      await Screenshot.capture(tester, 'fuel_today');

      await tester.tap(find.text('Plan'));
      await Screenshot.settle(tester);
      await Screenshot.settle(tester);
      await Screenshot.capture(tester, 'fuel_plan');

      // Scrolled on the Plan's own list. (ensureVisible would also nudge the
      // tab pager it sits in.)
      final list = find
          .descendant(
            of: find.byType(FuelWeekView),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> toTop(Finder f) async {
        final position = tester.state<ScrollableState>(list).position;
        // Step down until it is built, then put it just under the app bar.
        while (f.evaluate().isEmpty &&
            position.pixels < position.maxScrollExtent) {
          position.jumpTo(position.pixels + 300);
          await tester.pump();
        }
        position.jumpTo(
          (position.pixels + tester.getTopLeft(f).dy - 260).clamp(
            0,
            position.maxScrollExtent,
          ),
        );
        await Screenshot.settle(tester);
      }

      await toTop(find.text('THE WEEK'));
      await Screenshot.capture(tester, 'fuel_plan_week');

      await toTop(find.text('Tue 20 Oct'));
      await tester.tap(find.text('Tue 20 Oct'));
      await Screenshot.settle(tester);
      await Screenshot.capture(tester, 'fuel_plan_day');

      await toTop(find.text('SHOPPING LIST'));
      for (final food in ['Onion', 'Mixed vegetables, frozen']) {
        await tester.tap(find.text(food));
        await Screenshot.settle(tester, rounds: 4);
      }
      await Screenshot.capture(tester, 'fuel_plan_shopping');
      await toTop(find.text('CUPBOARD, WHEN IT RUNS OUT'));
      await Screenshot.capture(tester, 'fuel_plan_cupboard');
      expect(tester.takeException(), isNull);
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
