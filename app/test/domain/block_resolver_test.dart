import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';

import '../support/fixtures.dart';

void main() {
  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);
  final emptyBar = Fixtures.inventory.barWeight('barbell');

  Prescription find(List<Day> days, String id) => days
      .expand((d) => d.allPrescriptions)
      .firstWhere(
        (p) => p.id == id,
        orElse: () => throw StateError('no prescription $id'),
      );

  group('block selection', () {
    test('each week maps to exactly one block', () {
      const expected = {
        1: 'foundation',
        2: 'foundation',
        3: 'foundation',
        4: 'foundation',
        5: 'build',
        6: 'build',
        7: 'build',
        8: 'deload',
        9: 'push',
        10: 'push',
        11: 'push',
        12: 'test',
      };
      expected.forEach((week, blockId) {
        expect(programme.blockForWeek(week)?.id, blockId, reason: 'week $week');
      });
    });

    test('weeks outside the programme have no block', () {
      expect(programme.blockForWeek(0), isNull);
      expect(programme.blockForWeek(13), isNull);
    });
  });

  group('foundation — authored days pass through untouched', () {
    final days = resolver.resolveDays(programme.blockById('foundation')!, 1);

    test('all seven weekdays are defined', () {
      expect(days.map((d) => d.weekday).toSet(), Weekday.values.toSet());
    });

    test('week 1 squat starts on the empty bar', () {
      final squat = find(days, 'f-mon-1');
      expect(squat.exerciseId, 'barbell-back-squat');
      expect(emptyBar, 10.0, reason: 'the definitive kit: a 10 kg bar');
      expect(squat.startLoadKg, emptyBar);
      expect(squat.sets, 3);
    });

    test('deadlift and overhead press exist in week 1 — the v1 gap', () {
      // v1 never trained these before week 5, then opened at 45 kg for 4x5.
      final ids = days
          .expand((d) => d.allPrescriptions)
          .map((p) => p.exerciseId);
      expect(ids, contains('barbell-deadlift'));
      expect(ids, contains('barbell-overhead-press'));
      expect(ids, contains('barbell-bent-over-row'));
      expect(find(days, 'f-wed-1').startLoadKg, emptyBar);
      expect(find(days, 'f-wed-2').startLoadKg, emptyBar);
    });

    test('defaultRir 3 is inherited where targetRir is null', () {
      // 3, not 4: a logged RIR 3 must not block the jump (coach review M4).
      expect(find(days, 'f-mon-1').targetRir, 3);
    });

    test('the main lifts ramp from week 1', () {
      for (final id in ['f-mon-1', 'f-wed-1', 'f-fri-1']) {
        expect(find(days, id).warmupRamp, isTrue, reason: id);
      }
    });

    test('an explicit targetRir still wins over the block default', () {
      expect(find(days, 'f-fri-3b').targetRir, 3);
    });
  });

  group('build — the source of the inherited blocks', () {
    final days = resolver.resolveDays(programme.blockById('build')!, 5);

    test('defaultRir 2 is inherited by the main lifts', () {
      expect(find(days, 'b-mon-1').targetRir, 2);
      expect(find(days, 'b-tue-1').targetRir, 2);
    });

    test('supersets survive', () {
      expect(find(days, 'b-mon-3a').groupId, isNotNull);
      expect(find(days, 'b-mon-3a').groupId, find(days, 'b-mon-3b').groupId);
    });

    test('Lower B curls the hamstrings with the ring curl', () {
      // It replaced the suitcase carry, and kept its id (coach review M8).
      final curl = find(days, 'b-thu-4');
      expect(curl.exerciseId, 'ring-hamstring-curl');
      expect(curl.optional, isFalse);
      expect(curl.substitutes, contains('nordic-curl-negative'));
    });

    test('every upper day presses and pulls — the v1 B1 bug', () {
      const push = {'horizontalPush', 'verticalPush', 'extension'};
      const pull = {'horizontalPull', 'verticalPull', 'curl'};
      final library = Fixtures.library;

      for (final id in ['b-tue', 'b-fri']) {
        final day = days.firstWhere((d) => d.id == id);
        var pushSets = 0, pullSets = 0;
        for (final p in day.loggedPrescriptions.where((p) => !p.optional)) {
          final pattern = library.resolve(p.exerciseId).pattern;
          if (push.contains(pattern)) pushSets += p.sets;
          if (pull.contains(pattern)) pullSets += p.sets;
        }
        expect(pushSets, greaterThan(0), reason: '$id has no pressing');
        expect(pullSets, greaterThan(0), reason: '$id has no pulling');
        // 3, not 2, since v3 gave Upper A direct triceps work (coach review
        // M7): 13 v 10 counting pushdowns and laterals, 7 v 7 on compounds.
        expect(
          (pushSets - pullSets).abs(),
          lessThanOrEqualTo(3),
          reason: '$id is skewed: push $pushSets vs pull $pullSets',
        );
      }
    });
  });

  group('deload — week 8 resolves from build', () {
    final block = programme.blockById('deload')!;
    final days = resolver.resolveDays(block, 8);

    test('sets scale by 0.60, rounded UP, never below 1', () {
      // 4 sets * 0.6 = 2.4 -> 3.  3 * 0.6 = 1.8 -> 2.
      expect(find(days, 'b-mon-1').sets, 3);
      expect(find(days, 'b-mon-2').sets, 2);
      expect(find(days, 'b-thu-1').sets, 2);
      for (final p in days.expand((d) => d.allPrescriptions)) {
        expect(p.sets, greaterThanOrEqualTo(1), reason: p.id);
      }
    });

    test('loads scale to 70%', () {
      final build = resolver.resolveDays(programme.blockById('build')!, 5);
      for (final id in ['b-mon-1', 'b-thu-1']) {
        expect(
          find(days, id).startLoadKg,
          closeTo(find(build, id).startLoadKg! * 0.7, 1e-9),
          reason: id,
        );
      }
    });

    test('supersets unwind into straight sets', () {
      for (final p in days.expand((d) => d.allPrescriptions)) {
        expect(p.groupId, isNull, reason: '${p.id} still grouped');
      }
    });

    test('finisher sections are dropped', () {
      for (final d in days) {
        expect(d.sections.any((s) => s.type == SectionType.finisher), isFalse);
      }
    });

    test('defaultRir 4 reaches the main lifts — the audit C2 fix', () {
      // In build these leave targetRir null, so the deload actually softens
      // them. If every prescription restated its RIR, this would be 2.
      expect(find(days, 'b-mon-1').targetRir, 4);
      expect(find(days, 'b-tue-1').targetRir, 4);
      expect(find(days, 'b-thu-1').targetRir, 4);
    });

    test('an explicitly harder accessory is NOT softened', () {
      // Lateral raises are RIR 1 by intent, not by default.
      expect(find(days, 'b-tue-4b').targetRir, 1);
    });

    test('the source block is not mutated', () {
      final build = programme.blockById('build')!;
      final again = resolver.resolveDays(build, 5);
      expect(find(again, 'b-mon-1').sets, 4);
      expect(find(again, 'b-mon-1').startLoadKg, 21.0);
      expect(find(again, 'b-mon-1').targetRir, 2);
    });
  });

  group('push — weeks 9-11 resolve from build with overrides', () {
    final block = programme.blockById('push')!;
    final days = resolver.resolveDays(block, 9);

    test('the lead lift of each day gains a set and drops to RIR 1', () {
      expect(find(days, 'b-mon-1').sets, 5);
      expect(find(days, 'b-mon-1').targetRir, 1);
      expect(find(days, 'b-tue-1').sets, 5);
      expect(find(days, 'b-tue-1').targetRir, 1);
      expect(find(days, 'b-thu-1').sets, 4);
      expect(find(days, 'b-fri-1').sets, 5);
    });

    test('loads are unchanged — push adds volume, not weight', () {
      final build = resolver.resolveDays(programme.blockById('build')!, 5);
      expect(find(days, 'b-mon-1').startLoadKg, 21.0);
      expect(
        find(days, 'b-thu-1').startLoadKg,
        find(build, 'b-thu-1').startLoadKg,
      );
    });

    test('nordic negatives replace the ring curl, same prescription id', () {
      final nordic = find(days, 'b-thu-4');
      expect(nordic.exerciseId, 'nordic-curl-negative');
      expect(nordic.repsMin, 3);
      expect(nordic.repsMax, 5);
      expect(nordic.restSec, 90);
      expect(nordic.optional, isFalse);
    });

    test('supersets are kept', () {
      expect(find(days, 'b-mon-3a').groupId, isNotNull);
    });

    test('non-overridden accessories keep the block default RIR of 2', () {
      expect(find(days, 'b-mon-2').targetRir, 2);
    });
  });

  group('test block — week 12', () {
    final days = resolver.resolveDays(programme.blockById('test')!, 12);

    test('week 12 Sunday is the 5K time trial', () {
      final sun = days.firstWhere((d) => d.weekday == Weekday.sun);
      final p = sun.allPrescriptions.first;
      expect(p.exerciseId, 'five-k-time-trial');
      expect(p.loadMode, LoadMode.distance);
      expect(p.unit, RepUnit.m);
      expect(p.repsMax, 5000);
    });

    test('the four barbell lifts are each tested for a single set of 5', () {
      for (final id in ['t-mon-1', 't-tue-1', 't-thu-1', 't-fri-1']) {
        final p = find(days, id);
        expect(p.sets, 1, reason: id);
        expect(p.repsMax, 5, reason: id);
        expect(p.targetRir, 0, reason: id);
        expect(p.warmupRamp, isTrue, reason: '$id needs a ramp');
      }
    });

    test('deadlift day is one lift and nothing else', () {
      final thu = days.firstWhere((d) => d.weekday == Weekday.thu);
      expect(thu.loggedPrescriptions, hasLength(1));
    });

    test('max strict pull-ups are tested as an open rep range', () {
      final p = find(days, 't-fri-2');
      expect(p.exerciseId, 'pull-up');
      expect(p.repsMin, 1);
      expect(p.repsMax, greaterThan(8));
    });
  });

  group('detach and duplicate', () {
    test('materialises resolved days and clears the inheritance', () {
      final push = programme.blockById('push')!;
      expect(push.inherits, isTrue);

      final detached = resolver.detach(push, forWeek: 9);
      expect(detached.inherits, isFalse);
      expect(detached.days, isNotEmpty);
      expect(detached.dayOverrides, isEmpty);

      // The overrides are baked in.
      expect(find(detached.days, 'b-mon-1').sets, 5);
      expect(find(detached.days, 'b-mon-1').targetRir, 1);
      expect(find(detached.days, 'b-thu-4').exerciseId, 'nordic-curl-negative');
    });

    test('a detached block resolves to the same thing it came from', () {
      final push = programme.blockById('push')!;
      final before = resolver.resolveDays(push, 9);
      final after = BlockResolver(programme)
          .resolveDays(resolver.detach(push, forWeek: 9), 9);
      for (final p in before.expand((d) => d.allPrescriptions)) {
        final q = find(after, p.id);
        expect(q.sets, p.sets, reason: p.id);
        expect(q.startLoadKg, p.startLoadKg, reason: p.id);
        expect(q.targetRir, p.targetRir, reason: p.id);
        expect(q.groupId, p.groupId, reason: p.id);
      }
    });
  });

  group('the cardio table drives every run (audit C4, coach review §6)', () {
    List<int>? column(CardioWeek row, CardioColumn c) => switch (c) {
      CardioColumn.long => row.longRunMin,
      CardioColumn.second => row.secondRunMin,
    };

    // Every cardioTable prescription the programme authors, by id.
    final runs = <String, Prescription>{
      for (final b in programme.blocks.where((b) => !b.inherits))
        for (final d in b.days)
          for (final p in d.allPrescriptions)
            if (p.progression.type == ProgressionType.cardioTable) p.id: p,
    };

    test('every run names its table column', () {
      expect(runs, isNotEmpty);
      for (final p in runs.values) {
        expect(p.progression.table, isNotNull, reason: p.id);
      }
    });

    test('each week reads its own row, in seconds', () {
      var checked = 0;
      for (var week = 1; week <= programme.totalWeeks; week++) {
        final block = programme.blockForWeek(week)!;
        final row = programme.cardioForWeek(week);
        final days = resolver.resolveDays(block, week);
        for (final p in days.expand((d) => d.allPrescriptions)) {
          if (p.progression.type != ProgressionType.cardioTable) continue;
          final minutes = row == null
              ? null
              : column(row, p.progression.table!);
          expect(minutes, isNotNull, reason: '${p.id} week $week');
          expect(p.unit, RepUnit.sec, reason: p.id);
          expect(p.repsMin, minutes!.first * 60, reason: '${p.id} week $week');
          expect(p.repsMax, minutes.last * 60, reason: '${p.id} week $week');
          checked++;
        }
      }
      expect(checked, greaterThan(20));
    });

    test('the week-11 long run is 35 minutes, not the week-5 24', () {
      final days = resolver.resolveDays(programme.blockById('push')!, 11);
      final run = find(days, 'b-sun-1');
      expect(run.repsMin, 35 * 60);
      expect(run.repsMax, 35 * 60);
      // Build week 5 is still the start of the table.
      final w5 = resolver.resolveDays(programme.blockById('build')!, 5);
      expect(find(w5, 'b-sun-1').repsMin, 24 * 60);
    });

    test('an empty column means NO run that week, and the day says so', () {
      // Week 8 has no second run: the deload's Wednesday is not "the
      // prescription's own 20 minutes", it is nothing.
      var omitted = 0;
      for (var week = 1; week <= programme.totalWeeks; week++) {
        final row = programme.cardioForWeek(week);
        if (row == null) continue;
        final block = programme.blockForWeek(week)!;
        final days = resolver.resolveDays(block, week);
        final source = block.inherits
            ? programme.blockById(block.inheritsDaysFrom!)!.days
            : block.days;
        for (final d in source) {
          for (final p in d.allPrescriptions) {
            if (p.progression.type != ProgressionType.cardioTable) continue;
            if (column(row, p.progression.table!) != null) continue;
            omitted++;
            final day = days.firstWhere((x) => x.id == d.id);
            expect(
              day.allPrescriptions.map((q) => q.id),
              isNot(contains(p.id)),
              reason: '${p.id} week $week',
            );
            expect(day.note, isNotNull, reason: '${d.id} week $week');
            expect(day.note!.toLowerCase(), contains('no '));
            if (day.loggedPrescriptions.isEmpty) {
              expect(day.kind, DayKind.rest, reason: 'nothing left to do');
            }
          }
        }
      }
      expect(omitted, greaterThan(0), reason: 'week 8 has no second run');

      final wed = resolver
          .resolveDays(programme.blockById('deload')!, 8)
          .firstWhere((d) => d.id == 'b-wed');
      expect(wed.loggedPrescriptions, isEmpty);
      expect(wed.kind, DayKind.rest);
      expect(wed.isTrainingDay, isFalse);
    });

    test('a week with no row at all keeps the run as authored', () {
      final json = Fixtures.programmeJson;
      json['cardioProgression'] = [
        for (final r in json['cardioProgression'] as List)
          if (!((r as Map)['weeks'] as List).contains(5)) r,
      ];
      final edited = Programme.fromJson(json);
      final days = BlockResolver(edited)
          .resolveDays(edited.blockById('build')!, 5);
      final run = find(days, 'b-sun-1');
      expect(run.repsMin, runs['b-sun-1']!.repsMin);
      expect(run.repsMax, runs['b-sun-1']!.repsMax);
    });

    test('detaching a block never drops a run for good', () {
      final detached = resolver.detach(programme.blockById('deload')!);
      expect(
        detached.days.expand((d) => d.allPrescriptions).map((p) => p.id),
        contains('b-wed-1'),
      );
    });
  });

  group('resolver error handling', () {
    test(
      'a dangling inheritsDaysFrom throws rather than silently emptying',
      () {
        final broken = programme.copyWith(
          blocks: [
            programme.blockById('build')!.copyWith(id: 'renamed'),
            programme.blockById('push')!,
          ],
        );
        expect(
          () => BlockResolver(broken).resolveDays(broken.blockById('push')!, 9),
          throwsStateError,
        );
      },
    );
  });
}
