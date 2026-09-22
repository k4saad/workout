import 'package:drift/drift.dart';

import '../domain/metrics/plate_gap.dart';
import '../domain/metrics/session_stats.dart';
import '../domain/metrics/strength_metrics.dart';
import '../domain/metrics/volume_metrics.dart';
import '../domain/models/enums.dart';
import '../domain/models/exercise.dart';
import '../domain/models/inventory.dart';
import '../domain/models/programme.dart';
import '../domain/programme/block_resolver.dart';
import '../domain/progression/logged_set.dart';
import 'db/database.dart';

/// One exercise, summarised.
class LiftSummary {
  const LiftSummary({
    required this.exerciseId,
    required this.name,
    required this.trend,
    required this.best,
    required this.workingSets,
    required this.tonnageKg,
    required this.lastTrainedOn,
  });

  final String exerciseId;
  final String name;
  final List<E1rmPoint> trend;
  final E1rmPoint? best;
  final int workingSets;
  final double tonnageKg;
  final DateTime? lastTrainedOn;

  double? get changeFraction => StrengthMetrics.changeFraction(trend);

  bool get hasEstimate => best != null;
}

/// Feeds the pure metrics from the database.
///
/// Every read goes through `set_logs.exercise_id`, never through the live
/// programme, so twelve weeks of history survives an exercise being swapped
/// out in the editor.
class StatsService {
  StatsService({
    required this.db,
    required this.library,
    required this.inventory,
  }) : volume = VolumeMetrics(library);

  final AppDatabase db;
  final ExerciseLibrary library;
  final Inventory inventory;
  final VolumeMetrics volume;

  static LoggedSet toLogged(SetLog l) => LoggedSet(
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

  /// Working sets only — a ramp is not stimulus, and counting it inflates
  /// every volume number on the screen.
  Future<List<SetLog>> _workingSets() =>
      (db.select(db.setLogs)..where((l) => l.isWarmup.equals(false))).get();

  Future<LiftSummary> summaryFor(String exerciseId) async {
    final rows = await db.historyForExercise(exerciseId);
    final sets = rows.map(toLogged).toList();
    return LiftSummary(
      exerciseId: exerciseId,
      name: library.resolve(exerciseId).name,
      trend: StrengthMetrics.trend(sets),
      best: StrengthMetrics.best(sets),
      workingSets: sets.length,
      tonnageKg: StrengthMetrics.tonnage(sets),
      lastTrainedOn: sets.isEmpty
          ? null
          : sets
                .map((s) => s.completedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// Every exercise with logged work, heaviest estimate first.
  Future<List<LiftSummary>> allSummaries() async {
    final rows = await _workingSets();
    final byExercise = <String, List<LoggedSet>>{};
    for (final r in rows) {
      (byExercise[r.exerciseId] ??= []).add(toLogged(r));
    }

    final out = [
      for (final entry in byExercise.entries)
        LiftSummary(
          exerciseId: entry.key,
          name: library.resolve(entry.key).name,
          trend: StrengthMetrics.trend(entry.value),
          best: StrengthMetrics.best(entry.value),
          workingSets: entry.value.length,
          tonnageKg: StrengthMetrics.tonnage(entry.value),
          lastTrainedOn: entry.value
              .map((s) => s.completedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
        ),
    ];
    out.sort((a, b) {
      final ae = a.best?.e1rmKg ?? -1, be = b.best?.e1rmKg ?? -1;
      return be.compareTo(ae);
    });
    return out;
  }

  /// Working sets per exercise for one programme week.
  Future<Map<String, int>> setsInWeek(int weekNo) async {
    final sessions = await (db.select(
      db.sessions,
    )..where((s) => s.weekNo.equals(weekNo))).get();
    final ids = sessions.map((s) => s.id).toSet();
    if (ids.isEmpty) return const {};

    final rows =
        await (db.select(db.setLogs)..where(
              (l) => l.sessionId.isIn(ids.toList()) & l.isWarmup.equals(false),
            ))
            .get();

    final out = <String, int>{};
    for (final r in rows) {
      out[r.exerciseId] = (out[r.exerciseId] ?? 0) + 1;
    }
    return out;
  }

  Future<List<MuscleVolume>> weeklyMuscleVolume(int weekNo) async =>
      volume.weekly(await setsInWeek(weekNo));

  /// The most recent working load for each exercise, with the load mode the
  /// programme prescribes for it.
  Future<PlateGapReport> plateGaps(Programme programme) async {
    final rows =
        await (db.select(db.setLogs)
              ..where((l) => l.isWarmup.equals(false))
              ..orderBy([(l) => OrderingTerm.asc(l.completedAt)]))
            .get();

    final modes = <String, LoadMode>{};
    for (final b in programme.blocks) {
      for (final d in b.days) {
        for (final s in d.sections) {
          for (final p in s.prescriptions) {
            modes[p.exerciseId] = p.loadMode;
          }
        }
      }
    }

    final latest = <String, ({double kg, LoadMode mode})>{};
    for (final r in rows) {
      final kg = r.loadKg;
      final mode = modes[r.exerciseId];
      if (kg == null || kg <= 0 || mode == null) continue;
      latest[r.exerciseId] = (kg: kg, mode: mode); // ascending: newest wins
    }

    return PlateGapReport.build(inventory: inventory, currentLoads: latest);
  }

  /// How long sessions actually take, against what the programme promised.
  Future<SessionStats> sessionDurations(Programme programme) async {
    final sessions = await db.completedSessions();
    final resolver = BlockResolver(programme);

    final out = <SessionDuration>[];
    for (final s in sessions) {
      final started = s.startedAt, finished = s.finishedAt;
      // A session logged retroactively has no honest duration. Leaving it out
      // is better than reporting a zero that drags the median down.
      if (started == null || finished == null) continue;
      final minutes = finished.difference(started).inMinutes;
      if (minutes <= 0) continue;

      final block = programme.blockById(s.blockId);
      final day = block == null
          ? null
          : resolver
                .resolveDays(block, s.weekNo)
                .where((d) => d.id == s.dayId)
                .firstOrNull;

      out.add(
        SessionDuration(
          date: s.scheduledDate,
          dayId: s.dayId,
          actualMinutes: minutes,
          estimatedMinutes: day?.estMinutes ?? 0,
        ),
      );
    }
    return SessionStats(out);
  }

  /// Which joints complained, when, and doing what.
  Future<List<Niggle>> niggles({int limit = 100}) =>
      (db.select(db.niggles)
            ..orderBy([(n) => OrderingTerm.desc(n.loggedOn)])
            ..limit(limit))
          .get();

  Future<void> resolveNiggle(int id, DateTime on) =>
      (db.update(db.niggles)..where((n) => n.id.equals(id))).write(
        NigglesCompanion(resolvedOn: Value(on)),
      );
}
