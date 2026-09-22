import '../calendar/programme_calendar.dart';
import '../models/block.dart';
import '../models/day.dart';
import '../models/inventory.dart';
import '../models/prescription.dart';
import '../models/programme.dart';
import '../plates/lattice.dart';

/// One lift tested in the final week.
///
/// A rep-max, not a one-rep max. Training alone in a basement, a true 1RM is
/// the most dangerous set in the programme; the Test block asks for a heavy
/// five and the arithmetic does the rest.
class TestResult {
  const TestResult({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    this.testedOn,
  });

  final String exerciseId;
  final double weightKg;
  final int reps;
  final DateTime? testedOn;

  /// Epley. **An estimate**, and every surface that shows it must say so —
  /// it drifts high above about eight reps and it has never met you.
  double get e1rmKg => weightKg * (1 + reps / 30);
}

/// Where a seeded load came from. The diff shows this so a number is never
/// unexplained.
enum SeedBasis {
  /// Derived from a week-12 test result via e1RM.
  testedE1rm,

  /// No test result: the last load actually logged, carried straight over.
  carriedOver,

  /// Nothing to go on. What was authored stays.
  unchanged,
}

/// What a prescription is for, which decides the fraction of e1RM it opens at.
///
/// Read off the prescription's own rep scheme rather than a hand-maintained
/// list, so an exercise swapped in the editor is classified correctly without
/// anyone remembering to update a table.
enum SeedRole {
  /// Heavy, low reps — the lift the day is built around. 0.75 of e1RM.
  lead,

  /// Moderate reps, still loaded. 0.65 of e1RM.
  secondary,

  /// High reps. Percentages of a max mean nothing here; carry the load over.
  accessory,
}

/// One line of the diff.
class LoadChange {
  const LoadChange({
    required this.blockId,
    required this.dayId,
    required this.prescriptionId,
    required this.exerciseId,
    required this.role,
    required this.basis,
    required this.reason,
    this.oldKg,
    this.newKg,
    this.targetKg,
    this.e1rmKg,
  });

  final String blockId;
  final String dayId;
  final String prescriptionId;
  final String exerciseId;
  final SeedRole role;
  final SeedBasis basis;

  /// Shown verbatim in the diff sheet.
  final String reason;

  final double? oldKg;
  final double? newKg;

  /// What the arithmetic asked for, before snapping down to the lattice.
  /// Kept so the diff can explain why 26.9 became 26.
  final double? targetKg;

  final double? e1rmKg;

  bool get moved => oldKg != newKg;

  double? get deltaKg =>
      (oldKg == null || newKg == null) ? null : newKg! - oldKg!;
}

/// The proposed next cycle, and everything that changed to get there.
///
/// Nothing here is persisted. The caller shows it as a diff and only then
/// writes [programme] — a twelve-week training history is not something to
/// overwrite on a mis-tap.
class CycleSeed {
  const CycleSeed({
    required this.programme,
    required this.previous,
    required this.changes,
    required this.removedBlocks,
    required this.weekMap,
    required this.notes,
  });

  /// The new cycle, ready to save.
  final Programme programme;

  /// The cycle it came from, untouched.
  final Programme previous;

  final List<LoadChange> changes;
  final List<String> removedBlocks;

  /// Old programme week -> new programme week.
  final Map<int, int> weekMap;

  /// Structural consequences worth reading before applying.
  final List<String> notes;

  List<LoadChange> get movedLoads =>
      changes.where((c) => c.moved).toList(growable: false);

  int get testedCount =>
      changes.where((c) => c.basis == SeedBasis.testedE1rm).length;

  String get headline =>
      '${programme.totalWeeks} weeks · ${movedLoads.length} loads changed · '
      '$testedCount from test results';
}

/// Algorithm E — what the app says at week 13.
///
/// Turns the Test block's results into the next cycle: Foundation dropped
/// (you are no longer a beginner), weeks renumbered from 1, every opening
/// load recomputed from a tested e1RM and snapped **down** onto the lattice.
///
/// Pure. No I/O — hand it results, get a proposal back.
class CycleSeeder {
  CycleSeeder(this.inventory) : lattice = Lattice(inventory);

  final Inventory inventory;
  final Lattice lattice;

  /// Fraction of estimated 1RM a lead lift opens the next cycle at.
  static const double leadFactor = 0.75;

  /// Same, for the secondary movement of a day.
  static const double secondaryFactor = 0.65;

  /// At or below this many reps a movement is being trained for strength.
  static const int leadRepsMax = 6;

  /// Above [leadRepsMax] and up to this, it is a loaded secondary. Beyond it,
  /// a percentage of a max is meaningless and the load carries over.
  static const int secondaryRepsMax = 10;

  SeedRole roleOf(Prescription p) {
    if (p.repsMax <= leadRepsMax) return SeedRole.lead;
    if (p.repsMax <= secondaryRepsMax) return SeedRole.secondary;
    return SeedRole.accessory;
  }

