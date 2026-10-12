import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_editor_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/programme/programme_diff.dart';
import 'package:keller_twelve/domain/programme/programme_editor.dart';

import '../support/fixtures.dart';

void main() {
  const editor = ProgrammeEditor();

  late Directory docs;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late ProgrammeEditorService service;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('keller-editor-');
    // Seed the "user copy" directly so the repository never reaches for the
    // asset bundle, which is not mounted in a pure unit test.
    await File('${docs.path}/programme.json')
        .writeAsString(jsonEncode(Fixtures.programmeJson));
    await File('${docs.path}/inventory.json')
        .writeAsString(jsonEncode(Fixtures.inventoryJson));

    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: docs);
    service = ProgrammeEditorService(
      repository: repo,
      db: db,
      library: Fixtures.library,
      inventory: Fixtures.inventory,
    );
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Prescription find(Programme p, String id) => p.blocks
      .expand((b) => b.days)
      .expand((d) => d.sections)
      .expand((s) => s.prescriptions)
      .firstWhere((pre) => pre.id == id);

  group('saving an edit', () {
    test('writes the user copy and bumps the revision', () async {
      final before = await repo.loadProgramme();
      final edited = editor.updatePrescription(
        before,
        'b-mon-1',
        (p) => p.copyWith(sets: 5),
      );

      final result = await service.save(edited);
      expect(result.isSound, isTrue);
      expect(result.programme.revision, before.revision + 1);

      // And it is on disk, not just in memory.
      final reloaded = await ProgrammeRepository(documentsDir: docs)
          .loadProgramme();
      expect(find(reloaded, 'b-mon-1').sets, 5);
    });

    test('a broken edit is still saved, and reported', () async {
      final before = await repo.loadProgramme();
      final broken = editor.updatePrescription(
        before,
        'b-mon-1',
        (p) => p.copyWith(startLoadKg: 20.3),
      );

      final result = await service.save(broken);
      expect(result.isSound, isFalse);
      expect(result.errors.single.gate, 'V6');

      final reloaded = await ProgrammeRepository(documentsDir: docs)
          .loadProgramme();
      expect(
        find(reloaded, 'b-mon-1').startLoadKg,
        20.3,
        reason:
            'a half-finished edit the app refuses to store is worse than one '
            'it stores and flags',
      );
    });
  });

  group('export and import', () {
    test('a round trip changes nothing', () async {
      final file = File('${docs.path}/out/programme-export.json');
      await service.exportTo(file);
      expect(file.existsSync(), isTrue);

      final preview = await service.inspectImport(file);
      expect(preview.diff.isEmpty, isTrue);
      expect(preview.diff.summary, contains('Identical'));
    });

    test('the diff names what would change', () async {
      final before = await repo.loadProgramme();
      final edited = editor
          .swapExercise(before, 'b-sat-3a', 'reverse-lunge')
          .copyWith(revision: before.revision + 5);

      final file = File('${docs.path}/out/edited.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(edited.toJson()));

      final preview = await service.inspectImport(file);
      final change = preview.diff.changes.firstWhere((c) => c.id == 'b-sat-3a');
      expect(change.kind, ChangeKind.modified);
      expect(change.description, contains('reverse-lunge'));
      expect(preview.canApply, isTrue);
      expect(preview.isRevisionConflict, isFalse);
    });

    test('an older file is flagged as a revision conflict', () async {
      final before = await repo.loadProgramme();
      final older = before.copyWith(revision: before.revision - 1);
      final file = File('${docs.path}/out/older.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(older.toJson()));

      final preview = await service.inspectImport(file);
      expect(preview.isRevisionConflict, isTrue);
    });

    test('a file that would break the runner cannot be applied', () async {
      final before = await repo.loadProgramme();
      final broken = editor
          .updatePrescription(
            before,
            'b-mon-1',
            (p) => p.copyWith(startLoadKg: 20.3),
          )
          .copyWith(revision: before.revision + 1);
      final file = File('${docs.path}/out/broken.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(broken.toJson()));

      final preview = await service.inspectImport(file);
      expect(preview.canApply, isFalse);
      expect(preview.errors.single.gate, 'V6');
    });

    test('nonsense is refused with a readable message', () async {
      final file = File('${docs.path}/out/notes.txt');
      await file.parent.create(recursive: true);
      await file.writeAsString('shopping list');
      expect(
        () => service.inspectImport(file),
        throwsA(isA<FormatException>()),
      );
    });

    test('applying an import keeps the revision moving forward', () async {
      final before = await repo.loadProgramme();
      final incoming = editor
          .updatePrescription(before, 'b-mon-1', (p) => p.copyWith(sets: 6))
          .copyWith(revision: 99);

      final applied = await service.applyImport(incoming);
      expect(applied.revision, 99);
      expect(find(applied, 'b-mon-1').sets, 6);
    });
  });

  group('cycle 2 from what was actually logged', () {
    Future<void> logTestWeek(String exerciseId, double kg, int reps) async {
      final sessionId = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'test',
              dayId: 't-tue',
              weekNo: 12,
              plannedDate: DateTime(2026, 12, 14),
              scheduledDate: DateTime(2026, 12, 14),
            ),
          );
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: sessionId,
              prescriptionId: 't-tue-1',
              exerciseId: exerciseId,
              setIndex: 1,
              completedAt: DateTime(2026, 12, 14, 19),
            ).copyWith(reps: Value(reps), loadKg: Value(kg)),
          );
    }

    test('reads the test block results out of the logs', () async {
      await logTestWeek('barbell-back-squat', 36, 5);
      final results = await service.testWeekResults(await repo.loadProgramme());
      expect(results, hasLength(1));
      expect(results.single.exerciseId, 'barbell-back-squat');
      expect(results.single.e1rmKg, closeTo(42, 0.001));
    });

    test('the best set wins, not the last', () async {
      await logTestWeek('barbell-back-squat', 36, 5);
      await logTestWeek('barbell-back-squat', 30, 5);
      final results = await service.testWeekResults(await repo.loadProgramme());
      expect(results.single.weightKg, 36);
    });

    test('proposing a cycle writes nothing until it is applied', () async {
      await logTestWeek('barbell-back-squat', 36, 5);
      final before = await repo.loadProgramme();

      final seed = await service.proposeNextCycle();
      expect(seed.programme.blockById('foundation'), isNull);

      final stillThere = await ProgrammeRepository(documentsDir: docs)
          .loadProgramme();
      expect(stillThere.blockById('foundation'), isNotNull);
      expect(stillThere.revision, before.revision);
    });

    test('applying it persists the new cycle and keeps the logs', () async {
      await logTestWeek('barbell-back-squat', 36, 5);
      final seed = await service.proposeNextCycle();
      final result = await service.applyNextCycle(seed);

      expect(result.isSound, isTrue);
      final reloaded = await ProgrammeRepository(documentsDir: docs)
          .loadProgramme();
      expect(reloaded.blockById('foundation'), isNull);
      expect(reloaded.totalWeeks, 8);

      final logs = await db.select(db.setLogs).get();
      expect(logs, hasLength(1), reason: 'a new cycle must not erase history');
    });

    test('an untested accessory carries its last logged load', () async {
      final sessionId = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'build',
              dayId: 'b-mon',
              weekNo: 7,
              plannedDate: DateTime(2026, 11, 10),
              scheduledDate: DateTime(2026, 11, 10),
            ),
          );
      for (final (kg, at) in [
        (7.0, DateTime(2026, 11, 10, 19)),
        (9.0, DateTime(2026, 11, 17, 19)),
      ]) {
        await db
            .into(db.setLogs)
            .insert(
              SetLogsCompanion.insert(
                sessionId: sessionId,
                prescriptionId: 'b-mon-2a',
                exerciseId: 'incline-dumbbell-press',
                setIndex: 1,
                completedAt: at,
              ).copyWith(reps: const Value(10), loadKg: Value(kg)),
            );
      }

      final loads = await service.lastLoggedLoads();
      expect(
        loads['incline-dumbbell-press'],
        9.0,
        reason: 'the newest load should win',
      );

      final seed = await service.proposeNextCycle();
      final press = find(seed.programme, 'b-mon-2a');
      expect(press.startLoadKg, 9.0);
    });
  });
}
