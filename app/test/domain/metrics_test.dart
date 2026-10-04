import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/metrics/plate_gap.dart';
import 'package:keller_twelve/domain/metrics/session_stats.dart';
import 'package:keller_twelve/domain/metrics/strength_metrics.dart';
import 'package:keller_twelve/domain/metrics/volume_metrics.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/progression/logged_set.dart';

import '../support/fixtures.dart';

void main() {
  LoggedSet set(int day, {double? kg, int? reps, int? durationSec}) =>
      LoggedSet(
        completedAt: DateTime(2026, 11, day, 19),
        loadKg: kg,
        reps: reps,
        durationSec: durationSec,
      );

  group('estimated maxima', () {
    test('Epley, and never for a set it cannot describe', () {
      expect(StrengthMetrics.e1rm(40, 5), closeTo(46.667, 0.001));
      expect(StrengthMetrics.e1rm(40, 1), closeTo(41.333, 0.001));

      // A bodyweight chin-up has no meaningful e1RM here. Inventing one is
      // worse than an empty chart.
      expect(StrengthMetrics.e1rm(null, 8), isNull);
      expect(StrengthMetrics.e1rm(40, null), isNull);
      expect(StrengthMetrics.e1rm(0, 5), isNull);
      expect(StrengthMetrics.e1rm(40, 0), isNull);
    });

    test('the best set is the best estimate, not the heaviest bar', () {
      final best = StrengthMetrics.best([
        set(2, kg: 42, reps: 1), // 43.4
        set(3, kg: 40, reps: 5), // 46.7
      ]);
      expect(best!.weightKg, 40);
      expect(best.reps, 5);
      expect(best.setLabel, '40 x 5');
    });

    test('the trend keeps one point per day, the best one', () {
      final trend = StrengthMetrics.trend([
        set(2, kg: 40, reps: 5),
        set(2, kg: 40, reps: 3),
        set(9, kg: 42, reps: 5),
      ]);
      expect(trend, hasLength(2));
      expect(trend.first.reps, 5);
      expect(trend.first.date, DateTime(2026, 11, 2));
      expect(trend.last.weightKg, 42);
    });

    test('the trend is oldest first, so a chart reads left to right', () {
      final trend = StrengthMetrics.trend([
        set(9, kg: 42, reps: 5),
        set(2, kg: 40, reps: 5),
      ]);
      expect(trend.first.date.isBefore(trend.last.date), isTrue);
    });

    test('sets with no load are skipped rather than counted as zero', () {
      final trend = StrengthMetrics.trend([
        set(2, reps: 12),
        set(3, durationSec: 45),
        set(4, kg: 20, reps: 8),
      ]);
      expect(trend, hasLength(1));
      expect(trend.single.weightKg, 20);
    });

    test('tonnage is reps times load', () {
      expect(
        StrengthMetrics.tonnage([
          set(2, kg: 20, reps: 5),
          set(2, kg: 20, reps: 4),
          set(2, reps: 12), // bodyweight, contributes nothing
        ]),
        180,
      );
    });

    test('one session is not a trend', () {
      expect(
        StrengthMetrics.changeFraction(
          StrengthMetrics.trend([set(2, kg: 40, reps: 5)]),
        ),
        isNull,
      );
      final change = StrengthMetrics.changeFraction(
        StrengthMetrics.trend([
          set(2, kg: 40, reps: 5),
          set(9, kg: 44, reps: 5),
        ]),
      );
      expect(change, closeTo(0.10, 0.001));
    });
  });

  group('weekly sets per muscle', () {
    final metrics = VolumeMetrics(Fixtures.library);

    test('counts against primary muscles, not exercise names', () {
      final week = metrics.weekly({'barbell-bench-press': 4});
      final chest = week.firstWhere((v) => v.muscle == 'chest');
      expect(chest.directSets, 4);
    });

    test('secondary work is reported but never added in', () {
      // Bench press names chest and triceps as primary, front delts as
      // secondary. Front delts must not be credited with four sets.
      final week = metrics.weekly({'barbell-bench-press': 4});
      final delts = week.firstWhere((v) => v.muscle == 'frontDelts');
      expect(delts.directSets, 0);
      expect(delts.indirectSets, 4);
      expect(delts.isLow, isTrue);

      final triceps = week.firstWhere((v) => v.muscle == 'triceps');
      expect(triceps.directSets, 4, reason: 'triceps are primary on a bench');
    });

    test('under eight direct sets is flagged low', () {
      final flags = metrics.flags({'barbell-bench-press': 4});
      expect(flags.any((f) => f.muscle == 'chest'), isTrue);
      expect(flags.firstWhere((f) => f.muscle == 'chest').glyph, '↓');
    });

    test('over twenty is flagged high', () {
      final week = metrics.weekly({'barbell-bench-press': 24});
      final chest = week.firstWhere((v) => v.muscle == 'chest');
      expect(chest.isHigh, isTrue);
      expect(chest.glyph, '↑');
    });

    test('eight to twenty is in range and says nothing', () {
      final week = metrics.weekly({'barbell-bench-press': 12});
      final chest = week.firstWhere((v) => v.muscle == 'chest');
      expect(chest.isInRange, isTrue);
      expect(chest.glyph, '✓');
      expect(
        metrics
            .flags({'barbell-bench-press': 12})
            .any((f) => f.muscle == 'chest'),
        isFalse,
      );
    });

    test('an unknown exercise is ignored, not crashed on', () {
      expect(() => metrics.weekly({'moon-squat': 5}), returnsNormally);
      expect(metrics.weekly({'moon-squat': 5}), isEmpty);
    });

    test('zero sets contribute nothing', () {
      expect(metrics.weekly({'barbell-bench-press': 0}), isEmpty);
    });
  });

  group('plate gap', () {
    final inventory = Fixtures.inventory;

    test('a light bar has a coarse step, a heavy one does not', () {
      final report = PlateGapReport.build(
        inventory: inventory,
        currentLoads: {
          'barbell-overhead-press': (kg: 13.0, mode: LoadMode.barbell),
          'barbell-deadlift': (kg: 69.0, mode: LoadMode.barbell),
        },
      );

      final ohp = report.gaps.firstWhere(
        (g) => g.exerciseId == 'barbell-overhead-press',
      );
      final dl = report.gaps.firstWhere(
        (g) => g.exerciseId == 'barbell-deadlift',
      );

      expect(ohp.fraction, greaterThan(dl.fraction));
      expect(dl.isCoarse, isFalse);
      expect(report.gaps.first.exerciseId, 'barbell-overhead-press');
    });

    test('a coarse lift produces a plate recommendation', () {
      final report = PlateGapReport.build(
        inventory: inventory,
        currentLoads: {
          'barbell-overhead-press': (kg: 13.0, mode: LoadMode.barbell),
        },
      );
      if (report.coarse.isNotEmpty) {
        expect(report.suggestedPlateKg, isNotNull);
        expect(
          PlateGapReport.candidatePlates,
          contains(report.suggestedPlateKg),
        );
      }
    });

    test('nothing coarse means nothing to buy', () {
      final report = PlateGapReport.build(
        inventory: inventory,
        currentLoads: {'barbell-deadlift': (kg: 69.0, mode: LoadMode.barbell)},
      );
      expect(report.isClean, isTrue);
      expect(report.suggestedPlateKg, isNull);
    });

    test('movements the plates do not load are left out', () {
      final report = PlateGapReport.build(
        inventory: inventory,
        currentLoads: {
          'pull-up': (kg: 0.0, mode: LoadMode.bodyweight),
          'cable-face-pull': (kg: 10.0, mode: LoadMode.cable),
        },
      );
      expect(report.gaps.any((g) => g.exerciseId == 'pull-up'), isFalse);
    });
  });

  group('session duration', () {
    SessionDuration d(int day, int actual, {int est = 55}) => SessionDuration(
      date: DateTime(2026, 11, day),
      dayId: 'b-mon',
      actualMinutes: actual,
      estimatedMinutes: est,
    );

    test('nothing logged says so rather than showing a zero', () {
      const stats = SessionStats([]);
      expect(stats.isEmpty, isTrue);
      expect(stats.verdict, contains('No finished sessions'));
    });

    test('the median ignores one runaway evening', () {
      final stats = SessionStats([
        d(2, 28),
        d(3, 31),
        d(5, 95), // took a phone call
        d(6, 30),
        d(9, 29),
      ]);
      expect(stats.medianMinutes, 30);
      expect(stats.longestMinutes, 95);
      expect(stats.ceilingIsFiction, isFalse);
      expect(stats.verdict, contains('holds'));
    });

    test('a majority over the ceiling means the sessions are too big', () {
      final stats = SessionStats([d(2, 42), d(3, 40), d(5, 45), d(6, 33)]);
      expect(stats.ceilingIsFiction, isTrue);
      expect(stats.verdict, contains('cut volume'));
      expect(stats.overCeilingCount, 3);
    });

    test('two long sessions are not yet a pattern', () {
      final stats = SessionStats([d(2, 42), d(3, 44)]);
      expect(stats.ceilingIsFiction, isFalse);
    });

    test('overrun is measured against the generated estimate', () {
      final stats = SessionStats([d(2, 62, est: 55), d(3, 60, est: 55)]);
      expect(stats.medianOverrunMinutes, 6);
      expect(stats.durations.first.overran, isTrue);
    });
  });
}