  double factorFor(SeedRole role) => switch (role) {
    SeedRole.lead => leadFactor,
    SeedRole.secondary => secondaryFactor,
    SeedRole.accessory => 1.0,
  };

  CycleSeed seed({
    required Programme programme,
    required List<TestResult> results,
    Map<String, double> lastLoggedKg = const {},
    DateTime? startDate,
    double? bodyweightKg,
  }) {
    final byExercise = {for (final r in results) r.exerciseId: r};
    final notes = <String>[];

    // ---- 1. Drop the blocks the programme says to skip -------------------
    final skip = programme.onComplete?.skipBlocks.toSet() ?? const <String>{};
    final removed = <String>[];
    final surviving = <Block>[];
    for (final b in programme.blocks) {
      if (skip.contains(b.id)) {
        removed.add(b.id);
      } else {
        surviving.add(b);
      }
    }
    if (removed.isNotEmpty) {
      notes.add(
        'Dropped ${removed.join(', ')} — that block was the on-ramp, and you '
        'have already run it.',
      );
    }

    // A block may have inherited its days from one that just vanished.
    // Materialise nothing here: flag it, because silently empty days is the
    // worst possible failure mode on a Monday evening.
    final survivingIds = {for (final b in surviving) b.id};
    for (final b in surviving) {
      final from = b.inheritsDaysFrom;
      if (from != null && !survivingIds.contains(from)) {
        notes.add(
          '${b.name} inherited its days from the removed $from — detach and '
          'duplicate it in the editor before this cycle starts.',
        );
      }
    }

    // ---- 2. Renumber the surviving weeks contiguously from 1 -------------
    final oldWeeks = <int>[for (final b in surviving) ...b.weeks]..sort();
    final weekMap = <int, int>{
      for (var i = 0; i < oldWeeks.length; i++) oldWeeks[i]: i + 1,
    };
    final totalWeeks = oldWeeks.length;

    // ---- 3. Reseed every load -------------------------------------------
    final changes = <LoadChange>[];
    final blocks = <Block>[
      for (final b in surviving)
        b.copyWith(
          weeks: [for (final w in b.weeks) weekMap[w]!],
          days: [
            for (final d in b.days)
              d.copyWith(
                sections: [
                  for (final s in d.sections)
                    s.copyWith(
                      prescriptions: [
                        for (final p in s.prescriptions)
                          _reseed(
                            block: b,
                            day: d,
                            prescription: p,
                            tested: byExercise[p.exerciseId],
                            logged: lastLoggedKg[p.exerciseId],
                            collect: changes.add,
                          ),
                      ],
                    ),
                ],
              ),
          ],
        ),
    ];

    // ---- 4. Week-keyed tables follow the renumbering ---------------------
    final nutrition = [
      for (final n in programme.nutritionPhases)
        if (_mapWeeks(n.weeks, weekMap).isNotEmpty)
          NutritionPhase(
            weeks: _mapWeeks(n.weeks, weekMap),
            kcal: n.kcal,
            proteinG: n.proteinG,
            carbsG: n.carbsG,
            fatG: n.fatG,
            note: n.note,
          ),
    ];
    if (nutrition.isNotEmpty) {
      notes.add(
        'Nutrition now opens at ${nutrition.first.kcal} kcal — you weigh more '
        'than you did in week 1, so the old opening number is already '
        'maintenance.',
      );
    }

    final cardio = [
      for (final c in programme.cardioProgression)
        if (_mapWeeks(c.weeks, weekMap).isNotEmpty)
          CardioWeek(
            weeks: _mapWeeks(c.weeks, weekMap),
            longRunMin: c.longRunMin,
            secondRunMin: c.secondRunMin,
            skipping: c.skipping,
            bag: c.bag,
            note: c.note,
          ),
    ];

    final checkpoints = <Checkpoint>[
      for (final c in programme.checkpoints)
        if (weekMap.containsKey(c.week))
          Checkpoint(
            week: weekMap[c.week]!,
            items: c.items,
            expectedWeightKg: null,
          ),
    ];
    // A cycle that opens without a photo shoot and a tape measure has no
    // before to compare against in twelve weeks. If renumbering left week 1
    // bare, re-anchor the old opening checkpoint there.
    if (!checkpoints.any((c) => c.week == 1) &&
        programme.checkpoints.isNotEmpty) {
      final first = programme.checkpoints.reduce(
        (a, b) => a.week <= b.week ? a : b,
      );
      checkpoints.insert(
        0,
        Checkpoint(week: 1, items: first.items, expectedWeightKg: null),
      );
      notes.add(
        'Re-anchored the opening checkpoint to week 1 — photos and '
        'measurements on day one or there is nothing to compare against.',
      );
    }
    checkpoints.sort((a, b) => a.week.compareTo(b.week));

    notes.add(
      'Cleared the old strength targets. They were arithmetic for a '
      'twelve-week beginner cycle and would read as failure here; the next '
      'set gets written after week 1 of this cycle.',
    );

    // ---- 5. Dates --------------------------------------------------------
    final start = _mondayOf(
      startDate ??
          ProgrammeCalendar.addDays(
            programme.anchorMonday,
            7 * programme.totalWeeks,
          ),
    );

    final next = Programme(
      id: _nextId(programme.id),
      name: _nextName(programme.name),
      schemaVersion: programme.schemaVersion,
      revision: programme.revision + 1,
      startDate: start,
      totalWeeks: totalWeeks,
      notes: programme.notes,
      athlete: bodyweightKg == null
          ? programme.athlete
          : Athlete(
              startWeightKg: bodyweightKg,
              heightCm: programme.athlete.heightCm,
              targetWeightKg: programme.athlete.targetWeightKg,
              ageYears: programme.athlete.ageYears,
              sex: programme.athlete.sex,
              experience: programme.athlete.experience,
              trainsAlone: programme.athlete.trainsAlone,
            ),
      nutritionPhases: nutrition,
      nutritionRules: programme.nutritionRules,
      onComplete: programme.onComplete,
      rules: programme.rules,
      cardioProgression: cardio,
      checkpoints: checkpoints,
      strengthTargets: const [],
      blocks: blocks,
    );

    changes.sort((a, b) {
      final c = a.blockId.compareTo(b.blockId);
      return c != 0 ? c : a.prescriptionId.compareTo(b.prescriptionId);
    });

    return CycleSeed(
      programme: next,
      previous: programme,
      changes: changes,
      removedBlocks: removed,
      weekMap: weekMap,
      notes: notes,
    );
  }

