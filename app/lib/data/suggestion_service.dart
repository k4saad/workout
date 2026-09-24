import '../domain/models/block.dart';
import '../domain/models/day.dart';
import '../domain/models/inventory.dart';
import '../domain/models/prescription.dart';
import '../domain/models/programme.dart';
import '../domain/plates/plate_solver.dart';
import '../domain/progression/logged_set.dart';
import '../domain/progression/progression_engine.dart';
import '../domain/progression/ramp_generator.dart';
import 'db/database.dart';

/// Bridges the database to the pure progression engine.
///
/// The engine never sees a Drift row; this is the only place the two meet.
class SuggestionService {
  SuggestionService({
    required AppDatabase db,
    required Inventory inventory,
    Programme? programme,
  }) : this._(db, PlateSolver(inventory), programme);

  SuggestionService._(this.db, this.solver, this.programme)
    : engine = ProgressionEngine(solver),
      ramp = RampGenerator(solver),
      notHistory = {
        for (final Block b in programme?.blocks ?? const <Block>[])
          if (b.isDeload || b.isTest) b.id,
      };

  final AppDatabase db;
  final PlateSolver solver;
  final ProgressionEngine engine;
  final RampGenerator ramp;

  /// Needed to know which sessions are not training history and what a
  /// session's block multiplies loads by. Without it nothing is excluded —
  /// the v2 behaviour, kept for callers that only need the plates.
  final Programme? programme;

  /// Blocks whose sessions never feed a progression decision: the deload
  /// (70% loads at RIR 4 — v2 progressed week 9 from it, coach review §0
  /// item 3) and the test week (a 5RM at RIR 0 is not a working session).
  final Set<String> notHistory;

  /// History lookup precedence (docs/02, algorithm A):
  ///
  ///   1. the same prescription id DOING THE SAME EXERCISE  <- the normal path
  ///   2. the same exercise id anywhere  <- only when 1 is empty (a swap, or
  ///                                        a brand-new prescription)
  ///   3. nothing, so the engine cold-starts
  ///
  /// Step 1 is what stops two prescriptions of the same lift in one week —
  /// single-leg calf raise at 3x15 Monday and 3x20 Thursday — from driving
  /// each other's suggestions.
  ///
  /// Both steps skip [notHistory] blocks and [excludeSessionId] (the session
  /// being run: reopened mid-workout, its own first sets are not "last time").
  Future<List<LoggedSet>> historyFor(
    Prescription p, {
    int? excludeSessionId,
  }) async {
    var rows = await db.lastSetsForPrescription(
      p.id,
      p.exerciseId,
      excludeBlockIds: notHistory,
      excludeSessionId: excludeSessionId,
    );
    if (rows.isEmpty) {
      rows = await db.lastSetsForExercise(
        p.exerciseId,
        excludeBlockIds: notHistory,
        excludeSessionId: excludeSessionId,
      );
    }
    return rows.map(_toLogged).toList();
  }

  static LoggedSet _toLogged(SetLog l) => LoggedSet(
    completedAt: l.completedAt,
    reps: l.reps,
    loadKg: l.loadKg,
    durationSec: l.durationSec,
    distanceM: l.distanceM,
    rir: l.rir,
    targetRepsMin: l.targetRepsMin,
    targetRepsMax: l.targetRepsMax,
    side: l.side,
    note: l.note,
  );

  /// What to do next for one prescription, including how to load it.
  ///
  /// [p] is the block-resolved prescription for the week being trained.
  Future<LoadSuggestion> suggest(
    Prescription p, {
    double blockLoadMultiplier = 1.0,
    DateTime? now,
    int? excludeSessionId,
  }) async {
    final history = await historyFor(p, excludeSessionId: excludeSessionId);
    final stall = await db.stallFor(p.exerciseId, p.id);
    return engine.suggest(
      prescription: p,
      history: history,
      stallCount: stall?.count ?? 0,
      blockLoadMultiplier: blockLoadMultiplier,
      now: now,
    );
  }

  /// One suggestion per logged prescription of [day], for [session].
  ///
  /// This is what the runner pre-fills and what it logs as each set's
  /// target. Computed once, when the session opens: the session's own sets
  /// are excluded, so reopening it mid-workout gives the same answers.
  ///
  /// A deload or test session never moves a stall counter — its outcome is
  /// not history, so it must not count a stall against the next real week.
  Future<Map<String, LoadSuggestion>> forSession(
    Session session,
    Day day, {
    DateTime? now,
  }) async {
    final block = programme?.blockById(session.blockId);
    final multiplier = block?.loadMultiplier ?? 1.0;
    final counts = !notHistory.contains(session.blockId);
    final out = <String, LoadSuggestion>{};
    for (final p in day.loggedPrescriptions) {
      final s = await suggest(
        p,
        blockLoadMultiplier: multiplier,
        now: now,
        excludeSessionId: session.id,
      );
      if (counts) {
        out[p.id] = s;
      } else {
        final stall = await db.stallFor(p.exerciseId, p.id);
        out[p.id] = s.copyWith(newStallCount: stall?.count ?? 0);
      }
    }
    return out;
  }

  /// Writes back the stall counter after a session is logged.
  Future<void> recordOutcome(Prescription p, LoadSuggestion s) =>
      db.setStall(p.exerciseId, p.id, s.newStallCount);

  /// The warm-up ramp for a prescription's working weight.
  List<RampSet> rampFor(Prescription p, double workingKg) =>
      ramp.forWorkingSet(workingKg, p.loadMode, exerciseId: p.exerciseId);

  /// Whether everything in a day can be loaded at once.
  ///
  /// You own one plate set; a day that loads the barbell and a pair of
  /// dumbbells wants the same 5 kg plates in two places.
  ContentionReport contentionFor(
    List<({Prescription prescription, double? kg})> items,
  ) => solver.contention([
    for (final i in items)
      if (i.kg != null) (kg: i.kg!, mode: i.prescription.loadMode),
  ]);
}
