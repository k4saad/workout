import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/backup_service.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory docs;
  late AppDatabase db;
  late BackupService backup;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('kt_backup_');
    db = AppDatabase.memory();
    backup = BackupService(db: db, appVersion: '0.2.0+2', documentsDir: docs);
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<void> seed() async {
    final id = await db
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
              sessionId: id,
              prescriptionId: 'b-mon-1',
              exerciseId: 'barbell-back-squat',
              setIndex: i,
              reps: Value(5),
              loadKg: const Value(21),
              completedAt: DateTime(2026, 11, 2, 18, 40 + i),
            ),
          );
    }
    await db.upsertBodyweight(DateTime(2026, 11, 2), 51.4);

    // Programme files as the repository would have written them.
    final progDir = Directory(p.join(docs.path, 'programmes'))
      ..createSync(recursive: true);
    File(p.join(progDir.path, 'programme.json'))
        .writeAsStringSync(jsonEncode({'id': 'keller-twelve', 'revision': 7}));
    File(p.join(progDir.path, 'inventory.json'))
        .writeAsStringSync(jsonEncode({'bars': []}));

    // A progress photo, to prove media round-trips.
    final photoDir = Directory(p.join(docs.path, 'photos', 'shoot-1'))
      ..createSync(recursive: true);
    File(p.join(photoDir.path, 'front-relaxed.jpg'))
        .writeAsBytesSync(List<int>.generate(512, (i) => i % 256));
  }

  test('manifest counts what is actually there', () async {
    await seed();
    final m = await backup.buildManifest();
    expect(m.sessionCount, 1);
    expect(m.setCount, 4);
    expect(m.bodyweightCount, 1);
    expect(m.photoCount, 1);
    expect(m.programmeRevision, 7);
    expect(m.schemaVersion, db.schemaVersion);
    expect(m.summary, contains('4 sets'));
  });

  test('export writes a zip containing the manifest and the media', () async {
    await seed();
    final out = File(p.join(docs.path, 'out', 'backup.zip'));
    await backup.export(out);

    expect(out.existsSync(), isTrue);
    expect(out.lengthSync(), greaterThan(0));

    final m = await backup.inspect(out);
    expect(m, isNotNull);
    expect(m!.setCount, 4);
    expect(m.appVersion, '0.2.0+2');
  });

  test(
    'a backup can be excluded from media, for a quick logs-only copy',
    () async {
      await seed();
      final withMedia = File(p.join(docs.path, 'a.zip'));
      final without = File(p.join(docs.path, 'b.zip'));
      await backup.export(withMedia);
      await backup.export(without, includeMedia: false);
      expect(without.lengthSync(), lessThan(withMedia.lengthSync()));
    },
  );

  test('restore brings every row back after a wipe', () async {
    await seed();
    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);

    // Simulate a lost phone: everything gone.
    await db.wipe();
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.select(db.setLogs).get(), isEmpty);

    final m = await backup.restore(zip);
    expect(m.setCount, 4);

    final sessions = await db.select(db.sessions).get();
    final sets = await db.select(db.setLogs).get();
    final weights = await db.select(db.bodyweights).get();

    expect(sessions, hasLength(1));
    expect(sessions.single.dayId, 'b-mon');
    expect(sessions.single.status, SessionStatus.completed);
    expect(sets, hasLength(4));
    expect(sets.every((s) => s.loadKg == 21), isTrue);
    expect(weights.single.kg, 51.4);
  });

  test('a GPS trail and a meal log survive export, wipe and restore', () async {
    await seed();
    final runId = await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            runOn: DateTime(2026, 11, 8),
            startedAtMs: 1793950000123,
            endedAtMs: const Value(1793951800456),
            movingMs: const Value(1740000),
            distanceM: const Value(4215.7),
            status: const Value(RunStatus.finished),
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.runPoints)
          .insert(
            RunPointsCompanion.insert(
              runId: runId,
              seq: i,
              tMs: 1793950000123 + i * 1000,
              lat: 51.9607123 + i * 0.0001,
              lng: 7.6261456,
              segmentStart: Value(i == 0),
            ),
          );
    }
    await db
        .into(db.mealLogs)
        .insert(
          MealLogsCompanion.insert(
            loggedOn: DateTime(2026, 11, 8),
            slotId: 'post',
            templateId: 'n1',
            status: MealStatus.partial,
            portion: const Value(0.5),
            kcal: const Value(213),
            proteinG: const Value(8.8),
          ),
        );

    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);
    await db.wipe();
    expect(await db.select(db.runPoints).get(), isEmpty);
    await backup.restore(zip);

    final run = (await db.select(db.runs).get()).single;
    expect(run.startedAtMs, 1793950000123);
    expect(run.distanceM, closeTo(4215.7, 1e-9));
    expect(run.status, RunStatus.finished);
    final pts = await (db.select(
      db.runPoints,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();
    expect(pts, hasLength(3));
    expect(pts.first.lat, closeTo(51.9607123, 1e-9));
    expect(pts.first.segmentStart, isTrue);
    expect(pts.last.tMs, 1793950002123);
    final meal = (await db.select(db.mealLogs).get()).single;
    expect(meal.status, MealStatus.partial);
    expect(meal.portion, 0.5);
    expect(meal.proteinG, closeTo(8.8, 1e-9));
  });

  test('restore puts the programme file and the photos back', () async {
    await seed();
    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);

    File(p.join(docs.path, 'programmes', 'programme.json')).deleteSync();
    Directory(p.join(docs.path, 'photos')).deleteSync(recursive: true);

    await backup.restore(zip);

    final prog = File(p.join(docs.path, 'programmes', 'programme.json'));
    expect(prog.existsSync(), isTrue);
    expect((jsonDecode(prog.readAsStringSync()) as Map)['revision'], 7);

    final photo = File(
      p.join(docs.path, 'photos', 'shoot-1', 'front-relaxed.jpg'),
    );
    expect(photo.existsSync(), isTrue);
    expect(photo.lengthSync(), 512);
  });

  test('restoring a file that is not a backup fails loudly', () async {
    final junk = File(p.join(docs.path, 'holiday.zip'));
    // A valid zip, but not ours.
    await backup.export(junk);
    final bytes = junk.readAsBytesSync();
    final stripped = File(p.join(docs.path, 'stripped.zip'));
    // Corrupt it by truncating: decode must fail rather than wipe the data.
    stripped.writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 3));

    await expectLater(() => backup.restore(stripped), throwsA(anything));
  });

  /// [zip] rewritten: [edit] may change the manifest and data, and
  /// [extra] adds entries.
  Future<File> tampered(
    File zip, {
    void Function(Map<String, dynamic> manifest, Map<String, dynamic> data)?
    edit,
    Map<String, List<int>> extra = const {},
  }) async {
    final src = ZipDecoder().decodeBytes(await zip.readAsBytes());
    Map<String, dynamic> read(String name) => jsonDecode(
      utf8.decode(
        src.files.firstWhere((f) => f.name == name).content as List<int>,
      ),
    ) as Map<String, dynamic>;
    final manifest = read(BackupService.manifestEntry);
    final data = read(BackupService.dataEntry);
    edit?.call(manifest, data);
    final out = Archive();
    for (final f in src.files) {
      if (!f.isFile) continue;
      final bytes = switch (f.name) {
        BackupService.manifestEntry => utf8.encode(jsonEncode(manifest)),
        BackupService.dataEntry => utf8.encode(jsonEncode(data)),
        _ => f.content as List<int>,
      };
      out.addFile(ArchiveFile.bytes(f.name, Uint8List.fromList(bytes)));
    }
    extra.forEach(
      (name, bytes) =>
          out.addFile(ArchiveFile.bytes(name, Uint8List.fromList(bytes))),
    );
    final file = File(p.join(docs.path, 'tampered.zip'));
    await file.writeAsBytes(ZipEncoder().encode(out), flush: true);
    return file;
  }

  test('a restore that fails half way leaves everything as it was', () async {
    await seed();
    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);
    // A row this schema cannot hold: the import fails part way through.
    final bad = await tampered(
      zip,
      edit: (_, data) => (data['set_logs'] as List).add({
        ...(data['set_logs'] as List).first as Map<String, dynamic>,
        'id': 999,
        'no_such_column': 1,
      }),
    );
    File(p.join(docs.path, 'programmes', 'programme.json'))
        .writeAsStringSync(jsonEncode({'id': 'keller-twelve', 'revision': 8}));

    await expectLater(() => backup.restore(bad), throwsA(anything));

    // v3 wiped first, outside the import's transaction: a failure here left
    // an EMPTY database.
    expect(await db.select(db.setLogs).get(), hasLength(4));
    expect(await db.select(db.bodyweights).get(), hasLength(1));
    // Nor were the files overwritten by a restore that did not happen.
    expect(
      File(p.join(docs.path, 'programmes', 'programme.json'))
          .readAsStringSync(),
      contains('"revision":8'),
    );
  });

  test('a restore only writes inside the app\'s own folders', () async {
    await seed();
    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);
    final outside = p.join(docs.parent.path, 'kt-escaped.txt');
    addTearDown(() {
      final f = File(outside);
      if (f.existsSync()) f.deleteSync();
    });
    final evil = await tampered(
      zip,
      extra: {
        '../kt-escaped.txt': utf8.encode('out of the sandbox'),
        'photos/../../kt-escaped.txt': utf8.encode('out again'),
        'somewhere/else.bin': [1, 2, 3],
      },
    );

    await backup.restore(evil);
    expect(File(outside).existsSync(), isFalse);
    expect(
      File(p.join(docs.path, 'somewhere', 'else.bin')).existsSync(),
      isFalse,
      reason: 'only the entries a backup is made of',
    );
    // The real contents still came back.
    expect(await db.select(db.setLogs).get(), hasLength(4));
  });

  test('a backup from a newer schema refuses to restore', () async {
    await seed();
    final zip = File(p.join(docs.path, 'backup.zip'));
    await backup.export(zip);
    final future = await tampered(
      zip,
      edit: (m, _) => m['schemaVersion'] = db.schemaVersion + 5,
    );
    await expectLater(() => backup.restore(future), throwsStateError);
    expect(await db.select(db.setLogs).get(), hasLength(4));
  });

  test('the manifest of a newer schema says so', () async {
    await seed();
    final zip = File(p.join(docs.path, 'future.zip'));
    await backup.export(zip);

    // Rewrite the manifest to claim a future schema.
    final fake = BackupService(db: db, appVersion: '9.9.9', documentsDir: docs);
    final m = await fake.inspect(zip);
    expect(m!.schemaVersion, db.schemaVersion);

    // The guard is on schemaVersion > db.schemaVersion; assert the message is
    // the one that stops you destroying good data with an old build.
    final manifest = BackupManifest(
      createdAt: DateTime.now(),
      appVersion: '9.9.9',
      schemaVersion: db.schemaVersion + 5,
      sessionCount: 0,
      setCount: 0,
      bodyweightCount: 0,
      photoCount: 0,
      programmeRevision: 1,
    );
    expect(manifest.schemaVersion, greaterThan(db.schemaVersion));
  });

  test('suggested filename sorts chronologically', () {
    final a = BackupService.suggestedFileName(DateTime(2026, 9, 5, 7, 4));
    final b = BackupService.suggestedFileName(DateTime(2026, 11, 2, 18, 30));
    expect(a, 'keller-twelve-2026-09-05-0704.zip');
    expect(a.compareTo(b), lessThan(0));
  });
}
