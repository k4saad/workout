import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';

import '../support/fixtures.dart';

/// Validation gates V1-V13 from docs/02-data-model.md section 1.6.
///
/// These mirror `tools/validate.py`. They fail the build, not a report — a
/// programme that ships an unloadable weight or a 70-minute session is broken
/// data, and it should never reach the basement.
void main() {
  final programme = Fixtures.programme;
  final library = Fixtures.library;
  final inventory = Fixtures.inventory;
  final lattice = Lattice(inventory);

  /// Blocks that own their days (the ones authored directly).
  final owned = programme.blocks.where((b) => !b.inherits).toList();

  Iterable<({String blockId, String dayId, dynamic section, dynamic p})>
  walkOwned() sync* {
    for (final b in owned) {
      for (final d in b.days) {
        for (final s in d.sections) {
          for (final p in s.prescriptions) {
            yield (blockId: b.id, dayId: d.id, section: s, p: p);
          }
        }
      }
    }
  }

  group('V1 — schema', () {
    test('programme validates against schema.json', () {
      final schema = JsonSchema.create(Fixtures.schemaJson);
      final result = schema.validate(Fixtures.programmeJson);
      expect(
        result.isValid,
        isTrue,
        reason: result.errors.map((e) => e.toString()).join('\n'),
      );
    });
  });

  group('V2 — references resolve', () {
    test('every exerciseId exists in the library', () {
      for (final e in walkOwned()) {
        expect(
          library.contains(e.p.exerciseId),
          isTrue,
          reason: '${e.p.id} -> unknown exerciseId ${e.p.exerciseId}',
        );
      }
    });

    test('every substitute exists in the library', () {
      for (final e in walkOwned()) {
        for (final s in e.p.substitutes) {
          expect(
            library.contains(s),
            isTrue,
            reason: '${e.p.id} -> unknown substitute $s',
          );
        }
      }
    });

    test('every warm-up drill exists in the library', () {
      for (final b in owned) {
        for (final d in b.days) {
          for (final s in d.sections) {
            for (final dr in s.drills) {
              expect(
                library.contains(dr.exerciseId),
                isTrue,
                reason: '${d.id} drill -> unknown ${dr.exerciseId}',
              );
            }
          }
        }
      }
    });

    test('every strengthTarget exerciseId exists', () {
      for (final t in programme.strengthTargets) {
        expect(
          library.contains(t.exerciseId),
          isTrue,
          reason: 'strengthTarget -> unknown ${t.exerciseId}',
        );
      }
    });
  });

  group('V3 — week coverage', () {
    test('weeks 1..totalWeeks are each covered exactly once', () {
      for (var w = 1; w <= programme.totalWeeks; w++) {
        final hits = programme.blocks.where((b) => b.coversWeek(w)).toList();
        expect(
          hits,
          hasLength(1),
          reason: 'week $w covered by ${hits.map((b) => b.id).toList()}',
        );
      }
    });

    test('no block declares a week beyond totalWeeks', () {
      for (final b in programme.blocks) {
        for (final w in b.weeks) {
          expect(
            w,
            lessThanOrEqualTo(programme.totalWeeks),
            reason: '${b.id} declares week $w',
          );
        }
      }
    });
  });

  group('V4 — overrides target real things', () {
    test('every dayOverrides key resolves to a real day and prescription', () {
      for (final b in programme.blocks) {
        final src = b.inherits ? programme.blockById(b.inheritsDaysFrom!)! : b;
        for (final entry in b.dayOverrides.entries) {
          final day = src.days.where((d) => d.id == entry.key).toList();
          expect(
            day,
            hasLength(1),
            reason: '${b.id}: override targets unknown day ${entry.key}',
          );

          final known = day.first.allPrescriptions.map((p) => p.id).toSet();
          final ov = entry.value as Map<String, dynamic>;

          final base = (ov['prescriptionOverrides'] as Map?) ?? const {};
          for (final pid in base.keys) {
            expect(
              known,
              contains(pid),
              reason: '${b.id}/${entry.key}: unknown prescription $pid',
            );
          }

          final weekly = (ov['weekSpecific'] as Map?) ?? const {};
          for (final wk in weekly.entries) {
            expect(
              b.weeks,
              contains(int.parse(wk.key as String)),
              reason: '${b.id}: weekSpecific ${wk.key} not in block weeks',
            );
            final wov =
                ((wk.value as Map)['prescriptionOverrides'] as Map?) ??
                const {};
            for (final pid in wov.keys) {
              expect(
                known,
                contains(pid),
                reason: '${b.id}/${entry.key}/wk${wk.key}: unknown $pid',
              );
            }
          }
        }
      }
    });
  });

  group('V5 — days XOR inheritance', () {
    test(
      'a block has either days or inheritsDaysFrom, never both or neither',
      () {
        for (final b in programme.blocks) {
          expect(
            b.days.isNotEmpty != b.inherits,
            isTrue,
            reason: '${b.id}: days=${b.days.isNotEmpty} inherits=${b.inherits}',
          );
        }
      },
    );

    test('every inheritsDaysFrom names a real, non-inheriting block', () {
      for (final b in programme.blocks.where((b) => b.inherits)) {
        final src = programme.blockById(b.inheritsDaysFrom!);
        expect(src, isNotNull, reason: '${b.id} -> ${b.inheritsDaysFrom}');
        expect(
          src!.inherits,
          isFalse,
          reason: '${b.id} inherits from an inheriting block',
        );
      }
    });
  });

  group('V6 — every startLoadKg is loadable', () {
    // The gate that would have caught v1's 19 unloadable starting weights.
    test('authored loads sit on the plate lattice', () {
      var checked = 0;
      for (final e in walkOwned()) {
        final kg = e.p.startLoadKg as double?;
        final mode = e.p.loadMode as LoadMode;
        if (kg == null || !mode.isPlateLoaded) continue;
        checked++;
        expect(
          lattice.isValid(kg, mode),
          isTrue,
          reason:
              '${e.p.id} ${e.p.exerciseId}: $kg kg is not loadable as '
              '${mode.name} (nearest ${lattice.snapDown(kg, mode)} / '
              '${lattice.snapUp(kg, mode)})',
        );
      }
      expect(
        checked,
        greaterThan(20),
        reason: 'expected the programme to carry real loads',
      );
    });
  });

  group('V7 — rep ranges are sane', () {
    test('repsMin <= repsMax and repsCreepMax >= repsMax', () {
      for (final e in walkOwned()) {
        expect(
          e.p.repsMin,
          lessThanOrEqualTo(e.p.repsMax),
          reason: '${e.p.id}',
        );
        if (e.p.repsCreepMax != null) {
          expect(
            e.p.repsCreepMax,
            greaterThanOrEqualTo(e.p.repsMax),
            reason: '${e.p.id}',
          );
        }
      }
    });
  });

  group('V8 — supersets are real supersets', () {
    test('every groupId has at least two members in the same section', () {
      for (final b in owned) {
        for (final d in b.days) {
          for (final s in d.sections) {
            final counts = <String, int>{};
            for (final p in s.prescriptions) {
              if (p.groupId != null) {
                counts[p.groupId!] = (counts[p.groupId!] ?? 0) + 1;
              }
            }
            counts.forEach((g, n) {
              expect(
                n,
                greaterThanOrEqualTo(2),
                reason: '${d.id}/${s.title}: groupId $g has $n member(s)',
              );
            });
          }
        }
      }
    });

    test('no superset forces a re-plate between rounds', () {
      // Two members needing the SAME implement family at DIFFERENT loads means
      // unscrewing collars every round, and the superset saves nothing. This
      // is what breaks the 60-minute ceiling in practice.
      for (final b in owned) {
        for (final d in b.days) {
          for (final s in d.sections) {
            for (final group in s.groups.where((g) => g.length > 1)) {
              final byFamily = <String, Set<double?>>{};
              for (final p in group) {
                if (!p.loadMode.isPlateLoaded) continue;
                final family =
                    p.loadMode == LoadMode.dumbbellPair ||
                        p.loadMode == LoadMode.dumbbellSingle
                    ? 'dumbbell'
                    : p.loadMode.name;
                (byFamily[family] ??= {}).add(p.startLoadKg);
              }
              byFamily.forEach((family, loads) {
                expect(
                  loads.length,
                  lessThanOrEqualTo(1),
                  reason:
                      '${d.id} superset ${group.first.groupId} needs '
                      '$family at $loads — a re-plate every round',
                );
              });
            }
          }
        }
      }
    });
  });

  group('V9 — units match load modes', () {
    test('sec/m units only on modes that can carry them', () {
      const okForSec = {
        LoadMode.timed,
        LoadMode.bodyweight,
        LoadMode.dumbbellSingle,
        LoadMode.dumbbellPair,
        LoadMode.banded,
      };
      const okForM = {LoadMode.distance, LoadMode.timed, LoadMode.bodyweight};
      for (final e in walkOwned()) {
        switch (e.p.unit as RepUnit) {
          case RepUnit.sec:
            expect(
              okForSec,
              contains(e.p.loadMode),
              reason: '${e.p.id}: sec with ${e.p.loadMode}',
            );
          case RepUnit.m:
            expect(
              okForM,
              contains(e.p.loadMode),
              reason: '${e.p.id}: m with ${e.p.loadMode}',
            );
          case RepUnit.reps:
            break;
        }
      }
    });
  });

  group('V10 — no orphaned exercises', () {
    test('every library exercise is reachable', () {
      final used = <String>{};
      for (final b in programme.blocks) {
        for (final d in b.days) {
          for (final s in d.sections) {
            used.addAll(s.drills.map((dr) => dr.exerciseId));
            for (final p in s.prescriptions) {
              used.add(p.exerciseId);
              used.addAll(p.substitutes);
            }
          }
        }
      }
      used.addAll(programme.strengthTargets.map((t) => t.exerciseId));

      final orphans = library.exercises
          .map((e) => e.id)
          .where((id) => !used.contains(id));
      expect(
        orphans,
        isEmpty,
        reason:
            'unreachable: ${orphans.join(', ')} — an exercise with cues '
            'and a detail page that nothing links to',
      );
    });
  });

  group('V11 — the sixty-minute ceiling', () {
    const ceiling = 60;

    test('no authored lift day exceeds 60 minutes', () {
      for (final b in owned) {
        for (final d in b.days.where((d) => d.kind == DayKind.lift)) {
          expect(
            d.estMinutes,
            lessThanOrEqualTo(ceiling),
            reason: '${d.id} "${d.title}": ${d.estMinutes} min',
          );
        }
      }
    });

    test('inheriting blocks still fit after their overrides add sets', () {
      for (final b in programme.blocks.where((b) => b.inherits)) {
        final src = programme.blockById(b.inheritsDaysFrom!)!;
        for (final d in src.days.where((d) => d.kind == DayKind.lift)) {
          var extra = 0.0;
          final ov = b.dayOverrides[d.id] as Map<String, dynamic>?;
          final po = (ov?['prescriptionOverrides'] as Map?) ?? const {};
          for (final entry in po.entries) {
            final o = entry.value as Map<String, dynamic>;
            final base = d.allPrescriptions
                .where((p) => p.id == entry.key)
                .map((p) => p.sets)
                .firstOrNull;
            if (o['sets'] != null && base != null) {
              // ~190 s for an added heavy set, including its rest.
              extra += ((o['sets'] as num).toInt() - base).clamp(0, 99) * 3.2;
            }
            if (o['optional'] == false) extra += 4.5;
          }
          final est = d.estMinutes * b.setMultiplier + extra;
          expect(
            est,
            lessThanOrEqualTo(ceiling.toDouble()),
            reason: '${b.id}/${d.id} resolves to ~${est.round()} min',
          );
        }
      }
    });
  });

  group('V12 — inherited loads still resolve', () {
    test('deloaded loads snap to a lattice value or clamp to the bare bar', () {
      for (final b in programme.blocks.where((b) => b.inherits)) {
        if (b.loadMultiplier == 1.0) continue;
        final src = programme.blockById(b.inheritsDaysFrom!)!;
        for (final d in src.days) {
          for (final p in d.allPrescriptions) {
            if (p.startLoadKg == null || !p.loadMode.isPlateLoaded) continue;
            final target = p.startLoadKg! * b.loadMultiplier;
            final base = inventory.baseWeightFor(p.loadMode);
            if (target < base) {
              // Correct behaviour: clamp to the bare implement and say so.
              // You cannot deload an empty bar.
              expect(
                lattice.snapDown(target, p.loadMode),
                equals(base),
                reason: '${b.id}/${p.id} should clamp to $base kg',
              );
            } else {
              final snapped = lattice.snapDown(target, p.loadMode);
              expect(
                lattice.isValid(snapped, p.loadMode),
                isTrue,
                reason: '${b.id}/${p.id}: $target -> $snapped',
              );
            }
          }
        }
      }
    });
  });

  group('V13 — defaultRir is load-bearing', () {
    test(
      'some prescription leaves targetRir null so the deload can soften it',
      () {
        for (final b in owned) {
          if (b.defaultRir == null) continue;
          final nulls = b.days
              .expand((d) => d.allPrescriptions)
              .where(
                (p) => p.targetRir == null && p.loadMode != LoadMode.timed,
              );
          expect(
            nulls,
            isNotEmpty,
            reason:
                '${b.id} declares defaultRir=${b.defaultRir} but every '
                'prescription overrides it — the field is dead again',
          );
        }
      },
    );
  });

  group('data sanity beyond the gates', () {
    test('macros agree with the stated kcal', () {
      for (final p in programme.nutritionPhases) {
        expect(
          (p.macroKcal - p.kcal).abs(),
          lessThanOrEqualTo(25),
          reason: 'weeks ${p.weeks}: stated ${p.kcal}, macros ${p.macroKcal}',
        );
      }
    });

    test('round-trips through toJson without losing anything', () {
      final again = Programme.fromJson(programme.toJson());
      expect(again.blocks.length, programme.blocks.length);
      expect(again.totalWeeks, programme.totalWeeks);
      expect(again.startDate, programme.startDate);
      for (var i = 0; i < programme.blocks.length; i++) {
        expect(again.blocks[i].days.length, programme.blocks[i].days.length);
        expect(
          again.blocks[i],
          equals(programme.blocks[i]),
          reason: 'block ${programme.blocks[i].id} did not round-trip',
        );
      }
    });

    test('prescription ids are unique across the programme', () {
      final seen = <String>{};
      for (final e in walkOwned()) {
        expect(
          seen.add(e.p.id as String),
          isTrue,
          reason: 'duplicate prescription id ${e.p.id}',
        );
      }
    });

    test('every cardioTable prescription has a matching cardio row', () {
      for (final b in owned) {
        for (final d in b.days) {
          for (final p in d.allPrescriptions) {
            if (p.progression.type != ProgressionType.cardioTable) continue;
            for (final w in b.weeks) {
              expect(
                programme.cardioForWeek(w),
                isNotNull,
                reason: '${p.id}: no cardio row for week $w',
              );
            }
          }
        }
      }
    });
  });
}
