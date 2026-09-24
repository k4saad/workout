import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/fuel/fuel_plan.dart';

/// The eating plan, resolved for a date.
///
/// Everything here is arithmetic over generated data, so it is tested against
/// the REAL `fuel.json` — a hand-made fixture would prove the solver works on
/// numbers that do not ship.
void main() {
  final plan = FuelPlan.fromJson(
    jsonDecode(File('assets/nutrition/fuel.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('the plan loads', () {
    test('foods, meals, slots and phases all arrive', () {
      expect(plan.foods, isNotEmpty);
      expect(plan.meals, isNotEmpty);
      expect(plan.slots, isNotEmpty);
      expect(plan.phases, hasLength(3));
      expect(plan.supplements, isNotEmpty);
      expect(plan.buyingGuide, isNotEmpty);
    });

    test('every meal references food that exists', () {
      for (final m in plan.meals) {
        for (final item in m.items) {
          expect(
            plan.food(item.foodId),
            isNotNull,
            reason: '${m.id} wants ${item.foodId}',
          );
        }
      }
    });

    test('every meal sits in a slot that exists', () {
      final ids = {for (final s in plan.slots) s.id};
      for (final m in plan.meals) {
        expect(ids, contains(m.slotId));
      }
    });

    test('a meal knows its own macros, and they match its grams', () {
      for (final m in plan.meals) {
        var kcal = 0.0;
        for (final item in m.items) {
          kcal += plan.food(item.foodId)!.kcal * item.grams / 100;
        }
        expect(
          m.kcal,
          closeTo(kcal, 1.0),
          reason: '${m.id} says ${m.kcal} kcal, its grams say $kcal',
        );
      }
    });
  });

  group('the day it resolves', () {
    test('a training day has the two session meals', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      final slots = day.slots.map((s) => s.slot.id).toList();
      expect(slots, contains('pre_training'));
      expect(slots, contains('post_training'));
      expect(slots, isNot(contains('afternoon')));
    });

    test('a rest day collapses them into one afternoon meal', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: false);
      final slots = day.slots.map((s) => s.slot.id).toList();
      expect(slots, contains('afternoon'));
      expect(slots, isNot(contains('pre_training')));
      expect(slots, isNot(contains('post_training')));
    });

    test('the slots come back in the order you eat them', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      final times = day.slots.map((s) => s.slot.time).toList();
      expect(times, orderedEquals([...times]..sort()));
    });

    test('every slot offers a choice, and one is picked by default', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      for (final s in day.slots) {
        expect(s.choices, isNotEmpty, reason: '${s.slot.id} has no meal');
        expect(s.choices, contains(s.chosen));
      }
    });

    test('both kinds of day land on the phase target', () {
      for (final training in [true, false]) {
        for (final week in [1, 6, 11]) {
          final day = plan.forDay(weekNo: week, isTrainingDay: training);
          final target = plan.phaseForWeek(week)!;
          expect(
            day.totals.kcal,
            closeTo(target.kcal.toDouble(), target.kcal * 0.03),
            reason: 'week $week, training=$training',
          );
          expect(day.totals.proteinG, greaterThanOrEqualTo(target.proteinG));
        }
      }
    });

    test('the later phases are bigger than the first', () {
      final w1 = plan.forDay(weekNo: 1, isTrainingDay: true).totals.kcal;
      final w6 = plan.forDay(weekNo: 6, isTrainingDay: true).totals.kcal;
      final w11 = plan.forDay(weekNo: 11, isTrainingDay: true).totals.kcal;
      expect(w6, greaterThan(w1));
      expect(w11, greaterThan(w6));
    });

    test('the phase module appears as a real item, not a number', () {
      final day = plan.forDay(weekNo: 6, isTrainingDay: true);
      expect(day.module, isNotNull);
      expect(day.module!.items, isNotEmpty);
      for (final i in day.module!.items) {
        expect(plan.food(i.foodId), isNotNull);
      }
    });

    test('week 1 carries no module', () {
      expect(plan.forDay(weekNo: 1, isTrainingDay: true).module, isNull);
    });

    test('a week outside the programme still resolves to something edible', () {
      // Week 13 exists the day the programme ends. Showing nothing would be
      // worse than showing the last phase he was on.
      final day = plan.forDay(weekNo: 13, isTrainingDay: false);
      expect(day.slots, isNotEmpty);
      expect(day.totals.kcal, greaterThan(2000));
    });
  });

  group('swapping a meal', () {
    test('choosing another option keeps the day on target', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      final lunch = day.slots.firstWhere((s) => s.slot.id == 'lunch');
      final other = lunch.choices.firstWhere((c) => c != lunch.chosen);

      final swapped = day.choosing('lunch', other.id);
      expect(
        swapped.slots.firstWhere((s) => s.slot.id == 'lunch').chosen.id,
        other.id,
      );
      final target = plan.phaseForWeek(1)!;
      expect(
        swapped.totals.kcal,
        closeTo(target.kcal.toDouble(), target.kcal * 0.03),
      );
    });

    test('an unknown meal id is ignored rather than throwing', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      expect(() => day.choosing('lunch', 'no-such-meal'), returnsNormally);
      expect(
        day.choosing('lunch', 'no-such-meal').totals.kcal,
        day.totals.kcal,
      );
    });
  });

  group('an applied adjustment', () {
    test('adds its calories on top of the phase', () {
      final base = plan.forDay(weekNo: 1, isTrainingDay: true);
      final boosted = plan.forDay(
        weekNo: 1,
        isTrainingDay: true,
        extraKcal: 250,
      );
      expect(boosted.totals.kcal, closeTo(base.totals.kcal + 250, 60));
      expect(boosted.extraKcal, 250);
    });

    test('with no adjustment the day is exactly the phase', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      expect(day.extraKcal, 0);
    });
  });

  group('the grocery list', () {
    test('adds up a week of chosen meals, by food', () {
      final days = [
        for (var i = 0; i < 7; i++)
          plan.forDay(weekNo: 1, isTrainingDay: i < 5),
      ];
      final list = plan.groceries(days);

      expect(list, isNotEmpty);
      final quark = list.firstWhere((l) => l.food.id == 'magerquark');
      expect(quark.grams, greaterThan(0));
      // A shopping list in grams is useless at the shelf: it has to say how
      // many tubs.
      expect(quark.packs, greaterThanOrEqualTo(1));
      expect(quark.packs * quark.food.packG, greaterThanOrEqualTo(quark.grams));
    });

    test('is sorted by category so the list follows the aisles', () {
      final days = [plan.forDay(weekNo: 1, isTrainingDay: true)];
      final cats = plan.groceries(days).map((l) => l.food.category).toList();
      expect(cats, orderedEquals([...cats]..sort()));
    });

    test('an empty week buys nothing', () {
      expect(plan.groceries(const []), isEmpty);
    });
  });

  group('halal, checked in the app and not only in the generator', () {
    test('nothing on the list is pork, alcohol or unstated gelatine', () {
      const banned = [
        'schwein',
        'schinken',
        'speck',
        'bacon',
        'pork',
        'wein',
        'bier',
        'alkohol',
        'gelatine',
      ];
      for (final f in plan.foods) {
        for (final b in banned) {
          expect(
            f.name.toLowerCase().contains(b),
            isFalse,
            reason: '${f.id} is ${f.name}',
          );
        }
      }
    });
  });
}
