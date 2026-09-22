import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../domain/models/exercise.dart';
import '../domain/models/inventory.dart';
import '../domain/models/programme.dart';
import '../domain/programme/programme_diff.dart';
import '../domain/programme/programme_validator.dart';
import '../domain/progression/cycle_seeder.dart';
import 'db/database.dart';
import 'programme_repository.dart';

/// The outcome of saving an edit.
///
/// A save never fails on a validation error. A half-finished edit the app
/// refuses to store is worse than one it stores and flags — you are standing
/// in a basement between sets, not filling in a form.
class SaveResult {
  const SaveResult({required this.programme, required this.problems});

  final Programme programme;
  final List<Problem> problems;

  List<Problem> get errors => problems.where((p) => p.isError).toList();
  bool get isSound => errors.isEmpty;
}

/// What an import would do, computed before anything is written.
class ImportPreview {
  const ImportPreview({
    required this.incoming,
    required this.diff,
    required this.problems,
  });

  final Programme incoming;
  final ProgrammeDiff diff;
  final List<Problem> problems;

  List<Problem> get errors => problems.where((p) => p.isError).toList();

  /// Errors block an import. An unloadable weight or a missing exercise would
  /// break the runner mid-session, and unlike a local edit there is no
  /// half-finished state to preserve — the file can simply be fixed and
  /// re-exported.
  bool get canApply => errors.isEmpty;

  bool get isRevisionConflict => diff.isRevisionConflict;
}

/// Everything the programme editor needs from storage.
///
/// The domain layer does the thinking; this moves bytes. Edits go to the user
/// copy in the documents directory — the bundled asset is never touched, so
/// "reset to shipped" is one delete away.
class ProgrammeEditorService {
  ProgrammeEditorService({
    required this.repository,
    required this.db,
    required this.library,
    required this.inventory,
  }) : validator = ProgrammeValidator(library: library, inventory: inventory),
       seeder = CycleSeeder(inventory);

  final ProgrammeRepository repository;
  final AppDatabase db;
  final ExerciseLibrary library;
  final Inventory inventory;
  final ProgrammeValidator validator;
  final CycleSeeder seeder;

  /// Validates, then persists. `revision` is bumped by the repository.
  Future<SaveResult> save(Programme programme) async {
    final problems = validator.validate(programme);
    final saved = await repository.saveProgramme(programme);
    return SaveResult(programme: saved, problems: problems);
  }

  List<Problem> check(Programme programme) => validator.validate(programme);

  // ---- import / export -------------------------------------------------

  /// Writes the active programme as formatted JSON.
  ///
  /// Formatted rather than compact on purpose: this file is meant to be
  /// readable on the PC and diffable in git.
  Future<File> exportTo(File destination) async {
    final programme = await repository.loadProgramme();
    await destination.parent.create(recursive: true);
    await destination.writeAsString(
      const JsonEncoder.withIndent('  ').convert(programme.toJson()),
      flush: true,
    );
    return destination;
  }

  /// Parses and checks an incoming file without applying any of it.
  Future<ImportPreview> inspectImport(File file) async {
    final raw = await file.readAsString();
    final Programme incoming;
    try {
      incoming = Programme.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      throw FormatException('That is not a Keller Twelve programme file: $e');
    }
    final current = await repository.loadProgramme();
    return ImportPreview(
      incoming: incoming,
      diff: ProgrammeDiff.between(current, incoming),
      problems: validator.validate(incoming),
    );
  }

  /// Applies a previewed import. The caller must have shown the diff.
  Future<Programme> applyImport(Programme incoming) async {
    final current = await repository.loadProgramme();
    // Keep revision monotonic so a later import can still spot a conflict,
    // even when the file came in with a lower number.
    final revision = incoming.revision > current.revision
        ? incoming.revision - 1
        : current.revision;
    return repository.saveProgramme(incoming.copyWith(revision: revision));
  }

  Future<Programme> resetToShipped() => repository.resetToShipped();

  // ---- cycle 2 ---------------------------------------------------------

  /// The heaviest working set logged for each exercise in the Test block.
  ///
  /// Read from `set_logs` by `exercise_id`, never through the programme, so a
  /// swap made during the cycle cannot hide a result.
  Future<List<TestResult>> testWeekResults(Programme programme) async {
    final testBlock = programme.blocks.firstWhere(
      (b) => b.isTest,
      orElse: () => programme.blocks.last,
    );
    final weeks = testBlock.weeks.toSet();

    final sessions = await db.select(db.sessions).get();
    final ids = sessions
        .where((s) => weeks.contains(s.weekNo))
        .map((s) => s.id)
        .toSet();
    if (ids.isEmpty) return const [];

    final sets =
        await (db.select(db.setLogs)..where(
              (l) => l.sessionId.isIn(ids.toList()) & l.isWarmup.equals(false),
            ))
            .get();

    final best = <String, TestResult>{};
    for (final s in sets) {
      final kg = s.loadKg, reps = s.reps;
      if (kg == null || reps == null || reps < 1) continue;
      final candidate = TestResult(
        exerciseId: s.exerciseId,
        weightKg: kg,
        reps: reps,
        testedOn: s.completedAt,
      );
      final prior = best[s.exerciseId];
      if (prior == null || candidate.e1rmKg > prior.e1rmKg) {
        best[s.exerciseId] = candidate;
      }
    }
    return best.values.toList();
  }

  /// The most recent working load for every exercise with any history.
  ///
  /// This is what carries an untested accessory into the next cycle instead
  /// of resetting it to a beginner's opening weight.
  Future<Map<String, double>> lastLoggedLoads() async {
    final rows =
        await (db.select(db.setLogs)
              ..where((l) => l.isWarmup.equals(false))
              ..orderBy([(l) => OrderingTerm.asc(l.completedAt)]))
            .get();
    final out = <String, double>{};
    for (final r in rows) {
      final kg = r.loadKg;
      if (kg == null || kg <= 0) continue;
      out[r.exerciseId] = kg; // ascending order leaves the newest in place
    }
    return out;
  }

  /// Builds the week-13 proposal. Persists nothing.
  Future<CycleSeed> proposeNextCycle({
    DateTime? startDate,
    double? bodyweightKg,
    List<TestResult>? overrideResults,
  }) async {
    final programme = await repository.loadProgramme();
    final results = overrideResults ?? await testWeekResults(programme);
    return seeder.seed(
      programme: programme,
      results: results,
      lastLoggedKg: await lastLoggedLoads(),
      startDate: startDate,
      bodyweightKg: bodyweightKg,
    );
  }

  /// Writes the proposed cycle over the current one.
  ///
  /// The set logs are untouched: they carry their own `exercise_id` and a new
  /// cycle is not a reason to lose twelve weeks of history.
  Future<SaveResult> applyNextCycle(CycleSeed seed) => save(seed.programme);
}
