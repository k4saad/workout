import '../models/block.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/prescription.dart';
import '../models/programme.dart';
import 'block_resolver.dart';

/// Where one prescription lives.
typedef PrescriptionPath = ({
  String blockId,
  String dayId,
  int sectionIndex,
  String prescriptionId,
});

/// Pure edits on a programme.
///
/// Every method returns a NEW programme; nothing is mutated. That is what
/// makes "show me the diff before you apply it" possible everywhere, and it
/// is why an editor crash cannot corrupt the file on disk.
///
/// The editor deliberately does **not** touch `set_logs`. History is keyed by
/// `exercise_id` in the database and survives every operation here, including
/// swapping an exercise out mid-block (docs/03-build-plan.md Phase 8.1).
class ProgrammeEditor {
  const ProgrammeEditor();

  // ---- prescriptions ---------------------------------------------------

  /// Replaces one prescription, found by id, wherever it lives.
  Programme updatePrescription(
    Programme programme,
    String prescriptionId,
    Prescription Function(Prescription) edit,
  ) =>
      _mapPrescriptions(programme, (p) => p.id == prescriptionId ? edit(p) : p);

  /// Swaps the movement while keeping the slot.
  ///
  /// The prescription id is unchanged, so the day still reads the same shape;
  /// only `exerciseId` moves. The engine's history lookup matches on
  /// prescription id **and** exercise id, so the new movement starts from its
  /// own history (or cold) rather than inheriting the old one's loads — a
  /// reverse lunge suggested at a Bulgarian split squat's weight is how you
  /// get hurt.
  ///
  /// [startLoadKg] is cleared unless given, because the previous movement's
  /// opening weight means nothing for the new one.
  Programme swapExercise(
    Programme programme,
    String prescriptionId,
    String newExerciseId, {
    double? startLoadKg,
    LoadMode? loadMode,
  }) => updatePrescription(
    programme,
    prescriptionId,
    (p) => Prescription(
      id: p.id,
      exerciseId: newExerciseId,
      order: p.order,
      groupId: p.groupId,
      unit: p.unit,
      sets: p.sets,
      repsMin: p.repsMin,
      repsMax: p.repsMax,
      repsCreepMax: p.repsCreepMax,
      restSec: p.restSec,
      targetRir: p.targetRir,
      loadMode: loadMode ?? p.loadMode,
      startLoadKg: startLoadKg,
      perSide: p.perSide,
      unilateral: p.unilateral,
      warmupRamp: p.warmupRamp,
      optional: p.optional,
      progression: p.progression,
      substitutes: p.substitutes,
      coachNote: p.coachNote,
      tempo: p.tempo,
    ),
  );

  /// Removes a prescription, and dissolves its superset if that leaves one
  /// member alone (gate V8).
  Programme removePrescription(Programme programme, String prescriptionId) =>
      _mapSections(programme, (section) {
        if (!section.prescriptions.any((p) => p.id == prescriptionId)) {
          return section;
        }
        final kept = section.prescriptions
            .where((p) => p.id != prescriptionId)
            .toList();
        return section.copyWith(prescriptions: _tidy(kept));
      });

  /// Appends a prescription to a section, at the end of the running order.
  Programme addPrescription(
    Programme programme, {
    required String dayId,
    required int sectionIndex,
    required Prescription prescription,
  }) => _mapDays(programme, (day) {
    if (day.id != dayId) return day;
    final sections = [...day.sections];
    if (sectionIndex < 0 || sectionIndex >= sections.length) return day;
    final s = sections[sectionIndex];
    final nextOrder = s.prescriptions.isEmpty
        ? 1
        : s.prescriptions.map((p) => p.order).reduce((a, b) => a > b ? a : b) +
              1;
    sections[sectionIndex] = s.copyWith(
      prescriptions: [
        ...s.prescriptions,
        prescription.copyWith(order: nextOrder),
      ],
    );
    return day.copyWith(sections: sections);
  });

  /// Moves a prescription up or down within its section.
  ///
  /// Superset members move as a unit — splitting a pair by reordering is
  /// never what was meant.
  Programme movePrescription(
    Programme programme,
    String prescriptionId, {
    required bool up,
  }) => _mapSections(programme, (section) {
    final ordered = section.ordered;
    if (!ordered.any((p) => p.id == prescriptionId)) return section;

    final groups = section.groups;
    final gi = groups.indexWhere((g) => g.any((p) => p.id == prescriptionId));
    final target = up ? gi - 1 : gi + 1;
    if (target < 0 || target >= groups.length) return section;

    final reordered = [...groups];
    final moving = reordered.removeAt(gi);
    reordered.insert(target, moving);

    return section.copyWith(
      prescriptions: _tidy([for (final g in reordered) ...g]),
    );
  });

