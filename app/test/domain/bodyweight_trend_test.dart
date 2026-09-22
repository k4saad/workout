import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/metrics/bodyweight_trend.dart';
import 'package:keller_twelve/domain/models/programme.dart';

void main() {
  const trend = BodyweightTrend();
  const rules = NutritionRules(
    gainKgPerWeek: 0.3,
    flatWeeksBeforeBump: 2,
    kcalBumpWhenFlat: 250,
    waistGrowthLimitCm: 3.0,
    kcalCutWhenWaistGrows: 200,
  );

  final start = DateTime(2026, 9, 28);

  /// One entry per day from [start], following [kgs].
  List<WeightEntry> daily(List<double> kgs) => [
    for (var i = 0; i < kgs.length; i++)
      WeightEntry(
        date: start.add(Duration(days: i)),
        kg: kgs[i],
      ),
  ];

  /// A steady gain of [perWeek] kg over [days], with realistic daily noise.
  List<WeightEntry> gaining(double from, double perWeek, int days) {
    const noise = [0.0, 0.4, -0.3, 0.2, -0.4, 0.3, -0.2];
    return [
      for (var i = 0; i < days; i++)
        WeightEntry(
          date: start.add(Duration(days: i)),
          kg: from + perWeek * i / 7 + noise[i % noise.length],
        ),
    ];
  }

  group('the rolling average', () {
    test('a single reading averages to itself', () {
      final p = trend.points(daily([50.0]));
      expect(p, hasLength(1));
      expect(p.single.average, 50.0);
      expect(p.single.sampleCount, 1);
      expect(p.single.isReliable, isFalse);
    });

    test('averages over the window, not over every reading', () {
      // Ten days; the tenth point should average days 4-10 only.
      final p = trend.points(daily([50, 50, 50, 50, 50, 50, 50, 60, 60, 60]));
      expect(p.last.sampleCount, 7);
      // days 4..10 = 50,50,50,50,60,60,60 -> 54.28...
      expect(p.last.average, closeTo(54.29, 0.01));
    });

    test('smooths out the daily kilo of water and gut content', () {
      // The scale swings 1 kg day to day around a flat 50.
      final raw = daily([50.5, 49.6, 50.4, 49.7, 50.3, 49.8, 50.2]);
      final p = trend.points(raw);
      expect(p.last.average, closeTo(50.07, 0.05));
      // The average moves far less than the raw readings do.
      final rawSpread =
          raw.map((e) => e.kg).reduce((a, b) => a > b ? a : b) -
          raw.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
      final avgSpread =
          p.map((x) => x.average).reduce((a, b) => a > b ? a : b) -
          p.map((x) => x.average).reduce((a, b) => a < b ? a : b);
      expect(avgSpread, lessThan(rawSpread));
    });

    test('the window is by DATE, so a gap narrows the sample', () {
      final entries = [
        WeightEntry(date: start, kg: 50),
        WeightEntry(date: start.add(const Duration(days: 20)), kg: 52),
      ];
      final p = trend.points(entries);
      expect(
        p.last.sampleCount,
        1,
        reason: 'nothing else is inside the 7-day window',
      );
      expect(p.last.average, 52);
    });

    test('unsorted input is handled', () {
      final p = trend.points([
        WeightEntry(date: start.add(const Duration(days: 2)), kg: 51),
        WeightEntry(date: start, kg: 50),
        WeightEntry(date: start.add(const Duration(days: 1)), kg: 50.5),
      ]);
      expect(p.map((x) => x.raw).toList(), [50, 50.5, 51]);
    });
  });

  group('weekly change', () {
    test('a steady 0.3 kg a week reads as about 0.3', () {
      final change = trend.weeklyChange(gaining(50, 0.3, 28));
      expect(change, isNotNull);
      expect(change!, closeTo(0.3, 0.12));
    });

    test('a flat scale reads as about zero', () {
      final change = trend.weeklyChange(gaining(50, 0.0, 28));
      expect(change!.abs(), lessThan(0.1));
    });

    test('losing weight reads negative', () {
      final change = trend.weeklyChange(gaining(52, -0.3, 28));
      expect(change!, lessThan(0));
    });

    test('null with a single reading', () {
      expect(trend.weeklyChange(daily([50])), isNull);
    });
  });

  group('flat weeks', () {
    test('a rising average is never flat', () {
      expect(trend.flatWeeks(gaining(50, 0.4, 28)), 0);
    });

    test('three weeks of no movement counts three', () {
      final flat = trend.flatWeeks(gaining(50, 0.0, 28));
      expect(flat, greaterThanOrEqualTo(2));
    });

    test('scale noise inside a plateau does not reset the counter', () {
      // Genuinely flat, but bouncing around by half a kilo.
      final entries = <WeightEntry>[];
      const bounce = [0.0, 0.5, -0.4, 0.3, -0.5, 0.2, -0.1];
      for (var i = 0; i < 28; i++) {
        entries.add(
          WeightEntry(
            date: start.add(Duration(days: i)),
            kg: 50 + bounce[i % bounce.length],
          ),
        );
      }
      expect(trend.flatWeeks(entries), greaterThanOrEqualTo(2));
    });
  });

  group('the eat-more rule', () {
    test('says nothing until there is enough data', () {
      final advice = trend.advise(daily([50, 50.2]), rules);
      expect(advice.verdict, NutritionVerdict.tooEarly);
      expect(advice.needsAction, isFalse);
    });

    test('fires after two flat weeks, with the programme\'s own number', () {
      final advice = trend.advise(gaining(50, 0.0, 28), rules);
      expect(advice.verdict, NutritionVerdict.flat);
      expect(advice.kcalDelta, 250);
      expect(advice.message, contains('food problem'));
      expect(advice.needsAction, isTrue);
    });

    test('leaves a working plan alone', () {
      final advice = trend.advise(gaining(50, 0.3, 28), rules);
      expect(advice.verdict, NutritionVerdict.onTrack);
      expect(advice.kcalDelta, 0);
      expect(advice.message, contains('leave the food alone'));
    });

    test('flags losing weight while trying to gain', () {
      final advice = trend.advise(gaining(52, -0.35, 28), rules);
      expect(advice.verdict, NutritionVerdict.losing);
      expect(advice.kcalDelta, greaterThan(0));
    });

    test('flags gaining too fast', () {
      final advice = trend.advise(gaining(50, 1.0, 28), rules);
      expect(advice.verdict, NutritionVerdict.tooFast);
      expect(advice.kcalDelta, 0, reason: 'a warning, not a cut, on its own');
    });

    test('the waist rule OVERRIDES a flat scale', () {
      // Flat weight would normally say "eat more" — but if the waist has
      // grown past the limit, eating more is the wrong answer.
      final advice = trend.advise(
        gaining(50, 0.0, 28),
        rules,
        waistChangeCm: 4.0,
      );
      expect(advice.verdict, NutritionVerdict.tooFast);
      expect(advice.kcalDelta, -200);
      expect(advice.message, contains('Waist'));
    });

    test('a waist inside the limit does not override', () {
      final advice = trend.advise(
        gaining(50, 0.0, 28),
        rules,
        waistChangeCm: 1.5,
      );
      expect(advice.verdict, NutritionVerdict.flat);
      expect(advice.kcalDelta, 250);
    });
  });

  group('projection', () {
    test('extrapolates at the current rate', () {
      final entries = gaining(50, 0.3, 28);
      final at12 = trend.project(entries, 8);
      expect(at12, isNotNull);
      expect(at12!, greaterThan(trend.currentAverage(entries)!));
    });

    test('null without enough history to have a rate', () {
      expect(trend.project(daily([50]), 4), isNull);
    });
  });

  group('the real case: a 50 kg beginner over twelve weeks', () {
    test('gaining 0.3 kg a week lands near 55 kg', () {
      final entries = gaining(50, 0.3, 84);
      final finalAvg = trend.currentAverage(entries)!;
      expect(finalAvg, closeTo(53.5, 1.0));
      expect(trend.advise(entries, rules).verdict, NutritionVerdict.onTrack);
    });

    test('a stall at week 6 is caught and costed', () {
      // Four weeks of gain, then four weeks flat.
      final entries = <WeightEntry>[
        ...gaining(50, 0.3, 28),
        for (var i = 28; i < 56; i++)
          WeightEntry(
            date: start.add(Duration(days: i)),
            kg: 51.2 + (i.isEven ? 0.2 : -0.2),
          ),
      ];
      final advice = trend.advise(entries, rules);
      expect(advice.verdict, NutritionVerdict.flat);
      expect(advice.flatWeeks, greaterThanOrEqualTo(2));
      expect(advice.kcalDelta, 250);
    });
  });
}
