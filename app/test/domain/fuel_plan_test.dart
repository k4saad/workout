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

  group('the next meal to eat', () {
    final day = plan.forDay(weekNo: 1, isTrainingDay: true, weekday: 1);
    String? next(String now, [Set<String> logged = const {}]) =>
        day.nextToEat(now: now, logged: logged)?.slot.id;

    test('a meal just due is still the next one', () {
      // v3 compared the clock only: at 10:35 the 10:30 meal had vanished.
      expect(next('10:35'), 'mid_morning');
    });

    test('a meal logged is not next any more', () {
      expect(next('10:20', {'mid_morning'}), 'lunch');
      expect(next('07:00', {'breakfast', 'mid_morning'}), 'lunch');
    });

    test('a meal two hours gone gives way to the one coming', () {
      expect(next('15:10'), 'pre_training');
      expect(next('14:50'), 'lunch');
    });

    test('with everything logged, the day is done', () {
      expect(next('23:00', {for (final s in day.slots) s.slot.id}), isNull);
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

    test('a cut takes its calories off, too', () {
      final base = plan.forDay(weekNo: 1, isTrainingDay: true);
      final cut = plan.forDay(weekNo: 1, isTrainingDay: true, extraKcal: -200);
      expect(cut.totals.kcal, closeTo(base.totals.kcal - 200, 0.001));
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

  group('what it costs', () {
    test(
      'every food has a price, and every meal costs what its food costs',
      () {
        for (final f in plan.foods) {
          expect(f.priceEurPerKg, greaterThan(0), reason: f.id);
        }
        for (final m in plan.meals) {
          var eur = 0.0;
          for (final i in m.items) {
            eur += plan.food(i.foodId)!.priceEurPerKg * i.grams / 1000;
          }
          expect(m.costEur, closeTo(eur, 0.011), reason: m.id);
        }
      },
    );

    test('a day costs its meals, plus the phase module', () {
      final day = plan.forDay(weekNo: 6, isTrainingDay: true, weekday: 1);
      final meals = day.slots.fold<double>(0, (a, s) => a + s.chosen.costEur);
      final module = plan.costOf(day.module!.items);
      expect(module, greaterThan(0));
      expect(day.costEur, closeTo(meals + module, 0.001));
    });

    test('cupboard food says how long a packet lasts', () {
      final week = [
        for (var wd = 1; wd <= 7; wd++)
          plan.forDay(weekNo: 1, isTrainingDay: wd <= 5, weekday: wd),
      ];
      final lines = plan.groceries(week);
      final oats = lines.firstWhere((l) => l.food.id == 'haferflocken');
      expect(oats.food.keeps, isTrue);
      expect(oats.packLastsWeeks, closeTo(oats.food.packG / oats.grams, 1e-9));
      final quark = lines.firstWhere((l) => l.food.id == 'magerquark');
      expect(quark.food.keeps, isFalse, reason: 'bought fresh every week');
    });

    test('a grocery line costs the whole packets you pay for', () {
      final lines = plan.groceries([
        plan.forDay(weekNo: 1, isTrainingDay: true, weekday: 1),
      ]);
      for (final l in lines) {
        expect(
          l.costEur,
          closeTo(l.packs * l.food.packG / 1000 * l.food.priceEurPerKg, 0.001),
        );
      }
    });
  });

  group('the default week', () {
    List<FuelDay> week({required bool training, int weekNo = 1}) => [
      for (var wd = 1; wd <= 7; wd++)
        plan.forDay(weekNo: weekNo, isTrainingDay: training, weekday: wd),
    ];

    test('covers every weekday', () {
      for (var wd = 1; wd <= 7; wd++) {
        expect(plan.rotationFor(wd), isNotNull, reason: 'weekday $wd');
      }
    });

    test('each weekday starts from its own meals, not the first option', () {
      for (var wd = 1; wd <= 7; wd++) {
        final day = plan.forDay(weekNo: 1, isTrainingDay: true, weekday: wd);
        final r = plan.rotationFor(wd)!;
        for (final s in day.slots) {
          expect(s.chosen.id, r.meals[s.slot.id], reason: '$wd ${s.slot.id}');
        }
      }
      final lunches = {
        for (final d in week(training: true))
          d.slots.firstWhere((s) => s.slot.id == 'lunch').chosen.id,
      };
      expect(lunches.length, greaterThan(3), reason: 'a week, not one day x7');
    });

    test('no default day buys two meats, or meat and fish', () {
      for (final training in [true, false]) {
        for (final d in week(training: training)) {
          expect(
            d.meatOrFish.length,
            lessThanOrEqualTo(1),
            reason: 'weekday ${d.weekday}: ${d.meatOrFish}',
          );
        }
      }
    });

    test('salmon is never a default, and always a swap', () {
      for (final training in [true, false]) {
        for (final d in week(training: training)) {
          for (final s in d.slots) {
            expect(
              s.chosen.items.map((i) => i.foodId),
              isNot(contains('lachs')),
              reason: 'weekday ${d.weekday} ${s.slot.id}',
            );
          }
        }
      }
      final dinner = plan
          .forDay(weekNo: 1, isTrainingDay: true, weekday: 1)
          .slots
          .firstWhere((s) => s.slot.id == 'dinner');
      expect(
        dinner.choices.expand((m) => m.items).map((i) => i.foodId),
        contains('lachs'),
      );
    });

    test('every default day lands on its phase', () {
      for (final training in [true, false]) {
        for (final weekNo in [1, 6, 11]) {
          final target = plan.phaseForWeek(weekNo)!;
          for (final d in week(training: training, weekNo: weekNo)) {
            expect(
              d.totals.kcal,
              closeTo(target.kcal.toDouble(), target.kcal * 0.03),
              reason: 'week $weekNo weekday ${d.weekday}',
            );
            expect(d.totals.proteinG, greaterThanOrEqualTo(target.proteinG));
          }
        }
      }
    });

    test('fits a student budget, a day and a week', () {
      final budget = plan.budget!;
      for (final training in [true, false]) {
        final days = week(training: training);
        for (final d in days) {
          expect(d.costEur, lessThanOrEqualTo(budget.eurPerDay));
        }
        final total = days.fold<double>(0, (a, d) => a + d.costEur);
        expect(total, lessThanOrEqualTo(budget.eurPerWeek));
      }
    });

    test('his swap wins over the weekday', () {
      final day = plan.forDay(
        weekNo: 1,
        isTrainingDay: true,
        weekday: 1,
        chosen: const {'dinner': 'salmon_potato'},
      );
      expect(
        day.slots.firstWhere((s) => s.slot.id == 'dinner').chosen.id,
        'salmon_potato',
      );
    });

    test('with no weekday, the day still resolves', () {
      final day = plan.forDay(weekNo: 1, isTrainingDay: true);
      expect(day.weekday, isNull);
      for (final s in day.slots) {
        expect(s.choices, contains(s.chosen));
      }
    });
  });

  test('a week is shopped from its Monday', () {
    expect(mondayOf(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    expect(mondayOf(DateTime(2026, 10, 11, 21, 30)), DateTime(2026, 10, 5));
    // Across a month end and the clocks going back (25 October).
    expect(mondayOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
  });

  group('prep nights', () {
    // Monday 5 October 2026.
    final monday = DateTime(2026, 10, 5);
    List<FuelDay> weekOf({Map<int, Map<String, String>> swaps = const {}}) => [
      for (var wd = 1; wd <= 7; wd++)
        plan.forDay(
          weekNo: 1,
          isTrainingDay: wd <= 5,
          weekday: wd,
          chosen: swaps[wd] ?? const {},
        ),
    ];

    double cooked(PrepNight n, String foodId) =>
        n.cook.where((c) => c.food.id == foodId).fold(0, (a, c) => a + c.grams);

    test('each night falls before the days it cooks for', () {
      final nights = plan.prepNights(monday: monday, week: weekOf());
      expect(nights, isNotEmpty);
      final keeps = plan.prep!.keepsDays;
      for (final n in nights) {
        for (final m in n.meals) {
          final ahead = m.date.difference(n.cookDate).inDays;
          expect(ahead, inInclusiveRange(1, keeps), reason: n.session.label);
        }
      }
    });

    test('the first night is the Sunday before the week', () {
      final first = plan.prepNights(monday: monday, week: weekOf()).first;
      expect(first.cookDate, DateTime(2026, 10, 4));
      expect(first.cookDate.weekday, DateTime.sunday);
    });

    test('it cooks exactly what the batch meals of those days use', () {
      final week = weekOf();
      for (final n in plan.prepNights(monday: monday, week: week)) {
        final expected = <String, double>{};
        for (final wd in n.session.covers) {
          for (final s in week[wd - 1].slots) {
            if (!s.chosen.batch) continue;
            for (final i in s.chosen.items) {
              if (!plan.prep!.foods.contains(i.foodId)) continue;
              expected[i.foodId] = (expected[i.foodId] ?? 0) + i.grams;
            }
          }
        }
        expect(expected, isNotEmpty);
        for (final e in expected.entries) {
          expect(cooked(n, e.key), closeTo(e.value, 0.001), reason: e.key);
        }
        expect(n.cook.length, expected.length);
      }
    });

    test('it reads in cooking order: the protein first', () {
      final first = plan.prepNights(monday: monday, week: weekOf()).first;
      expect(first.cook.first.food.category, 'meat');
      final cats = first.cook.map((c) => c.food.category).toList();
      expect(cats.indexOf('grain'), greaterThan(cats.indexOf('legume')));
    });

    test('a meal swapped away is not cooked for', () {
      final chickenOnMonday = cooked(
        plan.prepNights(monday: monday, week: weekOf()).first,
        'haehnchen_ok',
      );
      expect(chickenOnMonday, greaterThan(0));
      final swapped = plan
          .prepNights(
            monday: monday,
            week: weekOf(
              swaps: const {
                1: {'lunch': 'egg_rice'},
              },
            ),
          )
          .first;
      expect(cooked(swapped, 'haehnchen_ok'), lessThan(chickenOnMonday));
      expect(swapped.meals.map((m) => m.meal.id), isNot(contains('egg_rice')));
    });

    test('a night with nothing to cook is left out', () {
      final noBatch = {
        for (var wd = 1; wd <= 7; wd++)
          wd: {'lunch': 'egg_rice', 'dinner': 'shakshuka'},
      };
      expect(
        plan.prepNights(
          monday: monday,
          week: weekOf(swaps: noBatch),
        ),
        isEmpty,
      );
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
        'gelatin',
        'ham ',
        'wine',
        'beer',
        'alcohol',
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
