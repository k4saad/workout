import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/router.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

/// The flat rule, end to end: the scale is flat, the Body page says add
/// 150, one tap adds it, Fuel plans it, and it can be taken off again.
///
/// Until v0.13 the advice was a sentence with no button, and Fuel pointed
/// at a "Body → adjustments" page that did not exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late GoRouter router;
  late DateTime today;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_adjust_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadFuel();
    final programme = await repo.loadProgramme();
    // A Wednesday in week 5: four weeks of a flat scale behind it.
    today = DateTime(
      programme.startDate.year,
      programme.startDate.month,
      programme.startDate.day + 30,
    );
    for (var i = 27; i >= 0; i--) {
      await db.upsertBodyweight(
        DateTime(today.year, today.month, today.day - i),
        50.0 + (i % 3) * 0.1,
      );
    }
    router = buildRouter();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _FixedToday(today)),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await settle(tester);
    router.go(location);
    await settle(tester);
    await settle(tester);
  }

  testWidgets('flat for weeks: add it, Fuel plans it, take it off', (
    tester,
  ) async {
    await pumpAt(tester, '/progress/body');

    expect(find.text('Add 150 kcal'), findsOneWidget);
    await tester.tap(find.text('Add 150 kcal a day'));
    await settle(tester);
    await settle(tester);

    final rows = await tester.runAsync(
      () => db.select(db.nutritionAdjustments).get(),
    );
    expect(rows, hasLength(1));
    expect(rows!.single.kcalDelta, 150);
    expect(rows.single.appliedOn, today);

    // The advice does not ask again straight away, and the change is
    // listed with the way to take it off.
    expect(find.text('Add 150 kcal a day'), findsNothing);
    expect(find.text('Settling in'), findsOneWidget);
    expect(find.text('Calorie changes in force'), findsOneWidget);

    // Fuel plans it, as food.
    router.go('/fuel');
    await settle(tester);
    await settle(tester);
    expect(find.text('+150 kcal a day, applied'), findsOneWidget);
    expect(find.textContaining('As food:'), findsOneWidget);

    // Its banner leads back to the page that takes it off.
    await tester.tap(find.text('+150 kcal a day, applied'));
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Take it off'));
    await settle(tester);
    await settle(tester);

    final after = await tester.runAsync(
      () => db.select(db.nutritionAdjustments).get(),
    );
    expect(after!.single.revertedOn, today);
    expect(find.text('Calorie changes in force'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._value);

  final DateTime _value;

  @override
  DateTime build() => _value;
}
