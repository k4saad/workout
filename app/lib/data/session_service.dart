import 'package:drift/drift.dart';

import '../domain/models/day.dart';
import '../domain/models/enums.dart';
import '../domain/models/prescription.dart';
import 'db/database.dart';
import 'db/tables.dart';

/// One set the athlete is about to record.
class SetEntry {
  const SetEntry({
    required this.prescriptionId,
    required this.exerciseId,
    required this.setIndex,
    this.reps,
    this.loadKg,
    this.durationSec,
    this.distanceM,
    this.rir,
    this.side,
    this.isWarmup = false,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetLoadKg,
    this.note,
  });

  final String prescriptionId;
  final String exerciseId;
  final int setIndex;
  final int? reps;
  final double? loadKg;
  final int? durationSec;
  final int? distanceM;
  final int? rir;
  final String? side;
  final bool isWarmup;

  /// What the SUGGESTION asked for — a crept rep target, this week's run
  /// length — not the prescription's base range. The engine reads these
  /// back as the target to beat; logging the base range instead reset every
  /// creep and deadlocked light dumbbell work (coach review §0 item 4).
  final int? targetRepsMin;
  final int? targetRepsMax;
  final double? targetLoadKg;
  final String? note;
}

/// Owns the lifecycle of a training session.
///
/// Two rules drive the whole design:
///
///  1. **Persist on every set, never on finish.** Phones die mid-session, and
///     a set that only lives in memory is a set the progression engine will
///     never see.
///  2. **An unfinished session is resumable.** Kill the app between sets,
///     reopen it, and you continue exactly where you were.
class SessionService {
  SessionService(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;

  /// Injectable so elapsed-time behaviour is testable. A service that reaches
  /// for DateTime.now() directly cannot be tested at all.
  final DateTime Function() _clock;

  /// Starts (or resumes) the session for [day] on [date].
  ///
  /// Re-opening a day that already has a session returns the existing one
  /// rather than creating a duplicate — tapping "start" twice must not fork
  /// your history.
  Future<Session> start({
    required String programmeId,
    required String blockId,
    required Day day,
    required int weekNo,
    required DateTime date,
    bool retroactive = false,
  }) async {
    final planned = DateTime(date.year, date.month, date.day);
    final existing = await db.sessionForDay(day.id, planned);
    if (existing != null) {
      if (existing.status == SessionStatus.inProgress) return existing;
      // Re-opening a completed or skipped day puts it back in progress so it
      // can be corrected, without losing what is already logged.
      await (db.update(
        db.sessions,
      )..where((s) => s.id.equals(existing.id))).write(
        const SessionsCompanion(
          status: Value(SessionStatus.inProgress),
          finishedAt: Value(null),
        ),
      );
      return (await db.sessionById(existing.id))!;
    }

    final id = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: programmeId,
            blockId: blockId,
            dayId: day.id,
            weekNo: weekNo,
            plannedDate: planned,
            scheduledDate: planned,
            startedAt: Value(retroactive ? null : _clock()),
            status: const Value(SessionStatus.inProgress),
            loggedRetroactively: Value(retroactive),
          ),
        );
    return (await db.sessionById(id))!;
  }

  /// Records one set. Written immediately.
  Future<int> logSet(int sessionId, SetEntry e) => db
      .into(db.setLogs)
      .insert(
        SetLogsCompanion.insert(
          sessionId: sessionId,
          prescriptionId: e.prescriptionId,
          exerciseId: e.exerciseId,
          setIndex: e.setIndex,
          reps: Value(e.reps),
          loadKg: Value(e.loadKg),
          durationSec: Value(e.durationSec),
          distanceM: Value(e.distanceM),
          rir: Value(e.rir),
          side: Value(e.side),
          isWarmup: Value(e.isWarmup),
          targetRepsMin: Value(e.targetRepsMin),
          targetRepsMax: Value(e.targetRepsMax),
          targetLoadKg: Value(e.targetLoadKg),
          note: Value(e.note),
          // The injected clock, like everything else here: history is
          // ordered by this, and a replayed or retro-logged week needs it.
          completedAt: _clock(),
        ),
      );

  /// Corrects a set already logged. Mis-taps happen with chalky hands.
  Future<void> updateSet(
    int setLogId, {
    int? reps,
    double? loadKg,
    int? rir,
    String? note,
  }) => (db.update(db.setLogs)..where((l) => l.id.equals(setLogId))).write(
    SetLogsCompanion(
      reps: reps == null ? const Value.absent() : Value(reps),
      loadKg: loadKg == null ? const Value.absent() : Value(loadKg),
      rir: rir == null ? const Value.absent() : Value(rir),
      note: note == null ? const Value.absent() : Value(note),
    ),
  );

  Future<void> deleteSet(int setLogId) =>
      (db.delete(db.setLogs)..where((l) => l.id.equals(setLogId))).go();

  /// Closes the session.
  ///
  /// [partial] when work was left undone — a short session, or one cut off.
  /// The distinction matters: adherence should not punish a deliberate
  /// forty-minute version the same way it punishes a walkout.
  Future<void> finish(
    int sessionId, {
    bool partial = false,
    bool wasShortened = false,
    double? bodyweightKg,
    int? rpeOverall,
    String? note,
  }) async {
    await (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        finishedAt: Value(_clock()),
        status: Value(
          partial ? SessionStatus.partial : SessionStatus.completed,
        ),
        wasShortened: Value(wasShortened),
        bodyweightKg: bodyweightKg == null
            ? const Value.absent()
            : Value(bodyweightKg),
        rpeOverall: rpeOverall == null
            ? const Value.absent()
            : Value(rpeOverall),
        note: note == null ? const Value.absent() : Value(note),
      ),
    );
  }

  Future<void> markSkipped(int sessionId, {String? note}) =>
      (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
        SessionsCompanion(
          status: const Value(SessionStatus.skipped),
          finishedAt: Value(_clock()),
          note: note == null ? const Value.absent() : Value(note),
        ),
      );

  /// Moves a session to a different date.
  ///
  /// `plannedDate` is untouched: adherence still counts it against the week it
  /// belonged to, while the calendar draws it where it actually happened.
  Future<void> reschedule(int sessionId, DateTime to) =>
      (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
        SessionsCompanion(
          scheduledDate: Value(DateTime(to.year, to.month, to.day)),
        ),
      );

  /// The session to reopen on launch, if the app was killed mid-workout.
  Future<Session?> resumable() => db.inProgressSession();

  /// How many sets of [prescriptionId] are already logged in [sessionId].
  Future<int> loggedSetCount(int sessionId, String prescriptionId) async {
    final rows =
        await (db.select(db.setLogs)..where(
              (l) =>
                  l.sessionId.equals(sessionId) &
                  l.prescriptionId.equals(prescriptionId) &
                  l.isWarmup.equals(false),
            ))
            .get();
    return rows.length;
  }

  /// Progress through a day: completed working sets over planned ones.
  Future<({int done, int planned})> progress(int sessionId, Day day) async {
    final logged = await db.setsForSession(sessionId);
    final done = logged.where((l) => !l.isWarmup).length;
    final planned = day.loggedPrescriptions
        .where((p) => !p.optional)
        .fold(0, (a, p) => a + p.totalWorkingSets);
    return (done: done, planned: planned);
  }

  Future<void> logNiggle({
    required NiggleSite site,
    required int severity,
    String? exerciseId,
    int? sessionId,
    String? note,
  }) => db
      .into(db.niggles)
      .insert(
        NigglesCompanion.insert(
          loggedOn: DateTime.now(),
          site: site,
          severity: severity,
          exerciseId: Value(exerciseId),
          sessionId: Value(sessionId),
          note: Value(note),
        ),
      );

  /// The sets to log for one prescription, expanded for per-side work.
  ///
  /// A 3 x 8 per-side prescription is six entries, not three — that is the
  /// distinction v1 could only express in an unparseable coach note.
  static List<({int setIndex, String? side})> plannedSets(Prescription p) {
    final out = <({int setIndex, String? side})>[];
    for (var i = 1; i <= p.sets; i++) {
      if (p.perSide) {
        out.add((setIndex: i, side: 'L'));
        out.add((setIndex: i, side: 'R'));
      } else {
        out.add((setIndex: i, side: null));
      }
    }
    return out;
  }

  /// What the log input should collect for this prescription.
  static SetInputKind inputKindFor(Prescription p) => switch (p.unit) {
    RepUnit.sec => SetInputKind.duration,
    RepUnit.m => SetInputKind.distance,
    RepUnit.reps =>
      p.loadMode.hasLoad ? SetInputKind.repsAndLoad : SetInputKind.reps,
  };
}

/// Which fields the runner shows for a set.
enum SetInputKind { repsAndLoad, reps, duration, distance }
