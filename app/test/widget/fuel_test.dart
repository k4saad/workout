import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/fuel/fuel_screen.dart';

/// The Fuel tab on the phone it is used on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late DateTime weekStart;
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
    // Week 2, comfortably inside the programme. Tuesday is a lift day.
    weekStart = DateTime(
      programme.startDate.year,
      programme.startDate.month,
      programme.startDate.day + 7,
    );
    trainingDay = DateTime(weekStart.year, weekStart.month, weekStart.day + 1);
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
          preferencesServiceProvider.overrideWithValue(
            PreferencesService(documentsDir: tmp),
          ),
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
    expect(find.text('06:45'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grams are on screen, not just meal names', (tester) async {
    await pump(tester);
    // "Porridge" is a serving suggestion; 65 g of oats is a meal.
    expect(find.textContaining(' g'), findsWidgets);
    expect(find.textContaining('Rolled oats'), findsWidgets);
  });

  testWidgets('four meals, and on a training day the snack is the fuel', (
    tester,
  ) async {
    await pump(tester);
    for (final meal in ['Breakfast', 'Lunch', 'Evening snack', 'Dinner']) {
      expect(find.text(meal), findsOneWidget, reason: meal);
    }
    expect(find.textContaining('fuel for the session'), findsOneWidget);
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

  testWidgets('a logged meal shows as logged, at once', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(FilledButton, 'Eaten'), findsNothing);

    await tester.tap(find.text('Eaten').first);
    await settle(tester);
    await settle(tester);
    expect(
      find.widgetWithText(FilledButton, 'Eaten'),
      findsOneWidget,
      reason: 'the button he tapped must say it took',
    );
    expect(find.byIcon(Icons.check), findsWidgets, reason: 'not by fill alone');
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

  testWidgets('after the programme ends, the food stays at week twelve', (
    tester,
  ) async {
    // Two weeks past the last day, before a new cycle is built. v3 fell
    // back to week one's numbers: food gone the week the programme finished.
    // v4 eats the same all twelve weeks, so the day stays at 2,300.
    final programme = await repo.loadProgramme();
    trainingDay = DateTime(
      programme.startDate.year,
      programme.startDate.month,
      programme.startDate.day + programme.totalWeeks * 7 + 14,
    );
    await pump(tester);
    final target = find.textContaining(RegExp(r'^of \d+$'));
    expect(target, findsOneWidget);
    final kcal = int.parse(
      (tester.widget<Text>(target).data ?? '').replaceFirst('of ', ''),
    );
    expect(kcal, inInclusiveRange(2200, 2400));
  });

  testWidgets('a rest day eats the same four meals, none of them timed', (
    tester,
  ) async {
    // Wednesday of week 2 is a rest day.
    trainingDay = trainingDay.add(const Duration(days: 1));
    await pump(tester);

    expect(find.text('Evening snack'), findsOneWidget);
    expect(find.textContaining('fuel for the session'), findsNothing);
    expect(find.textContaining('recovery happens today'), findsOneWidget);
  });

  testWidgets('a day buys one main: chicken twice, not chicken and salmon', (
    tester,
  ) async {
    // Monday is the rotation's chicken day.
    trainingDay = weekStart;
    expect(trainingDay.weekday, DateTime.monday);
    await pump(tester);
    expect(find.text('Chicken thighs, rice and vegetables'), findsOneWidget);
    expect(find.text('Chicken thighs and potatoes'), findsOneWidget);
    expect(find.text('Salmon and potatoes'), findsNothing);
  });

  Future<void> openPlan(WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Plan'));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('the plan lays out a week: cost, cooking ahead, the days', (
    tester,
  ) async {
    await openPlan(tester);

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Next week'), findsOneWidget);
    expect(find.text('FOOD THIS WEEK'), findsOneWidget);
    expect(find.text('COOK AHEAD'), findsOneWidget);
    expect(find.text('Sunday evening'), findsOneWidget);
    expect(find.text('THE WEEK'), findsOneWidget);
    // Seven days, Monday first.
    for (var i = 0; i < 7; i++) {
      final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      // (The prep night falls on some of them too.)
      expect(find.text(DateFormat('EEE d MMM').format(d)), findsWidgets);
    }
    expect(find.text('TODAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next week is a different week, planned the same way', (
    tester,
  ) async {
    await openPlan(tester);
    final monday = DateFormat('EEE d MMM').format(weekStart);
    expect(find.text(monday), findsOneWidget);

    await tester.tap(find.text('Next week'));
    await settle(tester);
    await settle(tester);
    expect(find.text(monday), findsNothing);
    expect(
      find.text(
        DateFormat(
          'EEE d MMM',
        ).format(DateTime(weekStart.year, weekStart.month, weekStart.day + 7)),
      ),
      findsOneWidget,
    );
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('a meal on a day next week swaps for that date', (tester) async {
    await openPlan(tester);
    await tester.tap(find.text('Next week'));
    await settle(tester);
    await settle(tester);

    final tuesday = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 8,
    );
    await tester.tap(find.text(DateFormat('EEE d MMM').format(tuesday)));
    await settle(tester);
    await tester.tap(find.byTooltip('Swap dinner'));
    await settle(tester);
    await tester.tap(find.text('Salmon and potatoes'));
    await settle(tester);
    await settle(tester);

    final rows = await db.select(db.mealLogs).get();
    expect(rows, hasLength(1));
    expect(rows.single.templateId, 'salmon_potato');
    expect(rows.single.status, MealStatus.planned);
    expect(rows.single.loggedOn, tuesday);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shopping list is packets and prices, ticked at the shelf', (
    tester,
  ) async {
    await openPlan(tester);

    expect(find.text('SHOPPING LIST'), findsOneWidget);
    // Half a tub of quark is not a thing you can buy.
    expect(find.textContaining(' x 500 g'), findsWidgets);
    expect(find.textContaining("this week's shop"), findsOneWidget);
    // The kilo tub of whey is not bought every week.
    expect(find.text('CUPBOARD, WHEN IT RUNS OUT'), findsOneWidget);
    expect(find.textContaining('lasts'), findsWidgets);

    final quark = find.text('Low-fat quark');
    await tester.ensureVisible(quark);
    await tester.pump();
    await tester.tap(quark);
    await settle(tester);
    expect(
      find.descendant(
        of: find.ancestor(of: quark, matching: find.byType(InkWell)),
        matching: find.byIcon(Icons.check_box),
      ),
      findsOneWidget,
    );
    // Real file IO: outside the test's fake clock, or it never completes.
    final prefs = await tester.runAsync(
      () => PreferencesService(documentsDir: tmp).load(),
    );
    expect(prefs!.shoppingTicksFor(weekStart), {'magerquark'});

    // The halal buying guide sits under the list.
    await tester.scrollUntilVisible(
      find.text('Buying it halal'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buying it halal'), findsOneWidget);
  });
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._value);

  final DateTime _value;

  @override
  DateTime build() => _value;
}
