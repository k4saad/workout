import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/backup_service.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/media_repository.dart';
import 'package:keller_twelve/data/session_service.dart';
import 'package:path/path.dart' as p;

/// The update that will actually happen: the phone holds a database written
/// by v0.11.0+11, and v0.12 opens it.
///
/// `test/fixtures/v0.11.0+11.sqlite` was made by the v0.11 code itself — a
/// checkout of that build, logging two weeks through its own services — not
/// by SQL typed to look like it. Its contents are invented; the schema, the
/// encodings and the row shapes are that build's.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kt_v011_');
    File('test/fixtures/v0.11.0+11.sqlite')
        .copySync(p.join(dir.path, 'keller_twelve.sqlite'));
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  File live() => File(p.join(dir.path, 'keller_twelve.sqlite'));
  File copyOf(int v) =>
      File(p.join(dir.path, 'keller_twelve.premigration.v$v.sqlite'));

  test(
    'the phone’s database is v2, and a copy is taken before anything',
    () async {
      expect(schemaVersionOf(live()), 2);
      final before = live().readAsBytesSync();

      final file = await prepareDatabaseFile(dir);
      expect(file.path, live().path);
      expect(copyOf(2).existsSync(), isTrue);
      expect(copyOf(2).readAsBytesSync(), before, reason: 'byte for byte');
    },
  );

  test('every row survives the upgrade', () async {
    final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
    addTearDown(db.close);

    final sessions = await db.select(db.sessions).get();
    final sets = await db.select(db.setLogs).get();
    expect(sets, hasLength(110), reason: 'every set v0.11 logged');
    expect(
      {for (final s in sessions) s.status},
      containsAll([
        SessionStatus.completed,
        SessionStatus.partial,
        SessionStatus.skipped,
        SessionStatus.inProgress,
      ]),
    );
    expect(
      sessions.where((s) => s.scheduledDate != s.plannedDate),
      hasLength(1),
      reason: 'the moved session is still moved',
    );
    expect(await db.select(db.bodyweights).get(), hasLength(16));
    expect(await db.select(db.measurements).get(), hasLength(5));
    expect(await db.select(db.cardioLogs).get(), hasLength(1));
    expect(await db.select(db.foodLogs).get(), hasLength(2));
    expect(await db.select(db.niggles).get(), hasLength(1));
    expect(await db.select(db.stallCounters).get(), hasLength(1));
    expect(await db.select(db.photoShoots).get(), hasLength(1));
    expect(await db.select(db.progressPhotos).get(), hasLength(4));
  });

  test('after the upgrade it is v3, and the v3 tables take rows', () async {
    final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            runOn: DateTime(2026, 10, 18),
            startedAtMs: DateTime(2026, 10, 18, 9).millisecondsSinceEpoch,
          ),
        );
    expect(await db.select(db.runs).get(), hasLength(1));
    expect(await db.select(db.mealLogs).get(), isEmpty);
    await db.close();
    expect(schemaVersionOf(live()), 3);
  });

  test('the session the app died during can still be resumed', () async {
    final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
    addTearDown(db.close);
    final open = await SessionService(db).resumable();
    expect(open, isNotNull);
    expect(open!.status, SessionStatus.inProgress);
    expect(await db.setsForSession(open.id), isNotEmpty);
  });

  test(
    'v0.11’s photo rows are kept: a shoot with photos is not tidied',
    () async {
      final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
      addTearDown(db.close);
      final media = MediaRepository(db: db, documentsDir: dir);
      expect(await media.tidyEmptyShoots(), 0);
      expect(await db.select(db.progressPhotos).get(), hasLength(4));
    },
  );

  test('a second launch takes no second copy of the upgraded file', () async {
    final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
    await db.select(db.sessions).get();
    await db.close();
    final copy = copyOf(2).readAsBytesSync();

    await prepareDatabaseFile(dir);
    expect(copyOf(3).existsSync(), isFalse);
    expect(copyOf(2).readAsBytesSync(), copy, reason: 'the v2 copy untouched');
  });

  test('the upgraded database backs up and restores whole', () async {
    final db = AppDatabase(NativeDatabase(await prepareDatabaseFile(dir)));
    final docs = Directory(p.join(dir.path, 'docs'))..createSync();
    final zip = File(p.join(dir.path, 'backup.zip'));
    await BackupService(
      db: db,
      appVersion: '0.12.0+12',
      documentsDir: docs,
    ).export(zip);
    final sets = (await db.select(db.setLogs).get()).length;
    await db.close();

    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    final manifest = await BackupService(
      db: fresh,
      appVersion: '0.12.0+12',
      documentsDir: Directory(p.join(dir.path, 'restored'))..createSync(),
    ).restore(zip);
    expect(manifest.schemaVersion, 3);
    expect(await fresh.select(fresh.setLogs).get(), hasLength(sets));
    expect(await fresh.select(fresh.sessions).get(), isNotEmpty);
  });
}
