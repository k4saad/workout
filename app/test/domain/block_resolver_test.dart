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
      for (final id in ['f-mon-1', 'f-wed-1', 'f-sat-1']) {
        expect(find(days, id).warmupRamp, isTrue, reason: id);
      }
    });

    test('an explicit targetRir still wins over the block default', () {
      expect(find(days, 'f-sat-3b').targetRir, 3);
    });
  });

  group('build — the source of the inherited blocks', () {
    final days = resolver.resolveDays(programme.blockById('build')!, 5);

    test('three training days, half an hour each, and the rest is rest', () {
      final training = days.where((d) => d.kind == DayKind.lift).toList();
      expect(training.map((d) => d.weekday), [
        Weekday.mon,
        Weekday.wed,
        Weekday.sat,
      ]);
      for (final d in training) {
        expect(d.estMinutes, lessThanOrEqualTo(35), reason: d.id);
      }
      final sun = days.firstWhere((d) => d.weekday == Weekday.sun);
      expect(sun.optional, isTrue, reason: 'the Sunday run or hike');
    });

    test('defaultRir 2 is inherited by the main lifts', () {
      expect(find(days, 'b-mon-1').targetRir, 2);
      expect(find(days, 'b-sat-1').targetRir, 2);
    });

    test('supersets survive', () {
      expect(find(days, 'b-mon-2a').groupId, isNotNull);
      expect(find(days, 'b-mon-2a').groupId, find(days, 'b-mon-2b').groupId);
    });

    test('every training day presses and pulls — the v1 B1 bug', () {
      const push = {'horizontalPush', 'verticalPush', 'extension'};
      const pull = {'horizontalPull', 'verticalPull', 'curl'};
      final library = Fixtures.library;

      for (final id in ['b-mon', 'b-wed', 'b-sat']) {
        final day = days.firstWhere((d) => d.id == id);
        var pushSets = 0, pullSets = 0;
        for (final p in day.loggedPrescriptions.where((p) => !p.optional)) {
          final pattern = library.resolve(p.exerciseId).pattern;
          if (push.contains(pattern)) pushSets += p.sets;
          if (pull.contains(pattern)) pullSets += p.sets;
        }
        expect(pushSets, greaterThan(0), reason: '$id has no pressing');
        expect(pullSets, greaterThan(0), reason: '$id has no pulling');
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
      // 3 sets * 0.6 = 1.8 -> 2; 2 sets * 0.6 = 1.2 -> 2.
      expect(find(days, 'b-mon-1').sets, 2);
      expect(find(days, 'b-wed-1').sets, 2);
      expect(find(days, 'b-mon-3').sets, 2);
      for (final p in days.expand((d) => d.allPrescriptions)) {
        expect(p.sets, greaterThanOrEqualTo(1), reason: p.id);
      }
    });

    test('loads scale to 70%', () {
      final build = resolver.resolveDays(programme.blockById('build')!, 5);
      for (final id in ['b-mon-1', 'b-wed-1']) {
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
      expect(find(days, 'b-wed-1').targetRir, 4);
      expect(find(days, 'b-sat-1').targetRir, 4);
    });

    test('an explicitly harder accessory is NOT softened', () {
      // Knee raises are RIR 1 by intent, not by default.
      expect(find(days, 'b-mon-3').targetRir, 1);
    });

    test('the source block is not mutated', () {
      final build = programme.blockById('build')!;
      final again = resolver.resolveDays(build, 5);
      expect(find(again, 'b-mon-1').sets, 3);
      expect(find(again, 'b-mon-1').startLoadKg, 21.0);
      expect(find(again, 'b-mon-1').targetRir, 2);
    });
  });

  group('push — weeks 9-11 resolve from build with overrides', () {
    final block = programme.blockById('push')!;
    final days = resolver.resolveDays(block, 9);

    test('the lead lift of each day drops to RIR 1, same sets', () {
      // v4: no added set — the sessions stay half an hour.
      for (final id in ['b-mon-1', 'b-wed-1', 'b-sat-1']) {
        expect(find(days, id).sets, 3, reason: id);
        expect(find(days, id).targetRir, 1, reason: id);
      }
    });

    test('loads are unchanged — push adds effort, not weight', () {
      final build = resolver.resolveDays(programme.blockById('build')!, 5);
      expect(find(days, 'b-mon-1').startLoadKg, 21.0);
      expect(
        find(days, 'b-wed-1').startLoadKg,
        find(build, 'b-wed-1').startLoadKg,
      );
    });

    test('an override can swap the exercise and keep the prescription id', () {
      // The mechanism v3's nordic curl used; v4 has no swap, so it is
      // checked on a copy.
      final json = Fixtures.programmeJson;
      final push = (json['blocks'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['id'] == 'push');
      push['dayOverrides'] = {
        'b-wed': {
          'prescriptionOverrides': {
            'b-wed-3b': {'exerciseId': 'step-up', 'repsMin': 8, 'repsMax': 10},
          },
        },
      };
      final edited = Programme.fromJson(json);
      final swapped = find(
        BlockResolver(edited).resolveDays(edited.blockById('push')!, 9),
        'b-wed-3b',
      );
      expect(swapped.exerciseId, 'step-up');
      expect(swapped.repsMax, 10);
      expect(swapped.groupId, isNotNull);
    });

    test('supersets are kept', () {
      expect(find(days, 'b-mon-2a').groupId, isNotNull);
    });

    test('non-overridden accessories keep the block default RIR of 2', () {
      expect(find(days, 'b-mon-2b').targetRir, 2);
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

    test('the five barbell lifts are each tested for a single set of 5', () {
      for (final id in [
        't-mon-1',
        't-mon-2',
        't-wed-1',
        't-wed-2',
        't-sat-1',
      ]) {
        final p = find(days, id);
        expect(p.sets, 1, reason: id);
        expect(p.repsMax, 5, reason: id);
        expect(p.targetRir, 0, reason: id);
      }
      // The first lift of each day ramps up to it.
      for (final id in ['t-mon-1', 't-wed-1', 't-sat-1']) {
        expect(find(days, id).warmupRamp, isTrue, reason: '$id needs a ramp');
      }
    });

    test('Wednesday is the deadlift and the press, nothing else', () {
      final wed = days.firstWhere((d) => d.weekday == Weekday.wed);
      expect(wed.loggedPrescriptions, hasLength(2));
    });

    test('max strict pull-ups are tested as an open rep range', () {
      final p = find(days, 't-sat-2');
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
      expect(find(detached.days, 'b-mon-1').sets, 3);
      expect(find(detached.days, 'b-mon-1').targetRir, 1);
      expect(find(detached.days, 'b-sat-1').targetRir, 1);
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
      // One run a week — the optional Sunday — in weeks 1-11.
      expect(checked, 11);
    });

    test('the week-11 run is 30 minutes, not the week-5 22', () {
      final days = resolver.resolveDays(programme.blockById('push')!, 11);
      final run = find(days, 'b-sun-1');
      expect(run.repsMin, 30 * 60);
      expect(run.repsMax, 30 * 60);
      // Build week 5 is still the start of the table.
      final w5 = resolver.resolveDays(programme.blockById('build')!, 5);
      expect(find(w5, 'b-sun-1').repsMin, 22 * 60);
    });

    test('an empty column means NO run that week, and the day says so', () {
      // v4's table has no empty week, so one is made on a copy: week 8
      // without its run. The deload's Sunday is then not "the
      // prescription's own minutes", it is nothing.
      final json = Fixtures.programmeJson;
      for (final r
          in (json['cardioProgression'] as List).cast<Map<String, dynamic>>()) {
        if ((r['weeks'] as List).contains(8)) r['longRunMin'] = null;
      }
      final edited = Programme.fromJson(json);
      final days = BlockResolver(edited)
          .resolveDays(edited.blockById('deload')!, 8);
      final sun = days.firstWhere((d) => d.id == 'b-sun');
      expect(sun.allPrescriptions.map((q) => q.id), isNot(contains('b-sun-1')));
      expect(sun.note, isNotNull);
      expect(sun.note!.toLowerCase(), contains('no '));
      expect(sun.loggedPrescriptions, isEmpty);
      expect(sun.kind, DayKind.rest);
      expect(sun.isTrainingDay, isFalse);
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
        contains('b-sun-1'),
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
