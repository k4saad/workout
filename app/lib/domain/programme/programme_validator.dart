import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/inventory.dart';
import '../models/programme.dart';
import '../plates/lattice.dart';

enum ProblemSeverity {
  /// The programme will not behave correctly. Block the import; warn loudly
  /// on an edit, but never refuse to save — a half-finished edit the app
  /// will not store is worse than one it stores and flags.
  error,

  /// Works, but is not what a coach would write.
  warning,
}

/// One thing wrong with a programme.
class Problem {
  const Problem({
    required this.severity,
    required this.gate,
    required this.where,
    required this.message,
  });

  final ProblemSeverity severity;

  /// The validation gate this came from, e.g. `V6`. Matches
  /// docs/02-data-model.md section 1.6 and `tools/validate.py`, so a failure
  /// on the phone and a failure in CI are the same failure.
  final String gate;

  /// Block, day or prescription id.
  final String where;
  final String message;

  bool get isError => severity == ProblemSeverity.error;

  @override
  String toString() => '$gate $where: $message';
}

/// Gates V2–V9 as a runtime check, on any programme.
///
/// `tools/validate.py` guards the data we author; this guards the data the
/// athlete edits at 21:40 in a basement, and the data that arrives through
/// import. Same gates, same names.
///
/// Pure Dart. No I/O.
class ProgrammeValidator {
  ProgrammeValidator({required this.library, required this.inventory})
    : lattice = Lattice(inventory);

  final ExerciseLibrary library;
  final Inventory inventory;
  final Lattice lattice;

