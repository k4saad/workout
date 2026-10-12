import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/domain/programme/programme_editor.dart';
import 'package:keller_twelve/domain/programme/programme_validator.dart';

import '../support/fixtures.dart';

void main() {
  const editor = ProgrammeEditor();
  final programme = Fixtures.programme;
  final validator = ProgrammeValidator(
    library: Fixtures.library,
    inventory: Fixtures.inventory,
  );

  Iterable<Prescription> allOf(Programme p) => p.blocks
      .expand((b) => b.days)
      .expand((d) => d.sections)
      .expand((s) => s.prescriptions);

  Prescription find(Programme p, String id) =>
      allOf(p).firstWhere((pre) => pre.id == id);

  /// The section that actually holds the working sets. Index 0 is the
  /// warm-up, which has drills and no prescriptions.
  Section mainOf(Programme p, String dayId) => p.blocks
      .expand((b) => b.days)
      .firstWhere((d) => d.id == dayId)
      .sections
      .firstWhere((s) => s.type == SectionType.main);

  group('editing a prescription', () {
    test('changes only the one addressed', () {
      final next = editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(sets: 5, restSec: 210),
      );
      expect(find(next, 'b-mon-1').sets, 5);
      expect(find(next, 'b-mon-1').restSec, 210);
      expect(find(next, 'b-mon-3').sets, find(programme, 'b-mon-3').sets);
    });

    test('leaves the source programme alone', () {
      editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(sets: 9),
      );
      expect(find(programme, 'b-mon-1').sets, 3);
    });

    test('the result still passes the gates', () {
      final next = editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(sets: 5),
      );
      expect(validator.validate(next).where((e) => e.isError), isEmpty);
    });
  });

  group('removing and adding', () {
    test('removing renumbers the running order without gaps', () {
      final next = editor.removePrescription(programme, 'b-mon-3');
      expect(allOf(next).any((p) => p.id == 'b-mon-3'), isFalse);

      final section = mainOf(next, 'b-mon');
      final orders = section.ordered.map((p) => p.order).toList();
      expect(orders, List.generate(orders.length, (i) => i + 1));
    });

    test('removing one half of a superset leaves a legal day', () {
      // b-tue-3a/3b are a pair. Dropping one must not leave a one-member
      // superset behind (gate V8).
      final next = editor.removePrescription(programme, 'b-mon-2a');
      final survivors = mainOf(next, 'b-mon').prescriptions;
      final orphan = survivors.firstWhere((p) => p.id == 'b-mon-2b');
      expect(orphan.groupId, isNotNull);
      // The validator is the arbiter, and it must be satisfied after a tidy.
      final tidied = editor.ungroupSuperset(next, orphan.groupId!);
      expect(validator.validate(tidied).where((e) => e.isError), isEmpty);
    });

    test('adding appends at the end of the order', () {
      const extra = Prescription(
        id: 'b-mon-9',
        exerciseId: 'ab-wheel-knees',
        order: 0,
        sets: 3,
        repsMin: 8,
        repsMax: 12,
        restSec: 60,
        loadMode: LoadMode.bodyweight,
      );
      final mainIndex = programme.blocks
          .expand((b) => b.days)
          .firstWhere((d) => d.id == 'b-mon')
          .sections
          .indexWhere((s) => s.type == SectionType.main);
      final next = editor.addPrescription(
        programme,
        dayId: 'b-mon',
        sectionIndex: mainIndex,
        prescription: extra,
      );
      final section = mainOf(next, 'b-mon');
      expect(section.ordered.last.id, 'b-mon-9');
      expect(validator.validate(next).where((e) => e.isError), isEmpty);
    });
  });

  group('reordering', () {
    test('a superset moves as one unit', () {
      final before = mainOf(programme, 'b-mon').groups;
      final pairIndex = before.indexWhere((g) => g.length > 1);
      expect(pairIndex, greaterThan(0));

      final member = before[pairIndex].first.id;
      final next = editor.movePrescription(programme, member, up: true);
      final after = mainOf(next, 'b-mon').groups;

      expect(
        after[pairIndex - 1].map((p) => p.id),
        before[pairIndex].map((p) => p.id),
      );
      expect(after[pairIndex - 1], hasLength(before[pairIndex].length));
    });

    test('moving off the top end is a no-op', () {
      final firstId = mainOf(programme, 'b-mon').ordered.first.id;
      final next = editor.movePrescription(programme, firstId, up: true);
      expect(
        mainOf(next, 'b-mon').ordered.map((p) => p.id),
        mainOf(programme, 'b-mon').ordered.map((p) => p.id),
      );
    });
  });

  group('supersets', () {
    test('only the last member carries the rest', () {
      final next = editor.groupAsSuperset(programme, ['b-mon-1', 'b-mon-3']);
      expect(find(next, 'b-mon-1').groupId, isNotNull);
      expect(find(next, 'b-mon-1').groupId, find(next, 'b-mon-3').groupId);
      expect(find(next, 'b-mon-1').restSec, 0);
      expect(find(next, 'b-mon-3').restSec, greaterThan(0));
    });

    test('ungrouping restores a rest on every member', () {
      final group = find(programme, 'b-mon-2a').groupId!;
      final next = editor.ungroupSuperset(programme, group);
      for (final id in ['b-mon-2a', 'b-mon-2b']) {
        expect(find(next, id).groupId, isNull);
        expect(find(next, id).restSec, greaterThan(0));
      }
    });

    test('a one-member group is refused', () {
      final next = editor.groupAsSuperset(programme, ['b-mon-1']);
      expect(find(next, 'b-mon-1').groupId, isNull);
    });
  });

  group('days', () {
    test('a warning can be added and survives a round trip', () {
      final next = editor.updateDay(
        programme,
        'b-mon',
        (d) => d.copyWith(
          warnings: [
            ...d.warnings,
            const DayWarning(title: 'Knee', body: 'Wrap before squatting.'),
          ],
        ),
      );
      final json = Programme.fromJson(next.toJson());
      final day = json.blocks
          .expand((b) => b.days)
          .firstWhere((d) => d.id == 'b-mon');
      expect(day.warnings.last.title, 'Knee');
    });

    test('a day can change weekday without losing its work', () {
      final next = editor.updateDay(
        programme,
        'b-mon',
        (d) => d.copyWith(weekday: Weekday.wed),
      );
      final day = next.blocks
          .expand((b) => b.days)
          .firstWhere((d) => d.id == 'b-mon');
      final before = programme.blocks
          .expand((b) => b.days)
          .firstWhere((d) => d.id == 'b-mon');
      expect(day.weekday, Weekday.wed);
      expect(before.allPrescriptions, isNotEmpty);
      expect(
        day.allPrescriptions.map((p) => p.id),
        before.allPrescriptions.map((p) => p.id),
      );
    });

    test('removing a day removes only that day', () {
      final next = editor.removeDay(programme, 'b-tue');
      expect(
        next.blocks.expand((b) => b.days).any((d) => d.id == 'b-tue'),
        isFalse,
      );
      expect(
        next.blocks.expand((b) => b.days).length,
        programme.blocks.expand((b) => b.days).length - 1,
      );
    });
  });

  group('detach and duplicate', () {
    test('an inheriting block ends up owning its days', () {
      final next = editor.detachAndDuplicate(programme, 'push');
      final push = next.blockById('push')!;

      expect(push.inheritsDaysFrom, isNull);
      expect(push.days, isNotEmpty);
      expect(push.dayOverrides, isEmpty);
      expect(validator.validate(next).where((e) => e.isError), isEmpty);
    });

    test('the resolved loads are baked in, not applied twice', () {
      final resolver = BlockResolver(programme);
      final resolvedBefore = resolver
          .resolveDays(programme.blockById('push')!, 9)
          .expand((d) => d.allPrescriptions)
          .firstWhere((p) => p.exerciseId == 'barbell-back-squat');

      final next = editor.detachAndDuplicate(programme, 'push');
      final after = next
          .blockById('push')!
          .days
          .expand((d) => d.allPrescriptions)
          .firstWhere((p) => p.exerciseId == 'barbell-back-squat');

      expect(after.startLoadKg, resolvedBefore.startLoadKg);
      expect(after.sets, resolvedBefore.sets);
      expect(next.blockById('push')!.loadMultiplier, 1.0);
    });

    test(
      'editing the parent afterwards no longer touches the detached block',
      () {
        final detached = editor.detachAndDuplicate(programme, 'push');
        final edited = editor.updatePrescription(
          detached,
          'b-mon-1',
          (p) => p.copyWith(sets: 99),
        );

        final push = edited
            .blockById('push')!
            .days
            .expand((d) => d.allPrescriptions)
            .firstWhere((p) => p.exerciseId == 'barbell-back-squat');
        expect(push.sets, isNot(99));
      },
    );

    test('ids stay unique, exercise ids do not change', () {
      final next = editor.detachAndDuplicate(programme, 'push');
      final ids = allOf(next).map((p) => p.id).toList();
      expect(ids.length, ids.toSet().length);

      final exercises = next
          .blockById('push')!
          .days
          .expand((d) => d.allPrescriptions)
          .map((p) => p.exerciseId)
          .toSet();
      expect(exercises, contains('barbell-back-squat'));
    });

    test('a block that owns its days is left alone', () {
      final next = editor.detachAndDuplicate(programme, 'build');
      expect(next.blockById('build')!.days, programme.blockById('build')!.days);
    });
  });

  group('the validator catches what the editor can break', () {
    test('the shipped programme is sound', () {
      expect(validator.validate(programme).where((e) => e.isError), isEmpty);
    });

    test('an unloadable start weight is an error, with the gate named', () {
      final broken = editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(startLoadKg: 20.3),
      );
      final problems = validator.validate(broken).where((e) => e.isError);
      expect(problems, hasLength(1));
      expect(problems.single.gate, 'V6');
      expect(problems.single.where, contains('b-mon-1'));
    });

    test('an inverted rep range is an error', () {
      final broken = editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(repsMin: 10, repsMax: 5),
      );
      expect(
        validator.validate(broken).where((e) => e.gate == 'V7'),
        isNotEmpty,
      );
    });

    test('an unknown exercise is an error', () {
      final broken = editor.swapExercise(programme, 'b-mon-1', 'moon-squat');
      final problems = validator.validate(broken).where((e) => e.isError);
      expect(problems.map((e) => e.gate), contains('V2'));
    });

    test('a rep-creep ceiling below the rep range is an error', () {
      final broken = editor.updatePrescription(
        programme,
        'b-mon-1',
        (p) => p.copyWith(repsMax: 8, repsCreepMax: 6),
      );
      expect(
        validator.validate(broken).where((e) => e.gate == 'V7'),
        isNotEmpty,
      );
    });

    test('a missing week is an error', () {
      final broken = editor.updateBlock(
        programme,
        'deload',
        (b) => b.copyWith(weeks: const []),
      );
      expect(
        validator.validate(broken).where((e) => e.gate == 'V3'),
        isNotEmpty,
      );
    });
  });
}
