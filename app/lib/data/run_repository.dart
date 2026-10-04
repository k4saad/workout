import 'package:drift/drift.dart';

import '../domain/run/run.dart';
import 'db/database.dart';
import 'db/tables.dart';
import 'session_service.dart';

/// What a run belongs to, when it was started from a programme day.
///
/// Stored on the run denormalised, like a set log's exercise id: the
/// programme can be edited later and the run must still say what it was.
class RunLink {
  const RunLink({
    this.sessionId,
    this.weekNo,
    this.dayId,
    this.prescriptionId,
    this.exerciseId,
    this.target,
    this.targetRepsMin,
    this.targetRepsMax,
  });

  final int? sessionId;
  final int? weekNo;
  final String? dayId;
  final String? prescriptionId;
  final String? exerciseId;

  /// This week's minutes or metres, from the resolved prescription.
  final RunTarget? target;

  /// The target the set log records, as the runner would.
  final int? targetRepsMin;
  final int? targetRepsMax;

  bool get logsASet => sessionId != null && prescriptionId != null;
}

/// GPS runs in the app's private database.
///
/// A trail that starts at the front door is a home address. It is stored
/// here and nowhere else; nothing in this file, or anything it calls, sends
/// it anywhere.
class RunRepository {
  RunRepository(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// Opens a run, or a hike, recording from now.
  Future<int> start({RunLink? link, RunKind kind = RunKind.run}) {
    final now = _clock();
    return db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            kind: Value(kind),
            sessionId: Value(link?.sessionId),
            weekNo: Value(link?.weekNo),
            dayId: Value(link?.dayId),
            prescriptionId: Value(link?.prescriptionId),
            exerciseId: Value(link?.exerciseId),
            runOn: DateTime(now.year, now.month, now.day),
            startedAtMs: now.millisecondsSinceEpoch,
          ),
        );
  }

  /// Appends one accepted fix. Called for every point, as it arrives.
  Future<void> addPoint(
    int runId,
    RunFix fix, {
    bool segmentStart = false,
  }) async {
    final seq = await _nextSeq(runId);
    await db
        .into(db.runPoints)
        .insert(
          RunPointsCompanion.insert(
            runId: runId,
            seq: seq,
            tMs: fix.tMs,
            lat: fix.lat,
            lng: fix.lng,
            accuracyM: Value(fix.accuracyM),
            altitudeM: Value(fix.altitudeM),
            speedMps: Value(fix.speedMps),
            segmentStart: Value(segmentStart),
          ),
        );
  }

  Future<int> _nextSeq(int runId) async {
    final max = db.runPoints.seq.max();
    final row =
        await (db.selectOnly(db.runPoints)
              ..addColumns([max])
              ..where(db.runPoints.runId.equals(runId)))
            .getSingle();
    final m = row.read(max);
    return m == null ? 0 : m + 1;
  }

  Future<Run?> byId(int id) =>
      (db.select(db.runs)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// The run still open, if the app was closed or killed mid-run.
  Future<Run?> active() =>
      (db.select(db.runs)
            ..where(
              (r) => r.status.isIn([
                RunStatus.recording.name,
                RunStatus.paused.name,
              ]),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.startedAtMs)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<RunPoint>> points(int runId) =>
      (db.select(db.runPoints)
            ..where((p) => p.runId.equals(runId))
            ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
          .get();

  /// The run's numbers, replayed from its stored points: counted as a hike
  /// when it was one.
  Future<RunTrack> track(int runId) async {
    final run = await byId(runId);
    final t = run?.kind == RunKind.hike ? RunTrack.hike() : RunTrack();
    for (final p in await points(runId)) {
      t.add(
        RunFix(
          tMs: p.tMs,
          lat: p.lat,
          lng: p.lng,
          accuracyM: p.accuracyM,
          altitudeM: p.altitudeM,
          speedMps: p.speedMps,
        ),
        segmentStart: p.segmentStart,
      );
    }
    return t;
  }

  Future<void> setStatus(int runId, RunStatus status) =>
      (db.update(db.runs)..where((r) => r.id.equals(runId))).write(
        RunsCompanion(status: Value(status)),
      );

  /// Keeps the row's totals current mid-run, so a killed run still shows
  /// its distance on the calendar.
  Future<void> saveProgress(int runId, RunTrack t) =>
      (db.update(db.runs)..where((r) => r.id.equals(runId))).write(_totals(t));

  RunsCompanion _totals(RunTrack t) {
    final first = t.segments.isEmpty ? null : t.segments.first.first;
    final last = t.last;
    return RunsCompanion(
      distanceM: Value(t.distanceM),
      movingMs: Value(t.movingMs),
      maxSpeedMps: Value(t.maxSpeedMps == 0 ? null : t.maxSpeedMps),
      elevGainM: Value(t.elevGainM == 0 ? null : t.elevGainM),
      elevLossM: Value(t.elevLossM == 0 ? null : t.elevLossM),
      maxAltM: Value(t.maxAltM),
      startLat: Value(first?.lat),
      startLng: Value(first?.lng),
      endLat: Value(last?.lat),
      endLng: Value(last?.lng),
    );
  }

  /// Closes the run. A run started from a programme day is logged into that
  /// session as the next set of its prescription: seconds as seconds,
  /// metres as metres. [link] carries this week's targets for the log; a
  /// run resumed after the app was killed has only the row, and logs
  /// without them.
  Future<Run> finish(
    int runId,
    RunTrack t, {
    RunLink? link,
    int? effort,
    String? note,
  }) {
    return db.transaction(() async {
      final run = (await byId(runId))!;
      int? setLogId = run.setLogId;
      if (setLogId == null &&
          run.sessionId != null &&
          run.prescriptionId != null &&
          run.exerciseId != null) {
        final sessions = SessionService(db, clock: _clock);
        final done = await sessions.loggedSetCount(
          run.sessionId!,
          run.prescriptionId!,
        );
        setLogId = await sessions.logSet(
          run.sessionId!,
          SetEntry(
            prescriptionId: run.prescriptionId!,
            exerciseId: run.exerciseId!,
            setIndex: done + 1,
            durationSec: (t.movingMs / 1000).round(),
            distanceM: t.distanceM.round(),
            targetRepsMin: link?.targetRepsMin,
            targetRepsMax: link?.targetRepsMax,
            note: run.kind == RunKind.hike ? 'GPS hike' : 'GPS run',
          ),
        );
      }
      await (db.update(db.runs)..where((r) => r.id.equals(runId))).write(
        _totals(t).copyWith(
          endedAtMs: Value(_clock().millisecondsSinceEpoch),
          status: const Value(RunStatus.finished),
          effort: Value(effort ?? run.effort),
          note: Value(note ?? run.note),
          setLogId: Value(setLogId),
        ),
      );
      return (await byId(runId))!;
    });
  }

  Future<void> setEffort(int runId, int effort) =>
      (db.update(db.runs)..where((r) => r.id.equals(runId))).write(
        RunsCompanion(effort: Value(effort)),
      );

  /// Gone: the run and every point of its trail.
  Future<void> discard(int runId) => db.transaction(() async {
    await (db.delete(db.runPoints)..where((p) => p.runId.equals(runId))).go();
    await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
  });

  /// Finished runs whose day falls in [from]..[to], newest first.
  /// Removes open runs with no trail — a Start with no fix after it, left
  /// behind — and returns how many. Today asks "Run still open?" only about
  /// a run there is something of.
  ///
  /// [olderThan] spares a run started moments ago that is still waiting for
  /// its first fix.
  Future<int> tidyEmptyRuns({Duration olderThan = Duration.zero}) async {
    final open =
        await (db.select(db.runs)..where(
              (r) =>
                  r.status.isInValues([RunStatus.recording, RunStatus.paused]),
            ))
            .get();
    final cutoff = _clock().millisecondsSinceEpoch - olderThan.inMilliseconds;
    var removed = 0;
    for (final r in open) {
      if (r.startedAtMs > cutoff) continue;
      if ((await points(r.id)).isNotEmpty) continue;
      await discard(r.id);
      removed++;
    }
    return removed;
  }

  Future<List<Run>> finishedBetween(DateTime from, DateTime to) =>
      (db.select(db.runs)
            ..where(
              (r) =>
                  r.status.equalsValue(RunStatus.finished) &
                  r.runOn.isBetweenValues(
                    DateTime(from.year, from.month, from.day),
                    DateTime(to.year, to.month, to.day),
                  ),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.startedAtMs)]))
          .get();

  /// Finished recordings of [kind] (every kind when null), newest first.
  Stream<List<Run>> watchFinished({RunKind? kind}) =>
      (db.select(db.runs)
            ..where(
              (r) =>
                  r.status.equalsValue(RunStatus.finished) &
                  (kind == null
                      ? const Constant(true)
                      : r.kind.equalsValue(kind)),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.startedAtMs)]))
          .watch();

  /// Average paces of his recent finished runs of this kind (null: free
  /// runs), newest first: what "easy" means for him right now.
  Future<List<double>> recentPaces(String? exerciseId, {int limit = 5}) async {
    final rows =
        await (db.select(db.runs)
              ..where(
                (r) =>
                    r.status.equalsValue(RunStatus.finished) &
                    r.kind.equalsValue(RunKind.run) &
                    (exerciseId == null
                        ? r.exerciseId.isNull()
                        : r.exerciseId.equals(exerciseId)) &
                    r.distanceM.isBiggerOrEqualValue(500),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.startedAtMs)])
              ..limit(limit))
            .get();
    return [
      for (final r in rows)
        if (r.movingMs > 0) (r.movingMs / 1000) / (r.distanceM / 1000),
    ];
  }
}