  Prescription _reseed({
    required Block block,
    required Day day,
    required Prescription prescription,
    required TestResult? tested,
    required double? logged,
    required void Function(LoadChange) collect,
  }) {
    final p = prescription;
    final role = roleOf(p);

    // Nothing to seed: bodyweight, bands, timed work and runs carry no load.
    if (!p.loadMode.isPlateLoaded) return p;

    LoadChange change;
    double? newKg;

    if (tested != null && role != SeedRole.accessory) {
      final e1rm = tested.e1rmKg;
      final target = factorFor(role) * e1rm;
      newKg = lattice.snapDown(target, p.loadMode);
      change = LoadChange(
        blockId: block.id,
        dayId: day.id,
        prescriptionId: p.id,
        exerciseId: p.exerciseId,
        role: role,
        basis: SeedBasis.testedE1rm,
        oldKg: p.startLoadKg,
        newKg: newKg,
        targetKg: target,
        e1rmKg: e1rm,
        reason:
            '${tested.weightKg.toStringAsFixed(tested.weightKg == tested.weightKg.roundToDouble() ? 0 : 1)} kg '
            'x ${tested.reps} tested -> ${e1rm.toStringAsFixed(1)} kg '
            'estimated max, opening at '
            '${(factorFor(role) * 100).round()}%.',
      );
    } else if (logged != null) {
      newKg = lattice.snapDown(logged, p.loadMode);
      change = LoadChange(
        blockId: block.id,
        dayId: day.id,
        prescriptionId: p.id,
        exerciseId: p.exerciseId,
        role: role,
        basis: SeedBasis.carriedOver,
        oldKg: p.startLoadKg,
        newKg: newKg,
        targetKg: logged,
        reason: 'Not tested. Carried over from the last load you logged.',
      );
    } else {
      newKg = p.startLoadKg;
      change = LoadChange(
        blockId: block.id,
        dayId: day.id,
        prescriptionId: p.id,
        exerciseId: p.exerciseId,
        role: role,
        basis: SeedBasis.unchanged,
        oldKg: p.startLoadKg,
        newKg: newKg,
        targetKg: p.startLoadKg,
        reason: 'No test result and no history. Left as written.',
      );
    }

    collect(change);
    return newKg == p.startLoadKg ? p : p.copyWith(startLoadKg: newKg);
  }

  static List<int> _mapWeeks(List<int> weeks, Map<int, int> map) => [
    for (final w in weeks)
      if (map.containsKey(w)) map[w]!,
  ]..sort();

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return ProgrammeCalendar.addDays(day, -(day.weekday - DateTime.monday));
  }

  /// `keller-twelve` -> `keller-twelve-c2` -> `keller-twelve-c3`.
  static String _nextId(String id) {
    final m = RegExp(r'^(.*)-c(\d+)$').firstMatch(id);
    if (m == null) return '$id-c2';
    return '${m.group(1)}-c${int.parse(m.group(2)!) + 1}';
  }

  static String _nextName(String name) {
    final m = RegExp(r'^(.*) · Cycle (\d+)$').firstMatch(name);
    if (m == null) return '$name · Cycle 2';
    return '${m.group(1)} · Cycle ${int.parse(m.group(2)!) + 1}';
  }
}
