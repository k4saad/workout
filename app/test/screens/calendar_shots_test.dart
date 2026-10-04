import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/progress_providers.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/fuel_service.dart';
import 'package:keller_twelve/data/media_repository.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';

import '../support/screenshot.dart';

/// The calendar, the day sheet and the week, with a month that has
/// everything in it: `build/screens/cal_*.png`, `week_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/calendar_shots_test.dart
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late MediaRepository media;

  // Thursday of week 5.
  final today = DateTime(2026, 11, 12);

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_cal_shots_');
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

  /// Five weeks of history with the untidy bits real ones have: a session
  /// moved onto a rest day, a skip, a miss, two runs, the week-4 photos,
  /// and the meals mostly eaten.
  Future<void> seed() async {
    await repo.ensureSeeded();
    // Ready before the first frame: a repository still opening when the
    // test ends fails its teardown.
    media = MediaRepository(db: db, documentsDir: tmp);
    await media.ensurePosesSeeded();
    await Screenshot.seedHistory(db, repo: repo, today: today);
    final programme = await repo.loadProgramme();
    final cal = ProgrammeCalendar(programme);
    DateTime d(int week, int offset) =>
        ProgrammeCalendar.addDays(cal.startOfWeek(week), offset);

    Future<Session?> at(int week, int offset) => (db.select(
      db.sessions,
    )..where((s) => s.plannedDate.equals(d(week, offset)))).getSingleOrNull();

    // Thursday of week 4, done on Friday's rest day instead.
    final thu = (await at(4, 3))!;
    await (db.update(db.sessions)..where((s) => s.id.equals(thu.id))).write(
      SessionsCompanion(scheduledDate: Value(d(4, 4))),
    );
    // Saturday of week 4, skipped on purpose.
    final sat = (await at(4, 5))!;
    await (db.update(db.sessions)..where((s) => s.id.equals(sat.id))).write(
      const SessionsCompanion(status: Value(SessionStatus.skipped)),
    );
    // Tuesday of week 5, never logged.
    final tue = (await at(5, 1))!;
    await (db.delete(db.sessions)..where((s) => s.id.equals(tue.id))).go();

    for (final (day, km, minutes) in [(d(4, 6), 4.6, 27), (d(5, 2), 5.2, 30)]) {
      await db
          .into(db.runs)
          .insert(
            RunsCompanion.insert(
              runOn: day,
              startedAtMs: DateTime(
                day.year,
                day.month,
                day.day,
                18,
              ).millisecondsSinceEpoch,
              status: const Value(RunStatus.finished),
              distanceM: Value(km * 1000),
              movingMs: Value(minutes * 60000),
            ),
          );
    }

    await db
        .into(db.photoShoots)
        .insert(
          PhotoShootsCompanion.insert(
            id: 'shoot-w4',
            shotOn: d(4, 0),
            weekNo: const Value(4),
          ),
        );

    final plan = await repo.loadFuel();
    final fuel = FuelService(db);
    for (var i = 0; i < 10; i++) {
      final day = ProgrammeCalendar.addDays(d(4, 0), i);
      final planned = cal.forDate(day);
      final fd = plan.forDay(
        weekNo: planned.weekNo!,
        isTrainingDay: planned.day?.isTrainingDay ?? false,
      );
      // Two days with the snack and dinner missed; the rest eaten.
      final eaten = i == 3 || i == 7 ? fd.slots.length - 2 : fd.slots.length;
      for (final pm in fd.slots.take(eaten)) {
        await fuel.logMeal(
          on: day,
          slotId: pm.slot.id,
          templateId: pm.chosen.id,
          status: MealStatus.eaten,
          macros: (
            kcal: pm.chosen.kcal.toDouble(),
            proteinG: pm.chosen.proteinG,
            carbsG: pm.chosen.carbsG,
            fatG: pm.chosen.fatG,
          ),
        );
      }
    }
  }

  Future<void> tapDay(WidgetTester tester, int dayOfMonth) async {
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('month-grid')),
            matching: find.text('$dayOfMonth'),
          )
          .first,
    );
    await Screenshot.settle(tester);
  }

  testWidgets('the month, and its days', skip: !_enabled, (tester) async {
    await tester.runAsync(seed);
    Screenshot.phone(tester, height: 1750);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/week/calendar',
      overrides: [
        Screenshot.pinToday(today),
        mapTilesEnabledProvider.overrideWithValue(false),
        mediaRepositoryProvider.overrideWith((ref) async => media),
      ],
    );
    await Screenshot.settle(tester, rounds: 24);
    await Screenshot.capture(tester, 'cal_month');

    Screenshot.phone(tester);
    await Screenshot.settle(tester);
    // Thursday of week 4: its session went to Friday.
    await tapDay(tester, 5);
    await Screenshot.capture(tester, 'cal_sheet_moved_away');
    Navigator.of(tester.element(find.text('Thursday 5 November'))).pop();
    await Screenshot.settle(tester);

    // Friday: a rest day that took Thursday's session.
    await tapDay(tester, 6);
    await Screenshot.capture(tester, 'cal_sheet_moved_here');
    Navigator.of(tester.element(find.text('Friday 6 November'))).pop();
    await Screenshot.settle(tester);

    // Tuesday of week 5: missed.
    await tapDay(tester, 10);
    await Screenshot.capture(tester, 'cal_sheet_missed');
  });

  testWidgets('the week', skip: !_enabled, (tester) async {
    await tester.runAsync(seed);
    Screenshot.phone(tester, height: 1500);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/week',
      overrides: [
        Screenshot.pinToday(today),
        mediaRepositoryProvider.overrideWith((ref) async => media),
      ],
    );
    await Screenshot.settle(tester, rounds: 24);
    await Screenshot.capture(tester, 'week_5');

    await tester.tap(find.byTooltip('Previous week'));
    await Screenshot.settle(tester, rounds: 24);
    await Screenshot.capture(tester, 'week_4');
  });
}