  /// Pairs two movements into a superset, or moves one into an existing group.
  ///
  /// Only the LAST member keeps a rest — that is what makes a five-movement
  /// session fit in sixty minutes.
  Programme groupAsSuperset(
    Programme programme,
    List<String> prescriptionIds, {
    String? groupId,
  }) {
    if (prescriptionIds.length < 2) return programme;
    final g = groupId ?? 'g-${prescriptionIds.first}';
    return _mapSections(programme, (section) {
      if (!prescriptionIds.every(
        (id) => section.prescriptions.any((p) => p.id == id),
      )) {
        return section;
      }
      final updated = [
        for (final p in section.prescriptions)
          prescriptionIds.contains(p.id)
              ? p.copyWith(
                  groupId: g,
                  restSec: p.id == prescriptionIds.last ? p.restSec : 0,
                )
              : p,
      ];
      // Keep members adjacent, in the order given.
      final members = [
        for (final id in prescriptionIds) updated.firstWhere((p) => p.id == id),
      ];
      final others = updated
          .where((p) => !prescriptionIds.contains(p.id))
          .toList();
      final anchor = section.ordered.indexWhere(
        (p) => p.id == prescriptionIds.first,
      );
      final rebuilt = [...others];
      rebuilt.insertAll(anchor.clamp(0, others.length), members);
      return section.copyWith(prescriptions: _tidy(rebuilt));
    });
  }

  /// Unwinds a superset into straight sets, restoring a rest on each member.
  Programme ungroupSuperset(
    Programme programme,
    String groupId, {
    int restSec = 90,
  }) => _mapPrescriptions(
    programme,
    (p) => p.groupId != groupId
        ? p
        : p.copyWith(
            clearGroupId: true,
            restSec: p.restSec == 0 ? restSec : p.restSec,
          ),
  );

  // ---- days ------------------------------------------------------------

  Programme updateDay(
    Programme programme,
    String dayId,
    Day Function(Day) edit,
  ) => _mapDays(programme, (d) => d.id == dayId ? edit(d) : d);

  Programme addDay(Programme programme, String blockId, Day day) =>
      _mapBlocks(programme, (b) {
        if (b.id != blockId) return b;
        return b.copyWith(days: [...b.days, day]);
      });

  Programme removeDay(Programme programme, String dayId) =>
      _mapBlocks(programme, (b) {
        if (!b.days.any((d) => d.id == dayId)) return b;
        return b.copyWith(days: b.days.where((d) => d.id != dayId).toList());
      });

  // ---- blocks ----------------------------------------------------------

  /// Materialises an inheriting block's resolved days and cuts it loose.
  ///
  /// Before: Push says "same as Build, 3% heavier". After: Push owns fifty
  /// prescriptions of its own and Build can be edited without touching it.
  /// Irreversible by design — the diff is shown first.
  ///
  /// Prescription ids are suffixed with the block id so they stay unique
  /// (gate V1) while `exerciseId` is untouched, which is what keeps history
  /// attached after the detach.
  Programme detachAndDuplicate(Programme programme, String blockId) {
    final block = programme.blockById(blockId);
    if (block == null || !block.inherits) return programme;

    final resolver = BlockResolver(programme);
    final week = block.firstWeek;
    final resolved = resolver.resolveDays(block, week);

    final days = [
      for (final d in resolved)
        d.copyWith(
          id: '${d.id}-$blockId',
          sections: [
            for (final s in d.sections)
              s.copyWith(
                prescriptions: [
                  for (final p in s.prescriptions)
                    p.copyWith(
                      id: '${p.id}-$blockId',
                      groupId: p.groupId == null
                          ? null
                          : '${p.groupId}-$blockId',
                    ),
                ],
              ),
          ],
        ),
    ];

    return _mapBlocks(programme, (b) {
      if (b.id != blockId) return b;
      return b.copyWith(
        clearInherits: true,
        dayOverrides: const {},
        // The multipliers have been baked into the resolved days; leaving them
        // on would apply them a second time.
        loadMultiplier: 1.0,
        setMultiplier: 1.0,
        days: days,
      );
    });
  }

  Programme updateBlock(
    Programme programme,
    String blockId,
    Block Function(Block) edit,
  ) => _mapBlocks(programme, (b) => b.id == blockId ? edit(b) : b);

  // ---- plumbing --------------------------------------------------------

  /// Renumbers `order` to 1..n in list sequence, keeping superset members
  /// adjacent. Call after any structural change.
  static List<Prescription> _tidy(List<Prescription> list) => [
    for (var i = 0; i < list.length; i++) list[i].copyWith(order: i + 1),
  ];

  Programme _mapBlocks(Programme p, Block Function(Block) f) =>
      p.copyWith(blocks: [for (final b in p.blocks) f(b)]);

  Programme _mapDays(Programme p, Day Function(Day) f) =>
      _mapBlocks(p, (b) => b.copyWith(days: [for (final d in b.days) f(d)]));

  Programme _mapSections(Programme p, Section Function(Section) f) => _mapDays(
    p,
    (d) => d.copyWith(sections: [for (final s in d.sections) f(s)]),
  );

  Programme _mapPrescriptions(
    Programme p,
    Prescription Function(Prescription) f,
  ) => _mapSections(
    p,
    (s) =>
        s.copyWith(prescriptions: [for (final pre in s.prescriptions) f(pre)]),
  );
}
