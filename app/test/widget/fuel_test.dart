import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/fuel/fuel_screen.dart';

/// The Fuel tab on the phone it is used on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late DateTime trainingDay;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_fuel_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadFuel();
    final programme = await repo.loadProgramme();
    // Monday of week 2: a lift day, comfortably inside the programme.
    trainingDay = DateTime(
      programme.startDate.year,
      programme.startDate.month,
      programme.startDate.day + 7,
    );
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
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 6000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _FixedToday(trainingDay)),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const FuelScreen()),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  testWidgets('the day draws, in the order it is eaten, without overflowing', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('THE DAY'), findsOneWidget);
    // Every meal shows a real time, so the plan reads as a day.
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grams are on screen, not just meal names', (tester) async {
    await pump(tester);
    // "Porridge" is a serving suggestion; 65 g of oats is a meal.
    expect(find.textContaining(' g'), findsWidgets);
    expect(find.textContaining('Haferflocken'), findsWidgets);
  });

  testWidgets('a training day says the session meals are timed', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('either side of the session'), findsOneWidget);
    expect(find.text('Before training'), findsOneWidget);
    expect(find.text('Straight after'), findsOneWidget);
  });

  testWidgets('logging a meal moves the ring and sticks', (tester) async {
    await pump(tester);

    // Nothing eaten yet.
    expect(find.text('0'), findsWidgets);

    await tester.tap(find.text('Eaten').first);
    await settle(tester);
    await settle(tester);

    final rows = await db.select(db.mealLogs).get();
    expect(rows, hasLength(1));
    expect(rows.single.portion, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('half a meal counts as half, not as nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Half').first);
    await settle(tester);

    final rows = await db.select(db.mealLogs).get();
    expect(rows.single.portion, 0.5);
  });

  testWidgets('water adds up and can be undone', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.text('+500'));
    await tester.pump();
    await tester.tap(find.text('+500'));
    await settle(tester);
    expect(find.textContaining('0.5 of'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo 250'));
    await settle(tester);
    expect(find.textContaining('0.3 of'), findsOneWidget);
  });

  testWidgets('a supplement ticks and persists', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.textContaining('Creatine'));
    await tester.pump();
    await tester.tap(find.textContaining('Creatine'));
    await settle(tester);

    expect(await db.select(db.supplementLogs).get(), hasLength(1));
  });

  testWidgets('a rest day swaps the session meals for one afternoon meal', (
    tester,
  ) async {
    // Saturday of week 2 is the programme's rest day.
    trainingDay = trainingDay.add(const Duration(days: 5));
    await pump(tester);

    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('Before training'), findsNothing);
    expect(find.textContaining('muscle is built today'), findsOneWidget);
  });

  testWidgets('the shopping list says packets, not grams', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Shopping and guide'));
    await settle(tester);
    await settle(tester);

    expect(find.text('A week of this'), findsOneWidget);
    // Half a tub of quark is not a thing you can buy.
    expect(find.textContaining(' x 500 g'), findsWidgets);
    expect(find.text('Buying it halal'), findsOneWidget);
  });
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._value);

  final DateTime _value;

  @override
  DateTime build() => _value;
}
