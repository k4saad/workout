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

  /// Builds a populated database and winds it back to schema v1 — the tables
  /// and version a phone would actually be carrying before the Phase 5 bump.
  Future<void> makeV1Database() async {
    final db = AppDatabase(NativeDatabase(dbFile));

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
}
