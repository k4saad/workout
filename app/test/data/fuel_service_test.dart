import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/fuel_service.dart';

/// Logging what was eaten, and the adjustment rule v2 got wrong.
void main() {
  late AppDatabase db;
  late FuelService fuel;

  final monday = DateTime(2026, 11, 2);

  setUp(() {
    db = AppDatabase.memory();
    fuel = FuelService(db);
  });
  tearDown(() => db.close());

  group('logging a meal', () {
    test('eaten, half and skipped all count for what they are', () async {
      await fuel.logMeal(
        on: monday,
        slotId: 'breakfast',
        templateId: 'porridge_pb',
        status: MealStatus.eaten,
        macros: (kcal: 540, proteinG: 22.0, carbsG: 70.0, fatG: 18.0),
      );
      await fuel.logMeal(
        on: monday,
        slotId: 'lunch',
        templateId: 'chicken_rice',
        status: MealStatus.partial,
        macros: (kcal: 560, proteinG: 30.0, carbsG: 70.0, fatG: 15.0),
      );
      await fuel.logMeal(
        on: monday,
        slotId: 'dinner',
        templateId: 'salmon_potato',
        status: MealStatus.skipped,
        macros: (kcal: 520, proteinG: 32.0, carbsG: 60.0, fatG: 18.0),
      );

      final eaten = await fuel.eatenOn(monday);
      // 540 whole + half of 560 + none of 520.
      expect(eaten.kcal, closeTo(820, 0.5));
      expect(eaten.proteinG, closeTo(37, 0.5));
    });

    test(
      'logging the same slot twice corrects it rather than doubling',
      () async {
        for (final status in [MealStatus.eaten, MealStatus.skipped]) {
          await fuel.logMeal(
            on: monday,
            slotId: 'breakfast',
            templateId: 'porridge_pb',
            status: status,
            macros: (kcal: 540, proteinG: 22.0, carbsG: 70.0, fatG: 18.0),
          );
        }
        final rows = await fuel.mealsOn(monday);
        expect(rows, hasLength(1));
        expect(rows.single.status, MealStatus.skipped);
        expect((await fuel.eatenOn(monday)).kcal, 0);
      },
    );

    test('a day with nothing logged is zero, not an error', () async {
      expect((await fuel.eatenOn(monday)).kcal, 0);
      expect(await fuel.mealsOn(monday), isEmpty);
    });
  });

  group('water and supplements', () {
    test('water accumulates across the day', () async {
      await fuel.addWater(monday, 500);
      await fuel.addWater(monday, 750);
      expect(await fuel.waterOn(monday), 1250);
    });

    test('water never goes below zero', () async {
      await fuel.addWater(monday, 500);
      await fuel.addWater(monday, -900);
      expect(await fuel.waterOn(monday), 0);
    });

    test('a supplement ticks on and off', () async {
      await fuel.setSupplement(monday, 'creatine', taken: true);
      expect(await fuel.supplementsOn(monday), contains('creatine'));
      await fuel.setSupplement(monday, 'creatine', taken: false);
      expect(await fuel.supplementsOn(monday), isEmpty);
    });
  });

  group('adherence', () {
    Future<void> logDay(
      DateTime day, {
      required int of,
      required int eaten,
    }) async {
      for (var i = 0; i < of; i++) {
        await fuel.logMeal(
          on: day,
          slotId: 'slot$i',
          templateId: 't$i',
          status: i < eaten ? MealStatus.eaten : MealStatus.skipped,
          macros: (kcal: 400, proteinG: 20.0, carbsG: 50.0, fatG: 12.0),
        );
      }
    }

    test('is the share of planned meals actually eaten', () async {
      await logDay(monday, of: 7, eaten: 7);
      await logDay(monday.add(const Duration(days: 1)), of: 7, eaten: 4);

      final a = await fuel.adherence(
        from: monday,
        to: monday.add(const Duration(days: 1)),
      );
      expect(a.planned, 14);
      expect(a.eaten, 11);
      expect(a.rate, closeTo(11 / 14, 0.001));
    });

    test('a half counts as a half, not as a miss', () async {
      await fuel.logMeal(
        on: monday,
        slotId: 'a',
        templateId: 't',
        status: MealStatus.partial,
        macros: (kcal: 400, proteinG: 20.0, carbsG: 50.0, fatG: 12.0),
      );
      final a = await fuel.adherence(from: monday, to: monday);
      expect(a.rate, closeTo(0.5, 0.001));
    });

    test('nothing logged is nothing claimed', () async {
      final a = await fuel.adherence(from: monday, to: monday);
      expect(a.planned, 0);
      expect(a.rate, 0);
    });
  });

  group('the +250 that used to vanish the moment it worked', () {
    test('an applied adjustment persists and keeps counting', () async {
      await fuel.applyAdjustment(
        on: monday,
        kcalDelta: 250,
        reason: 'Flat for two weeks',
        moduleId: 'boost250',
      );

      // v2 recomputed the advice on every read: the scale moved, the "flat"
      // condition stopped being true, and the extra 250 silently disappeared
      // — so the weight stalled again, and so on around the loop.
      expect(await fuel.appliedExtraKcal(on: monday), 250);
      expect(
        await fuel.appliedExtraKcal(on: monday.add(const Duration(days: 30))),
        250,
        reason: 'it stays applied until it is reverted',
      );
    });

    test('it does not apply before the day it was applied', () async {
      await fuel.applyAdjustment(
        on: monday,
        kcalDelta: 250,
        reason: 'Flat for two weeks',
      );
      expect(
        await fuel.appliedExtraKcal(
          on: monday.subtract(const Duration(days: 1)),
        ),
        0,
      );
    });

    test('reverting it stops it, from the day it was reverted', () async {
      final id = await fuel.applyAdjustment(
        on: monday,
        kcalDelta: 250,
        reason: 'Flat for two weeks',
      );
      final later = monday.add(const Duration(days: 14));
      await fuel.revertAdjustment(id, on: later);

      expect(await fuel.appliedExtraKcal(on: monday), 250);
      expect(
        await fuel.appliedExtraKcal(on: later.add(const Duration(days: 1))),
        0,
      );
    });

    test('two adjustments stack', () async {
      await fuel.applyAdjustment(on: monday, kcalDelta: 250, reason: 'flat');
      await fuel.applyAdjustment(
        on: monday.add(const Duration(days: 21)),
        kcalDelta: 250,
        reason: 'flat again',
      );
      expect(
        await fuel.appliedExtraKcal(on: monday.add(const Duration(days: 22))),
        500,
      );
    });

    test('a cut is just a negative adjustment', () async {
      await fuel.applyAdjustment(
        on: monday,
        kcalDelta: -200,
        reason: 'Waist ran ahead of the lifts',
      );
      expect(await fuel.appliedExtraKcal(on: monday), -200);
    });

    test('the open ones are listed so they can be reverted', () async {
      await fuel.applyAdjustment(on: monday, kcalDelta: 250, reason: 'flat');
      final open = await fuel.openAdjustments();
      expect(open, hasLength(1));
      expect(open.single.reason, 'flat');

      await fuel.revertAdjustment(open.single.id, on: monday);
      expect(await fuel.openAdjustments(), isEmpty);
    });
  });
}
