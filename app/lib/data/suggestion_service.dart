import '../domain/models/inventory.dart';
import '../domain/models/prescription.dart';
import '../domain/plates/plate_solver.dart';
import '../domain/progression/logged_set.dart';
import '../domain/progression/progression_engine.dart';
import '../domain/progression/ramp_generator.dart';
import 'db/database.dart';

/// Bridges the database to the pure progression engine.
///
/// The engine never sees a Drift row; this is the only place the two meet.
class SuggestionService {
  SuggestionService({required this.db, required Inventory inventory})
    : solver = PlateSolver(inventory),
      engine = ProgressionEngine(PlateSolver(inventory)),
      ramp = RampGenerator(PlateSolver(inventory));

  final AppDatabase db;
  final PlateSolver solver;
  final ProgressionEngine engine;
  final RampGenerator ramp;

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
  Future<List<LoggedSet>> historyFor(Prescription p) async {
    var rows = await db.lastSetsForPrescription(p.id, p.exerciseId);
    if (rows.isEmpty) {
      rows = await db.lastSetsForExercise(p.exerciseId);
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
  Future<LoadSuggestion> suggest(
    Prescription p, {
    double blockLoadMultiplier = 1.0,
    DateTime? now,
  }) async {
    final history = await historyFor(p);
    final stall = await db.stallFor(p.exerciseId, p.id);
    return engine.suggest(
      prescription: p,
      history: history,
      stallCount: stall?.count ?? 0,
      blockLoadMultiplier: blockLoadMultiplier,
      now: now,
    );
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
