import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';

import '../support/fixtures.dart';

void main() {
  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);

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
      expect(squat.startLoadKg, 9.0);
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
      expect(find(days, 'f-wed-1').startLoadKg, 9.0);
      expect(find(days, 'f-wed-2').startLoadKg, 9.0);
    });

    test('defaultRir 4 is inherited where targetRir is null', () {
      expect(find(days, 'f-mon-1').targetRir, 4);
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

    test('the nordic curl ships switched off until week 9', () {
      expect(find(days, 'b-thu-5').optional, isTrue);
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
        expect(
          (pushSets - pullSets).abs(),
          lessThanOrEqualTo(2),
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
      expect(find(days, 'b-mon-1').startLoadKg, closeTo(21.0 * 0.7, 1e-9));
      expect(find(days, 'b-thu-1').startLoadKg, closeTo(39.0 * 0.7, 1e-9));
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
      expect(find(days, 'b-mon-1').startLoadKg, 21.0);
      expect(find(days, 'b-thu-1').startLoadKg, 39.0);
    });

    test('the nordic curl switches on', () {
      expect(find(days, 'b-thu-5').optional, isFalse);
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
      expect(find(detached.days, 'b-thu-5').optional, isFalse);
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
