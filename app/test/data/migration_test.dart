import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:path/path.dart' as p;

/// Phase 10: rehearse the migration against a database that HAS DATA IN IT.
///
/// An empty database migrates cleanly by definition. The one that matters is
/// the one on the phone in week nine, holding forty sessions and six hundred
/// sets, and the failure mode is silent: the app opens, the tables are there,
/// and the logs are gone.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kt_migration_');
    dbFile = File(p.join(tmp.path, 'keller_twelve.sqlite'));
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle briefly after close.
    }
  });

  /// The tables v3 added, children before parents so the drops succeed.
  const v3Tables = [
    'run_points',
    'runs',
    'meal_logs',
    'water_logs',
    'supplement_logs',
    'nutrition_adjustments',
  ];

  /// Builds a populated database and winds it back to schema v1 — the tables
  /// and version a phone would actually be carrying before the Phase 5 bump.
  Future<void> makeV1Database() async {
    final db = AppDatabase(NativeDatabase(dbFile));
    // Everything added after v1 goes, so a later ADD COLUMN in an upgrade
    // branch would really run rather than hide behind IF NOT EXISTS.
    for (final table in v3Tables) {
      await db.customStatement('DROP TABLE IF EXISTS $table');
    }

    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'build',
            dayId: 'b-mon',
            weekNo: 5,
            plannedDate: DateTime(2026, 11, 2),
            scheduledDate: DateTime(2026, 11, 2),
            status: const Value(SessionStatus.completed),
          ),
        );
    for (var i = 1; i <= 4; i++) {
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: sessionId,
              prescriptionId: 'b-mon-1',
              exerciseId: 'barbell-back-squat',
              setIndex: i,
              completedAt: DateTime(2026, 11, 2, 19, i),
            ).copyWith(reps: const Value(5), loadKg: const Value(21)),
          );
    }
    await db.upsertBodyweight(DateTime(2026, 11, 2), 52.4);
    await db.setStall('barbell-back-squat', 'b-mon-1', 1);

    // Wind back to v1: drop the five tables Phase 5 added and reset the
    // recorded schema version.
    for (final table in [
      'photo_shoots',
      'progress_photos',
      'photo_poses',
      'measurements',
      'form_clips',
    ]) {
      await db.customStatement('DROP TABLE IF EXISTS $table');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  test(
    'the recorded schema version is readable without opening the db',
    () async {
      await makeV1Database();
      expect(schemaVersionOf(dbFile), 1);
      expect(schemaVersionOf(File(p.join(tmp.path, 'nope.sqlite'))), isNull);
    },
  );

  test('a v1 database upgrades without losing a single set', () async {
    await makeV1Database();
    expect(schemaVersionOf(dbFile), 1);

    final db = AppDatabase(NativeDatabase(dbFile));

    // Touching the database is what triggers the migration.
    final sessions = await db.select(db.sessions).get();
    final sets = await db.select(db.setLogs).get();
    final weights = await db.bodyweightHistory();
    final stall = await db.stallFor('barbell-back-squat', 'b-mon-1');

    expect(sessions, hasLength(1));
    expect(sets, hasLength(4));
    expect(sets.every((s) => s.loadKg == 21), isTrue);
    expect(weights.single.kg, 52.4);
    expect(stall!.count, 1);

    await db.close();
    expect(schemaVersionOf(dbFile), AppDatabase.currentSchema);
  });

  test('the tables Phase 5 added come back, and are usable', () async {
    await makeV1Database();
    final db = AppDatabase(NativeDatabase(dbFile));

    await db
        .into(db.photoPoses)
        .insert(
          PhotoPosesCompanion.insert(
            id: 'front-relaxed',
            name: 'Front relaxed',
            orderIndex: 1,
          ),
        );
    await db.upsertMeasurement(
      DateTime(2026, 11, 2),
      MeasurementSite.waist,
      74.5,
    );

    expect(await db.enabledPoses(), hasLength(1));
    expect((await db.measurementsFor(MeasurementSite.waist)).single.cm, 74.5);
    await db.close();
  });

  test('a database already at the current schema is left alone', () async {
    final db = AppDatabase(NativeDatabase(dbFile));
    await db.upsertBodyweight(DateTime(2026, 11, 2), 52.4);
    await db.close();

    expect(schemaVersionOf(dbFile), AppDatabase.currentSchema);

    final again = AppDatabase(NativeDatabase(dbFile));
    expect((await again.bodyweightHistory()).single.kg, 52.4);
    await again.close();
  });

  test(
    'foreign keys are on after the upgrade, so cascades still fire',
    () async {
      await makeV1Database();
      final db = AppDatabase(NativeDatabase(dbFile));

      final session = (await db.select(db.sessions).get()).single;
      await (db.delete(
        db.sessions,
      )..where((s) => s.id.equals(session.id))).go();

      expect(
        await db.select(db.setLogs).get(),
        isEmpty,
        reason: 'deleting a session must take its set logs with it',
      );
      await db.close();
    },
  );

  /// A phone on v0.11 today: schema v2, sessions, sets, photos, a manual run.
  Future<void> makeV2Database() async {
    final db = AppDatabase(NativeDatabase(dbFile));
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'foundation',
            dayId: 'f-mon',
            weekNo: 1,
            plannedDate: DateTime(2026, 9, 28),
            scheduledDate: DateTime(2026, 9, 28),
            status: const Value(SessionStatus.completed),
          ),
        );
    await db
        .into(db.setLogs)
        .insert(
          SetLogsCompanion.insert(
            sessionId: sessionId,
            prescriptionId: 'f-mon-1',
            exerciseId: 'barbell-back-squat',
            setIndex: 1,
            completedAt: DateTime(2026, 9, 28, 19),
          ).copyWith(reps: const Value(8), loadKg: const Value(10)),
        );
    await db
        .into(db.cardioLogs)
        .insert(
          CardioLogsCompanion.insert(
            kind: CardioKind.run,
            measuredOn: DateTime(2026, 9, 29),
            durationSec: const Value(900),
          ),
        );
    await db.upsertMeasurement(
      DateTime(2026, 9, 28),
      MeasurementSite.waist,
      70.0,
    );
    for (final table in v3Tables) {
      await db.customStatement('DROP TABLE IF EXISTS $table');
    }
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();
  }

  group('v2 -> v3 (GPS runs and the Fuel plan)', () {
    test('keeps every row the phone already holds', () async {
      await makeV2Database();
      expect(schemaVersionOf(dbFile), 2);

      final db = AppDatabase(NativeDatabase(dbFile));
      expect(await db.select(db.sessions).get(), hasLength(1));
      expect((await db.select(db.setLogs).get()).single.loadKg, 10);
      expect((await db.select(db.cardioLogs).get()).single.durationSec, 900);
      expect((await db.measurementsFor(MeasurementSite.waist)).single.cm, 70);
      await db.close();
      expect(schemaVersionOf(dbFile), 3);
    });

    test('the new tables exist and take rows', () async {
      await makeV2Database();
      final db = AppDatabase(NativeDatabase(dbFile));

      final runId = await db
          .into(db.runs)
          .insert(
            RunsCompanion.insert(
              runOn: DateTime(2026, 10, 4),
              startedAtMs: DateTime(2026, 10, 4, 9).millisecondsSinceEpoch,
            ),
          );
      await db
          .into(db.runPoints)
          .insert(
            RunPointsCompanion.insert(
              runId: runId,
              seq: 0,
              tMs: DateTime(2026, 10, 4, 9).millisecondsSinceEpoch,
              lat: 51.9607,
              lng: 7.6261,
            ),
          );
      await db
          .into(db.mealLogs)
          .insert(
            MealLogsCompanion.insert(
              loggedOn: DateTime(2026, 10, 4),
              slotId: 'breakfast',
              templateId: 'b1',
              status: MealStatus.eaten,
            ),
          );
      await db
          .into(db.waterLogs)
          .insert(
            WaterLogsCompanion.insert(
              loggedOn: DateTime(2026, 10, 4),
              ml: const Value(750),
            ),
          );
      await db
          .into(db.supplementLogs)
          .insert(
            SupplementLogsCompanion.insert(
              loggedOn: DateTime(2026, 10, 4),
              supplementId: 'creatine',
            ),
          );
      await db
          .into(db.nutritionAdjustments)
          .insert(
            NutritionAdjustmentsCompanion.insert(
              appliedOn: DateTime(2026, 10, 18),
              kcalDelta: 250,
              reason: 'flat two weeks',
            ),
          );

      final run = (await db.select(db.runs).get()).single;
      expect(run.status, RunStatus.recording);
      expect(run.distanceM, 0);
      expect((await db.select(db.runPoints).get()).single.lat, 51.9607);
      expect((await db.select(db.mealLogs).get()).single.portion, 1.0);
      expect((await db.select(db.waterLogs).get()).single.ml, 750);
      expect(await db.select(db.supplementLogs).get(), hasLength(1));
      expect(
        (await db.select(db.nutritionAdjustments).get()).single.kcalDelta,
        250,
      );
      await db.close();
    });

    test(
      'deleting a run takes its points; deleting a session keeps the run',
      () async {
        await makeV2Database();
        final db = AppDatabase(NativeDatabase(dbFile));
        final session = (await db.select(db.sessions).get()).single;

        final runId = await db
            .into(db.runs)
            .insert(
              RunsCompanion.insert(
                sessionId: Value(session.id),
                runOn: DateTime(2026, 9, 29),
                startedAtMs: 0,
              ),
            );
        for (var i = 0; i < 3; i++) {
          await db
              .into(db.runPoints)
              .insert(
                RunPointsCompanion.insert(
                  runId: runId,
                  seq: i,
                  tMs: i * 1000,
                  lat: 51.96,
                  lng: 7.62,
                ),
              );
        }

        // A run outlives the session it was logged against: the trail is the
        // record, the session is only the context.
        await (db.delete(
          db.sessions,
        )..where((s) => s.id.equals(session.id))).go();
        final orphan = (await db.select(db.runs).get()).single;
        expect(orphan.sessionId, isNull);
        expect(await db.select(db.runPoints).get(), hasLength(3));

        await (db.delete(db.runs)..where((r) => r.id.equals(runId))).go();
        expect(
          await db.select(db.runPoints).get(),
          isEmpty,
          reason: 'a deleted run must not leave its trail behind',
        );
        await db.close();
      },
    );
  });
}