  List<Problem> validate(Programme p) {
    final problems = <Problem>[];
    void err(String gate, String where, String msg) => problems.add(
      Problem(
        severity: ProblemSeverity.error,
        gate: gate,
        where: where,
        message: msg,
      ),
    );
    void warn(String gate, String where, String msg) => problems.add(
      Problem(
        severity: ProblemSeverity.warning,
        gate: gate,
        where: where,
        message: msg,
      ),
    );

    // ---- V3: every week covered exactly once ----------------------------
    final seenWeeks = <int, String>{};
    for (final b in p.blocks) {
      for (final w in b.weeks) {
        final prior = seenWeeks[w];
        if (prior != null) {
          err('V3', b.id, 'week $w is also claimed by $prior');
        }
        seenWeeks[w] = b.id;
        if (w < 1 || w > p.totalWeeks) {
          err('V3', b.id, 'week $w is outside 1..${p.totalWeeks}');
        }
      }
    }
    for (var w = 1; w <= p.totalWeeks; w++) {
      if (!seenWeeks.containsKey(w)) {
        err('V3', p.id, 'week $w has no block');
      }
    }

    // ---- V5: a block has days XOR inherits them -------------------------
    final blockIds = {for (final b in p.blocks) b.id};
    for (final b in p.blocks) {
      if (b.days.isEmpty && b.inheritsDaysFrom == null) {
        err('V5', b.id, 'has neither days nor inheritsDaysFrom');
      }
      if (b.days.isNotEmpty && b.inheritsDaysFrom != null) {
        err('V5', b.id, 'has both its own days and inheritsDaysFrom');
      }
      final from = b.inheritsDaysFrom;
      if (from != null) {
        if (!blockIds.contains(from)) {
          err('V5', b.id, 'inherits from "$from", which does not exist');
        } else if (p.blockById(from)!.days.isEmpty) {
          err('V5', b.id, 'inherits from "$from", which has no days itself');
        }
      }
    }

    // ---- ids are unique --------------------------------------------------
    final dayIds = <String>{};
    final prescriptionIds = <String>{};
    if (blockIds.length != p.blocks.length) {
      err('V1', p.id, 'two blocks share an id');
    }

    for (final b in p.blocks) {
      for (final d in b.days) {
        if (!dayIds.add(d.id)) err('V1', d.id, 'duplicate day id');

        for (final s in d.sections) {
          // ---- V8: a superset needs at least two members -----------------
          final groupCounts = <String, int>{};
          for (final pre in s.prescriptions) {
            if (pre.groupId != null) {
              groupCounts[pre.groupId!] = (groupCounts[pre.groupId!] ?? 0) + 1;
            }
          }
          groupCounts.forEach((g, n) {
            if (n < 2) {
              err('V8', d.id, 'superset "$g" has only $n member');
            }
          });

          for (final pre in s.prescriptions) {
            final at = '${d.id}/${pre.id}';
            if (!prescriptionIds.add(pre.id)) {
              err('V1', at, 'duplicate prescription id');
            }

            // ---- V2: references resolve -------------------------------
            if (!library.contains(pre.exerciseId)) {
              err('V2', at, 'unknown exercise "${pre.exerciseId}"');
            }
            for (final sub in pre.substitutes) {
              if (!library.contains(sub)) {
                warn('V2', at, 'substitute "$sub" is not in the library');
              }
            }

            // ---- V7: rep ranges are sane ------------------------------
            if (pre.sets < 1) err('V7', at, 'sets must be at least 1');
            if (pre.repsMin > pre.repsMax) {
              err('V7', at, 'repsMin ${pre.repsMin} > repsMax ${pre.repsMax}');
            }
            if (pre.repsMin < 1) err('V7', at, 'repsMin must be at least 1');
            if (pre.restSec < 0) err('V7', at, 'restSec is negative');
            final creep = pre.repsCreepMax;
            if (creep != null && creep < pre.repsMax) {
              err(
                'V7',
                at,
                'repsCreepMax $creep is below repsMax ${pre.repsMax}, so rep '
                    'creep can never engage',
              );
            }

            // ---- V6: the load exists in this gym -----------------------
            final kg = pre.startLoadKg;
            if (kg != null && !lattice.isValid(kg, pre.loadMode)) {
              err(
                'V6',
                at,
                '$kg kg cannot be built on ${pre.loadMode.name} with the '
                    'plates you own',
              );
            }
            if (kg != null && !pre.loadMode.isPlateLoaded) {
              warn(
                'V6',
                at,
                'a load on ${pre.loadMode.name} is ignored by the runner',
              );
            }

            // ---- V9: units match load modes ---------------------------
            const okForSec = {
              LoadMode.timed,
              LoadMode.bodyweight,
              LoadMode.dumbbellSingle,
              LoadMode.dumbbellPair,
              LoadMode.banded,
            };
            const okForM = {
              LoadMode.distance,
              LoadMode.timed,
              LoadMode.bodyweight,
            };
            switch (pre.unit) {
              case RepUnit.sec:
                if (!okForSec.contains(pre.loadMode)) {
                  err('V9', at, 'seconds on ${pre.loadMode.name}');
                }
              case RepUnit.m:
                if (!okForM.contains(pre.loadMode)) {
                  err('V9', at, 'metres on ${pre.loadMode.name}');
                }
              case RepUnit.reps:
                break;
            }
          }
        }
      }
    }

    // ---- V4: overrides point at things that exist -----------------------
    for (final b in p.blocks) {
      final target = b.inheritsDaysFrom == null
          ? b
          : p.blockById(b.inheritsDaysFrom!);
      if (target == null) continue;
      final ownDayIds = {for (final d in target.days) d.id};
      final ownPreIds = {
        for (final d in target.days)
          for (final s in d.sections)
            for (final pre in s.prescriptions) pre.id,
      };
      b.dayOverrides.forEach((dayId, raw) {
        if (!ownDayIds.contains(dayId)) {
          err('V4', b.id, 'override targets unknown day "$dayId"');
          return;
        }
        final o = raw as Map<String, dynamic>?;
        final pres = o?['prescriptionOverrides'] as Map<String, dynamic>?;
        pres?.forEach((preId, _) {
          if (!ownPreIds.contains(preId)) {
            err('V4', b.id, 'override targets unknown prescription "$preId"');
          }
        });
      });
    }

    return problems;
  }

  /// True when nothing would stop the app behaving correctly.
  bool isSound(Programme p) => validate(p).every((e) => !e.isError);
}
