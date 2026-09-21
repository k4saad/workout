import '../models/block.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/prescription.dart';
import '../models/programme.dart';

/// Resolves a block's days for a given week, applying inheritance,
/// multipliers and overrides.
///
/// Resolution order — this is the spec, and all four of steps 2a/2c/2e and the
/// rounding rule are things v1 either left undefined or never implemented:
///
/// ```
/// 1.  deep-copy the source block's days
/// 2a. sets      := round(sets * setMultiplier, setRounding), clamped to >= 1
/// 2b. load      := load * loadMultiplier
/// 2c. targetRir := prescription.targetRir ?? block.defaultRir       (audit C2)
/// 2d. if !includeFinishers -> drop sections of type finisher
/// 2e. if !includeSupersets -> clear every groupId                    (new)
/// 3.  apply dayOverrides[dayId].prescriptionOverrides[presId]
/// 4.  apply dayOverrides[dayId].weekSpecific[weekNo].prescriptionOverrides
/// ```
///
/// Steps 3 and 4 are shallow merges, and 4 wins over 3.
class BlockResolver {
  const BlockResolver(this.programme);

  final Programme programme;

  /// The days of [block] as they should be performed in [week].
  ///
  /// Throws [StateError] if the block inherits from a block that does not
  /// exist, or from one that itself inherits (one level only, deliberately —
  /// a chain would make "detach and duplicate" ambiguous).
  List<Day> resolveDays(Block block, int week) {
    final source = _sourceBlock(block);

    var days = source.days;

    // 2d — drop finisher sections entirely.
    if (!block.includeFinishers) {
      days = days
          .map(
            (d) => d.copyWith(
              sections: d.sections
                  .where((s) => s.type != SectionType.finisher)
                  .toList(),
            ),
          )
          .toList();
    }

    // 2a / 2b / 2c / 2e
    days = days
        .map((d) => d.mapPrescriptions((p) => _applyBlock(p, block)))
        .toList();

    // 3 and 4 — overrides, week-specific last.
    days = days.map((d) => _applyOverrides(d, block, week)).toList();

    return days;
  }

  /// The day of [block] falling on [weekday] in [week], or null if the block
  /// defines no day for that weekday.
  Day? resolveDay(Block block, int week, Weekday weekday) {
    for (final d in resolveDays(block, week)) {
      if (d.weekday == weekday) return d;
    }
    return null;
  }

  Block _sourceBlock(Block block) {
    if (!block.inherits) return block;
    final src = programme.blockById(block.inheritsDaysFrom!);
    if (src == null) {
      throw StateError(
        "block '${block.id}' inherits from '${block.inheritsDaysFrom}', "
        'which does not exist',
      );
    }
    if (src.inherits) {
      throw StateError(
        "block '${block.id}' inherits from '${src.id}', which itself "
        'inherits — inheritance is one level only',
      );
    }
    return src;
  }

  Prescription _applyBlock(Prescription p, Block block) {
    // 2a — set count. Always at least one: a deload never removes a movement.
    final sets = block.setMultiplier == 1.0
        ? p.sets
        : block.setRounding.apply(p.sets, block.setMultiplier);

    // 2b — load. The engine snaps this to the lattice later; where 70% of an
    // already-light lift falls below the bare bar, the solver clamps to base
    // and says so rather than pretending (gate V12).
    final load = (p.startLoadKg == null || block.loadMultiplier == 1.0)
        ? p.startLoadKg
        : p.startLoadKg! * block.loadMultiplier;

    // 2c — RIR inheritance. THE fix for audit C2: v1 declared defaultRir on
    // every block and nothing ever read it, so its deload softened nothing.
    final rir = p.targetRir ?? block.defaultRir;

    // 2e — unwind supersets so a deload is not rushed.
    return p.copyWith(
      sets: sets,
      startLoadKg: load,
      targetRir: rir,
      clearGroupId: !block.includeSupersets,
    );
  }

  Day _applyOverrides(Day day, Block block, int week) {
    final dayOv = block.dayOverrides[day.id] as Map<String, dynamic>?;
    if (dayOv == null) return day;

    final base =
        (dayOv['prescriptionOverrides'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final weekMap = (dayOv['weekSpecific'] as Map?)?.cast<String, dynamic>();
    final weekOv =
        (weekMap?['$week'] as Map?)
                ?.cast<String, dynamic>()['prescriptionOverrides']
            as Map? ??
        const <String, dynamic>{};
    final weekSpecific = weekOv.cast<String, dynamic>();

    if (base.isEmpty && weekSpecific.isEmpty) return day;

    return day.mapPrescriptions((p) {
      var out = p;
      final b = base[p.id] as Map<String, dynamic>?;
      if (b != null) out = out.applyOverride(b);
      final w = weekSpecific[p.id] as Map<String, dynamic>?;
      if (w != null) out = out.applyOverride(w);
      return out;
    });
  }

  /// Materialises an inheriting block into a standalone one: resolved days
  /// become real `days`, and the inheritance is cleared.
  ///
  /// This is the "detach and duplicate" the in-app editor offers, so Push can
  /// diverge from Build without touching Build.
  Block detach(Block block, {int? forWeek}) {
    if (!block.inherits) return block;
    final week = forWeek ?? block.firstWeek;
    return block.copyWith(
      days: resolveDays(block, week),
      clearInherits: true,
      dayOverrides: const {},
      loadMultiplier: 1.0,
      setMultiplier: 1.0,
    );
  }
}
