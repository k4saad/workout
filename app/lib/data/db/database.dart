import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// The training log.
///
/// Every set is persisted the moment it is logged, never batched to the end of
/// a session — phones die, and a session you cannot recover is a session the
/// progression engine will never see.
@DriftDatabase(
  tables: [
    Sessions,
    SetLogs,
    StallCounters,
    Bodyweights,
    CardioLogs,
    FoodLogs,
    Niggles,
    PhotoShoots,
    ProgressPhotos,
    PhotoPoses,
    Measurements,
    FormClips,
    // v3
    Runs,
    RunPoints,
    MealLogs,
    WaterLogs,
    SupplementLogs,
    NutritionAdjustments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory instance for tests. No device, no files.
  ///
  /// Streams close synchronously so a `.watch()` provider does not leave a
  /// pending timer behind when a widget test ends.
  AppDatabase.memory()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  /// Bump this and add an `onUpgrade` branch. Never drop a column that holds
  /// logged sets.
  static const currentSchema = 3;

  @override
  int get schemaVersion => currentSchema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Every schema bump lands on a device holding real training data, and
      // openConnection() has already taken a copy before we get here. Never
      // drop a column that holds logged sets.
      if (from < 2) {
        await m.createTable(photoShoots);
        await m.createTable(progressPhotos);
        await m.createTable(photoPoses);
        await m.createTable(measurements);
        await m.createTable(formClips);
      }
      // v3: GPS runs and the Fuel plan. New TABLES only — createTable is
      // CREATE TABLE IF NOT EXISTS, and ADD COLUMN has no such guard, so a
      // v1 -> v3 upgrade would otherwise fail on a duplicate column.
      //
      // Until v3 ships, later work in the same release extends THIS branch
      // rather than bumping again: one migration per release.
      if (from < 3) {
        await m.createTable(runs);
        await m.createTable(runPoints);
        await m.createTable(mealLogs);
        await m.createTable(waterLogs);
        await m.createTable(supplementLogs);
        await m.createTable(nutritionAdjustments);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ---------------------------------------------------------------- sessions

  Future<Session?> sessionById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// The session currently in progress, if any. Checked on every launch so a
  /// killed app resumes exactly where it was.
  Future<Session?> inProgressSession() =>
      (select(sessions)
            ..where((s) => s.status.equalsValue(SessionStatus.inProgress))
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<Session?> sessionForDay(String dayId, DateTime plannedDate) {
    final d = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);
    return (select(sessions)
          ..where((s) => s.dayId.equals(dayId) & s.plannedDate.equals(d))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Session>> sessionsBetween(DateTime from, DateTime to) =>
      (select(sessions)
            ..where((s) => s.scheduledDate.isBetweenValues(from, to))
            ..orderBy([(s) => OrderingTerm.asc(s.scheduledDate)]))
          .get();

  Future<List<Session>> completedSessions({int limit = 200}) =>
      (select(sessions)
            ..where((s) => s.status.equalsValue(SessionStatus.completed))
            ..orderBy([(s) => OrderingTerm.desc(s.scheduledDate)])
            ..limit(limit))
          .get();

  // ---------------------------------------------------------------- set logs

  Future<List<SetLog>> setsForSession(int sessionId) =>
      (select(setLogs)
            ..where((l) => l.sessionId.equals(sessionId))
            ..orderBy([
              (l) => OrderingTerm.asc(l.prescriptionId),
              (l) => OrderingTerm.asc(l.setIndex),
            ]))
          .get();

  /// Working sets (never ramp sets) from the most recent session that logged
  /// [prescriptionId] **doing [exerciseId]**.
  ///
  /// This is the primary history lookup. Keying on the prescription — not just
  /// the exercise — is what stops two prescriptions of the same lift in one
  /// week from driving each other's suggestions.
  ///
  /// Matching the exercise as well is what makes an editor swap safe. The slot
  /// keeps its id when you trade Bulgarian split squats for reverse lunges;
  /// without this clause the lunge would be suggested at the split squat's
  /// load, which is how someone training alone gets hurt.
  Future<List<SetLog>> lastSetsForPrescription(
    String prescriptionId,
    String exerciseId,
  ) async {
    final last =
        await (select(setLogs)
              ..where(
                (l) =>
                    l.prescriptionId.equals(prescriptionId) &
                    l.exerciseId.equals(exerciseId) &
                    l.isWarmup.equals(false),
              )
              ..orderBy([(l) => OrderingTerm.desc(l.completedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (last == null) return const [];
    return _setsFromSameSession(
      last,
      (l) =>
          l.prescriptionId.equals(prescriptionId) &
          l.exerciseId.equals(exerciseId),
    );
  }

  /// Fallback history lookup, by exercise. Used when a prescription is new —
  /// after a swap, or when the programme was edited.
  Future<List<SetLog>> lastSetsForExercise(String exerciseId) async {
    final last =
        await (select(setLogs)
              ..where(
                (l) =>
                    l.exerciseId.equals(exerciseId) & l.isWarmup.equals(false),
              )
              ..orderBy([(l) => OrderingTerm.desc(l.completedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (last == null) return const [];
    return _setsFromSameSession(last, (l) => l.exerciseId.equals(exerciseId));
  }

  Future<List<SetLog>> _setsFromSameSession(
    SetLog anchor,
    Expression<bool> Function($SetLogsTable) extra,
  ) =>
      (select(setLogs)
            ..where(
              (l) =>
                  l.sessionId.equals(anchor.sessionId) &
                  l.isWarmup.equals(false) &
                  extra(l),
            )
            ..orderBy([(l) => OrderingTerm.asc(l.setIndex)]))
          .get();

  /// Every logged set for one exercise, newest first. Drives the per-lift
  /// history screen and the e1RM trend.
  Future<List<SetLog>> historyForExercise(
    String exerciseId, {
    int limit = 500,
  }) =>
      (select(setLogs)
            ..where(
              (l) => l.exerciseId.equals(exerciseId) & l.isWarmup.equals(false),
            )
            ..orderBy([(l) => OrderingTerm.desc(l.completedAt)])
            ..limit(limit))
          .get();

  // ----------------------------------------------------------------- stalls

  Future<StallCounter?> stallFor(String exerciseId, String prescriptionId) =>
      (select(stallCounters)..where(
            (s) =>
                s.exerciseId.equals(exerciseId) &
                s.prescriptionId.equals(prescriptionId),
          ))
          .getSingleOrNull();

  Future<void> setStall(String exerciseId, String prescriptionId, int count) =>
      into(stallCounters).insertOnConflictUpdate(
        StallCountersCompanion.insert(
          exerciseId: exerciseId,
          prescriptionId: prescriptionId,
          count: Value(count),
          updatedAt: DateTime.now(),
        ),
      );

  // ------------------------------------------------------------- bodyweight

  Future<List<Bodyweight>> bodyweightHistory({int limit = 400}) =>
      (select(bodyweights)
            ..orderBy([(b) => OrderingTerm.desc(b.measuredOn)])
            ..limit(limit))
          .get();

  Future<void> upsertBodyweight(DateTime on, double kg, {String? note}) {
    final d = DateTime(on.year, on.month, on.day);
    return into(bodyweights).insertOnConflictUpdate(
      BodyweightsCompanion.insert(measuredOn: d, kg: kg, note: Value(note)),
    );
  }

  /// Bodyweight nearest [date] within +/- [withinDays]. Used to caption a
  /// progress photo without making you type the number twice.
  Future<Bodyweight?> bodyweightNear(
    DateTime date, {
    int withinDays = 2,
  }) async {
    final lo = DateTime(date.year, date.month, date.day - withinDays);
    final hi = DateTime(date.year, date.month, date.day + withinDays);
    final rows = await (select(
      bodyweights,
    )..where((b) => b.measuredOn.isBetweenValues(lo, hi))).get();
    if (rows.isEmpty) return null;
    rows.sort(
      (a, b) => (a.measuredOn.difference(date).inHours.abs()).compareTo(
        b.measuredOn.difference(date).inHours.abs(),
      ),
    );
    return rows.first;
  }

  // ------------------------------------------------------------ progress

  Future<List<PhotoPose>> enabledPoses() =>
      (select(photoPoses)
            ..where((p) => p.enabled.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
          .get();

  Future<List<PhotoShoot>> shoots() => (select(
    photoShoots,
  )..orderBy([(s) => OrderingTerm.desc(s.shotOn)])).get();

  Future<List<ProgressPhoto>> photosForShoot(String shootId) =>
      (select(progressPhotos)..where((p) => p.shootId.equals(shootId))).get();

  /// Every photo of one pose, oldest first. This is the flipbook.
  Future<List<ProgressPhoto>> photosForPose(String poseId) =>
      (select(progressPhotos)
            ..where((p) => p.poseId.equals(poseId))
            ..orderBy([(p) => OrderingTerm.asc(p.takenAt)]))
          .get();

  /// The most recent photo of a pose — the ghost the next one aligns against.
  Future<ProgressPhoto?> latestForPose(String poseId) =>
      (select(progressPhotos)
            ..where((p) => p.poseId.equals(poseId))
            ..orderBy([(p) => OrderingTerm.desc(p.takenAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<Measurement>> measurementsFor(MeasurementSite site) =>
      (select(measurements)
            ..where((m) => m.site.equalsValue(site))
            ..orderBy([(m) => OrderingTerm.asc(m.measuredOn)]))
          .get();

  Future<void> upsertMeasurement(
    DateTime on,
    MeasurementSite site,
    double cm, {
    String? note,
  }) {
    final d = DateTime(on.year, on.month, on.day);
    return into(measurements).insert(
      MeasurementsCompanion.insert(
        measuredOn: d,
        site: site,
        cm: cm,
        note: Value(note),
      ),
      onConflict: DoUpdate(
        (_) => MeasurementsCompanion(cm: Value(cm), note: Value(note)),
        target: [measurements.measuredOn, measurements.site],
      ),
    );
  }

  Future<List<FormClip>> clipsForExercise(String exerciseId) =>
      (select(formClips)
            ..where((c) => c.exerciseId.equals(exerciseId))
            ..orderBy([(c) => OrderingTerm.desc(c.recordedAt)]))
          .get();

  /// Bytes held by photos and clips, for the storage budget.
  Future<int> mediaBytes() async {
    final photos = await select(progressPhotos).get();
    final clips = await select(formClips).get();
    return photos.fold<int>(0, (a, p) => a + p.bytes) +
        clips.fold<int>(0, (a, c) => a + c.bytes);
  }

  // ----------------------------------------------------------------- admin

  /// Every table, cleared. Used by restore before importing a backup.
  Future<void> wipe() async {
    await transaction(() async {
      for (final t in allTables) {
        await delete(t).go();
      }
    });
  }
}

/// The schema version recorded inside an SQLite file, without opening it.
///
/// SQLite stores `user_version` as a big-endian 32-bit integer at byte 60 of
/// the file header. Reading it directly means the launch path can decide
/// whether a migration is coming BEFORE handing the file to Drift — and
/// therefore whether it needs to copy it first.
///
/// Returns null when the file is missing, truncated, or not an SQLite file.
int? schemaVersionOf(File file) {
  try {
    if (!file.existsSync()) return null;
    final raf = file.openSync();
    try {
      if (raf.lengthSync() < 64) return null;
      raf.setPositionSync(60);
      final bytes = raf.readSync(4);
      if (bytes.length < 4) return null;
      return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return null;
  }
}

/// Opens the on-device database, taking a backup copy before any migration.
///
/// A Drift migration that goes wrong on a device holding ten weeks of logs is
/// unrecoverable without this.
///
/// The copy is taken ONLY when the file on disk is behind the current schema,
/// so an ordinary launch does not duplicate the whole database every time.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'keller_twelve.sqlite'));

    final onDisk = schemaVersionOf(file);
    final migrationComing =
        onDisk != null && onDisk > 0 && onDisk < AppDatabase.currentSchema;

    if (migrationComing) {
      final backup = File(
        p.join(dir.path, 'keller_twelve.premigration.v$onDisk.sqlite'),
      );
      try {
        await file.copy(backup.path);
      } catch (_) {
        // A failed pre-migration copy must not stop the app opening. The
        // alternative — refusing to launch — loses the session either way.
      }
    }
    return NativeDatabase.createInBackground(file);
  });
}
