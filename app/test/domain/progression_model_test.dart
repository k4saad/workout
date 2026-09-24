import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';

import '../support/fixtures.dart';

/// The Progression model has to carry every field the schema defines, or an
/// in-app edit (which saves through `Programme.toJson`) silently drops it.
void main() {
  group('Progression.table', () {
    test('parses both columns', () {
      final long = Progression.fromJson(const {
        'type': 'cardioTable',
        'table': 'long',
      });
      final second = Progression.fromJson(const {
        'type': 'cardioTable',
        'table': 'second',
      });
      expect(long.table, CardioColumn.long);
      expect(second.table, CardioColumn.second);
    });

    test('is absent on everything that is not a cardio table run', () {
      final dp = Progression.fromJson(const {
        'type': 'doubleProgression',
        'incrementKg': 2.0,
      });
      expect(dp.table, isNull);
      expect(dp.toJson().containsKey('table'), isFalse);
    });

    test('survives toJson and back', () {
      const p = Progression(
        type: ProgressionType.cardioTable,
        table: CardioColumn.second,
        stallLimit: 99,
      );
      expect(p.toJson()['table'], 'second');
      final back = Progression.fromJson(p.toJson());
      expect(back, p);
      expect(back.table, CardioColumn.second);
    });

    test('is part of equality, so an edit that changes it is a change', () {
      const a = Progression(
        type: ProgressionType.cardioTable,
        table: CardioColumn.long,
      );
      const b = Progression(
        type: ProgressionType.cardioTable,
        table: CardioColumn.second,
      );
      expect(a == b, isFalse);
      expect(a.copyWith(table: CardioColumn.second), b);
    });

    test('an unknown column reads as none rather than bricking the app', () {
      final p = Progression.fromJson(const {
        'type': 'cardioTable',
        'table': 'tempo',
      });
      expect(p.table, isNull);
    });
  });

  test('saving the shipped programme keeps every run on its table column', () {
    // The editor path: parse, save, parse again.
    final raw = Fixtures.programmeJson;
    final saved = Programme.fromJson(Fixtures.programme.toJson());

    final want = <String, String>{};
    for (final b in raw['blocks'] as List) {
      for (final d in (b as Map)['days'] as List) {
        for (final s in (d as Map)['sections'] as List) {
          for (final p in (s as Map)['prescriptions'] as List) {
            final prog = (p as Map)['progression'] as Map;
            if (prog['type'] == 'cardioTable') {
              want[p['id'] as String] = prog['table'] as String;
            }
          }
        }
      }
    }
    expect(want, isNotEmpty);

    final got = <String, String>{};
    for (final b in saved.blocks) {
      for (final d in b.days) {
        for (final p in d.allPrescriptions) {
          if (p.progression.type == ProgressionType.cardioTable) {
            got[p.id] = p.progression.table!.toJson();
          }
        }
      }
    }
    expect(got, want);
  });
}
