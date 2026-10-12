import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/progression/cycle_seeder.dart';

import '../support/fixtures.dart';

/// Algorithm E — docs/02-data-model.md.
///
/// What the app says at week 13. Without this the calendar runs out of
/// programme and the athlete is on their own (audit C8).
void main() {
  final inventory = Fixtures.inventory;
  final lattice = Lattice(inventory);
  final programme = Fixtures.programme;
  final seeder = CycleSeeder(inventory);

  /// A plausible week-12 test week: a 5RM on each tested lift.
  List<TestResult> results() => const [
    TestResult(exerciseId: 'barbell-back-squat', weightKg: 36, reps: 5),
    TestResult(exerciseId: 'barbell-bench-press', weightKg: 26, reps: 5),
    TestResult(exerciseId: 'barbell-deadlift', weightKg: 69, reps: 5),
    TestResult(exerciseId: 'barbell-overhead-press', weightKg: 19, reps: 5),
    TestResult(exerciseId: 'barbell-bent-over-row', weightKg: 31, reps: 5),
  ];

  Iterable<Prescription> allOf(Programme p) sync* {
    for (final b in p.blocks) {
      for (final d in b.days) {
        for (final s in d.sections) {
          yield* s.prescriptions;
        }
      }
    }
  }

  group('E-1  e1RM is Epley, and labelled an estimate', () {
    test('40 kg for 5 reps', () {
      const r = TestResult(exerciseId: 'x', weightKg: 40, reps: 5);
      expect(r.e1rmKg, closeTo(40 * (1 + 5 / 30), 1e-9));
      expect(r.e1rmKg, closeTo(46.667, 0.001));
    });

    test('a single rep is its own e1RM', () {
      const r = TestResult(exerciseId: 'x', weightKg: 50, reps: 1);
      expect(r.e1rmKg, closeTo(50 * (1 + 1 / 30), 1e-9));
    });
  });

  group('E-2  every emitted startLoadKg is on the lattice', () {
    test('gate V6 holds for the seeded cycle', () {
      final seed = seeder.seed(programme: programme, results: results());
      var checked = 0;
      for (final p in allOf(seed.programme)) {
        if (p.startLoadKg == null) continue;
        checked++;
        expect(
          lattice.isValid(p.startLoadKg!, p.loadMode),
          isTrue,
          reason:
              '${p.id} (${p.exerciseId}) seeded ${p.startLoadKg} kg on '
              '${p.loadMode.name}, which the plates cannot build',
        );
      }
      expect(checked, greaterThan(10));
    });

    test('a bodyweight movement is not given a load', () {
      final seed = seeder.seed(programme: programme, results: results());
      // Bodyweight and timed work: a kettlebell is not plate-loaded, but it
      // is a load, and keeps one.
      final bw = allOf(seed.programme)
          .where(
            (p) =>
                p.loadMode == LoadMode.bodyweight ||
                p.loadMode == LoadMode.timed,
          )
          .toList();
      expect(bw, isNotEmpty);
      expect(bw.every((p) => p.startLoadKg == null), isTrue);
    });
  });

  group('E-3  structure: blocks dropped, weeks renumbered from 1', () {
    test('Foundation is removed and the rest renumber contiguously', () {
      final seed = seeder.seed(programme: programme, results: results());
      final next = seed.programme;

      expect(next.blockById('foundation'), isNull);
      expect(seed.removedBlocks, contains('foundation'));

      final weeks = [for (final b in next.blocks) ...b.weeks]..sort();
      expect(weeks.first, 1);
      expect(weeks, List.generate(weeks.length, (i) => i + 1));
      expect(next.totalWeeks, weeks.last);
    });

    test('build now opens the cycle, test still closes it', () {
      final seed = seeder.seed(programme: programme, results: results());
      expect(seed.programme.blockForWeek(1)!.id, 'build');
      final last = seed.programme.totalWeeks;
      expect(seed.programme.blockForWeek(last)!.id, 'test');
    });

    test('inheritance survives renumbering', () {
      final seed = seeder.seed(programme: programme, results: results());
      final push = seed.programme.blockById('push')!;
      expect(push.inheritsDaysFrom, 'build');
      expect(seed.programme.blockById(push.inheritsDaysFrom!), isNotNull);
    });

    test('week-keyed tables are remapped, not left pointing at old weeks', () {
      final seed = seeder.seed(programme: programme, results: results());
      final next = seed.programme;
      final valid = {for (var w = 1; w <= next.totalWeeks; w++) w};

      for (final n in next.nutritionPhases) {
        expect(n.weeks, isNotEmpty);
        expect(valid.containsAll(n.weeks), isTrue);
      }
      for (final c in next.cardioProgression) {
        expect(valid.containsAll(c.weeks), isTrue);
      }
      for (final c in next.checkpoints) {
        expect(valid.contains(c.week), isTrue);
      }
      expect(next.nutritionForWeek(1), isNotNull);
      expect(next.cardioForWeek(1), isNotNull);
    });
  });

  group('E-4  the diff lists every changed load', () {
    test('a tested lead lift reports old and new', () {
      final seed = seeder.seed(programme: programme, results: results());
      final squat = seed.changes.firstWhere(
        (c) =>
            c.exerciseId == 'barbell-back-squat' &&
            c.prescriptionId == 'b-mon-1',
      );
      expect(squat.oldKg, 21.0);
      expect(squat.newKg, isNotNull);
      expect(squat.newKg, greaterThan(squat.oldKg!));
      expect(squat.basis, SeedBasis.testedE1rm);
      expect(squat.reason, contains('estimate'));
    });

    test('every prescription whose load moved appears exactly once', () {
      final seed = seeder.seed(programme: programme, results: results());
      final before = {for (final p in allOf(programme)) p.id: p.startLoadKg};
      final moved = <String>{};
      for (final p in allOf(seed.programme)) {
        if (before[p.id] != p.startLoadKg) moved.add(p.id);
      }
      final reported = seed.changes
          .where((c) => c.oldKg != c.newKg)
          .map((c) => c.prescriptionId)
          .toList();
      expect(reported.toSet(), moved);
      expect(reported.length, reported.toSet().length);
    });

    test('nothing tested means nothing invented', () {
      final seed = seeder.seed(programme: programme, results: const []);
      expect(
        seed.changes.where((c) => c.basis == SeedBasis.testedE1rm),
        isEmpty,
      );
    });
  });

  group('E-5  an untested exercise carries over, it is never dropped', () {
    test('last logged load wins over the authored start load', () {
      final seed = seeder.seed(
        programme: programme,
        results: results(),
        lastLoggedKg: const {'incline-dumbbell-press': 9.0},
      );
      final press = allOf(seed.programme)
          .firstWhere((p) => p.exerciseId == 'incline-dumbbell-press');
      expect(press.startLoadKg, 9.0);
      expect(lattice.isValid(press.startLoadKg!, press.loadMode), isTrue);

      final change = seed.changes.firstWhere(
        (c) => c.exerciseId == 'incline-dumbbell-press',
      );
      expect(change.basis, SeedBasis.carriedOver);
    });

    test('an off-lattice logged load is snapped down, not trusted', () {
      final seed = seeder.seed(
        programme: programme,
        results: results(),
        lastLoggedKg: const {'incline-dumbbell-press': 9.3},
      );
      final press = allOf(seed.programme)
          .firstWhere((p) => p.exerciseId == 'incline-dumbbell-press');
      expect(lattice.isValid(press.startLoadKg!, press.loadMode), isTrue);
      expect(press.startLoadKg, lessThanOrEqualTo(9.3));
    });

    test('no test result and no history keeps what was there', () {
      final seed = seeder.seed(programme: programme, results: results());
      final before = allOf(programme).firstWhere((p) => p.id == 'b-mon-2a');
      final after = allOf(seed.programme).firstWhere((p) => p.id == 'b-mon-2a');
      expect(after.startLoadKg, before.startLoadKg);
      expect(after.exerciseId, before.exerciseId);
    });

    test('the seeded cycle keeps every prescription it started with', () {
      final seed = seeder.seed(programme: programme, results: results());
      final kept = allOf(seed.programme).map((p) => p.id).toSet();
      final expected = allOf(programme)
          .where((p) => !p.id.startsWith('f-'))
          .map((p) => p.id)
          .toSet();
      expect(kept, expected);
    });
  });

  group('E-6  role decides the multiplier', () {
    test('a lead lift seeds near 0.75 of e1RM', () {
      final seed = seeder.seed(programme: programme, results: results());
      final squat = allOf(seed.programme).firstWhere((p) => p.id == 'b-mon-1');
      const e1rm = 36 * (1 + 5 / 30);
      final target = CycleSeeder.leadFactor * e1rm;
      expect(squat.startLoadKg, lessThanOrEqualTo(target + 1e-9));
      expect(
        squat.startLoadKg,
        greaterThan(target - lattice.nominalBarbellStep!),
      );
    });

    test('a secondary lift seeds near 0.65 of e1RM', () {
      final seed = seeder.seed(
        programme: programme,
        results: const [
          TestResult(
            exerciseId: 'barbell-bent-over-row',
            weightKg: 50,
            reps: 5,
          ),
        ],
      );
      // The row is Saturday's second lift: a secondary.
      final row = allOf(seed.programme).firstWhere((p) => p.id == 'b-sat-2');
      const e1rm = 50 * (1 + 5 / 30);
      final target = CycleSeeder.secondaryFactor * e1rm;
      expect(row.startLoadKg, lessThanOrEqualTo(target + 1e-9));
      expect(
        row.startLoadKg,
        greaterThan(target - lattice.nominalBarbellStep!),
      );
    });

    test('snapping always rounds down, never above what was earned', () {
      final seed = seeder.seed(programme: programme, results: results());
      for (final c in seed.changes) {
        if (c.basis != SeedBasis.testedE1rm || c.newKg == null) continue;
        expect(
          c.newKg,
          lessThanOrEqualTo(c.targetKg! + 1e-9),
          reason: '${c.prescriptionId} rounded UP past its target',
        );
      }
    });
  });

  group('E-7  dates and revision', () {
    test('startDate is the Monday after the final test week', () {
      final seed = seeder.seed(programme: programme, results: results());
      final d = seed.programme.startDate;
      expect(d.weekday, DateTime.monday);
      expect(d.isAfter(programme.startDate), isTrue);
      final expected = DateTime(
        programme.anchorMonday.year,
        programme.anchorMonday.month,
        programme.anchorMonday.day + 7 * programme.totalWeeks,
      );
      expect(d, expected);
    });

    test('an explicit start date is honoured and normalised to a Monday', () {
      final seed = seeder.seed(
        programme: programme,
        results: results(),
        startDate: DateTime(2027, 1, 6), // a Wednesday
      );
      expect(seed.programme.startDate.weekday, DateTime.monday);
      expect(seed.programme.startDate, DateTime(2027, 1, 4));
    });

    test('revision is bumped so an import can spot the conflict', () {
      final seed = seeder.seed(programme: programme, results: results());
      expect(seed.programme.revision, programme.revision + 1);
      expect(seed.programme.id, isNot(programme.id));
    });

    test('stale twelve-week strength targets are not carried forward', () {
      final seed = seeder.seed(programme: programme, results: results());
      expect(seed.programme.strengthTargets, isEmpty);
      expect(seed.notes.join(' '), contains('target'));
    });
  });

  group('E-8  it is a projection, not a mutation', () {
    test('the source programme is untouched', () {
      final beforeJson = programme.toJson().toString();
      seeder.seed(programme: programme, results: results());
      expect(programme.toJson().toString(), beforeJson);
      expect(programme.blockById('foundation'), isNotNull);
      expect(programme.totalWeeks, 12);
    });
  });
}
