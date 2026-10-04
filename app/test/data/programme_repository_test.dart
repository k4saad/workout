import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:path/path.dart' as p;

import '../support/fixtures.dart';

/// The shipped assets, read straight off disk: what the APK's bundle serves.
Future<String> diskAsset(String key) => File(key).readAsString();

/// A later release: the same files with a revision bumped. A corrected
/// plan, unless [startsFresh]: the shipped v4 file starts fresh, and the
/// rule for every other revision is to keep the athlete's start date.
AssetLoader shippedAt({
  int? programmeRevision,
  int? inventoryRevision,
  bool startsFresh = false,
}) => (key) async {
  final j = jsonDecode(await diskAsset(key)) as Map<String, dynamic>;
  if (key == ProgrammeRepository.assetProgramme && !startsFresh) {
    j.remove('startsFresh');
  }
  if (key == ProgrammeRepository.assetProgramme && programmeRevision != null) {
    j['revision'] = programmeRevision;
  }
  if (key == ProgrammeRepository.assetInventory && inventoryRevision != null) {
    j['revision'] = inventoryRevision;
  }
  return jsonEncode(j);
};

/// The v0.11 kit, verbatim: placeholder bars, no `revision` field.
const legacyInventoryJson =
    '{"bars": [{"id": "barbell", "name": "Standard spinlock barbell", '
    '"weightKg": 9.0, "measured": false}, {"id": "ezBar", "name": "EZ curl '
    'bar", "weightKg": 6.0, "measured": false}, {"id": "dbHandle", "name": '
    '"Dumbbell handle", "weightKg": 2.0, "measured": false}], "plates": '
    '[{"weightKg": 20.0, "count": 2, "bore": "standard"}, {"weightKg": 10.0, '
    '"count": 4, "bore": "standard"}, {"weightKg": 5.0, "count": 8, "bore": '
    '"standard"}, {"weightKg": 2.5, "count": 8, "bore": "standard"}, '
    '{"weightKg": 1.25, "count": 8, "bore": "standard"}, {"weightKg": 0.5, '
    '"count": 8, "bore": "standard"}, {"weightKg": 0.25, "count": 8, "bore": '
    '"standard"}], "fixedDumbbells": [{"weightKg": 2.0, "count": 2}, '
    '{"weightKg": 3.0, "count": 2}], "kettlebells": [{"weightKg": 8.0}], '
    '"collarWeightKg": 0.0, "cable": {"present": true, "maxKg": null, '
    '"incrementKg": null, "note": "Wall-mounted single pulley. Measure the '
    'stack and increment."}, "room": {"ceilingLiftingCm": null, '
    '"ceilingSkippingCm": null, "pullUpClearanceCm": null, "carryLengthM": '
    'null}}';

void main() {
  late Directory docs;
  final now = DateTime(2026, 9, 24, 7, 15, 30);
  const stamp = '20260924-071530';

  final shippedRevision = Fixtures.programmeJson['revision'] as int;
  final shippedInventoryRevision = Fixtures.inventoryJson['revision'] as int;
  final shippedName = Fixtures.programmeJson['name'] as String;

  setUp(() => docs = Directory.systemTemp.createTempSync('kt_repo_'));
  tearDown(() {
    try {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment longer than the test.
    }
  });

  ProgrammeRepository repo({AssetLoader loader = diskAsset}) =>
      ProgrammeRepository(
        documentsDir: docs,
        loadAsset: loader,
        clock: () => now,
      );

  File file(String name) => File(p.join(docs.path, name));
  Map<String, dynamic> json(String name) =>
      jsonDecode(file(name).readAsStringSync()) as Map<String, dynamic>;
  List<String> names() =>
      docs.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
        ..sort();

  /// What a v0.11 phone holds: the revision-1 programme it was seeded with
  /// (start date moved by the athlete), the placeholder kit, and no record of
  /// either — v0.11 never wrote one.
  String installV011({String startDate = '2026-10-05', int revision = 1}) {
    final old = Fixtures.programmeJson
      ..['revision'] = revision
      ..['startDate'] = startDate
      ..['name'] = 'The Keller Twelve (v0.11)';
    final raw = const JsonEncoder.withIndent('  ').convert(old);
    file('programme.json').writeAsStringSync(raw);
    file('inventory.json').writeAsStringSync(legacyInventoryJson);
    return raw;
  }

  group('a fresh install', () {
    test('copies both shipped files and records what it seeded', () async {
      final r = repo();
      final programme = await r.loadProgramme();
      final inventory = await r.loadInventory();

      expect(programme.revision, shippedRevision);
      expect(inventory.revision, shippedInventoryRevision);
      expect(
        file('programme.json').readAsStringSync(),
        await diskAsset(ProgrammeRepository.assetProgramme),
      );
      expect(
        file('inventory.json').readAsStringSync(),
        await diskAsset(ProgrammeRepository.assetInventory),
      );

      final seeded = json('seeded.json');
      expect(seeded['programmeRevision'], shippedRevision);
      expect(seeded['inventoryRevision'], shippedInventoryRevision);
      expect(seeded['programmeHash'], isA<String>());

      expect(r.lastUpgrade, isNull, reason: 'nothing was replaced');
      expect(names(), ['inventory.json', 'programme.json', 'seeded.json']);
    });
  });

  group('a v0.11 install (old copy, no record)', () {
    test(
      'is upgraded to the shipped revision and keeps its start date',
      () async {
        final oldRaw = installV011();

        final programme = await repo(loader: shippedAt()).loadProgramme();

        expect(programme.revision, shippedRevision);
        expect(programme.name, shippedName);
        expect(programme.startDate, DateTime(2026, 10, 5));
        final onDisk = json('programme.json');
        expect(onDisk['startDate'], '2026-10-05');
        expect(onDisk['revision'], shippedRevision);

        final backup = file('programme.rev1.$stamp.json');
        expect(backup.existsSync(), isTrue);
        expect(backup.readAsStringSync(), oldRaw, reason: 'byte for byte');
        expect(json('seeded.json')['programmeRevision'], shippedRevision);
      },
    );

    test('keeps every field the shipped file has, even ones the model '
        'does not know', () async {
      // Programme.toJson drops unknown keys. The upgrade must copy the
      // shipped JSON, not round-trip it through the model.
      installV011();
      await repo().loadProgramme();
      final shipped = jsonDecode(
        await diskAsset(ProgrammeRepository.assetProgramme),
      ) as Map<String, dynamic>;
      final onDisk = json('programme.json');
      expect(onDisk..remove('startDate'), shipped..remove('startDate'));
    });

    test('swaps the placeholder kit for the definitive one', () async {
      installV011();
      final inventory = await repo().loadInventory();

      expect(inventory.revision, shippedInventoryRevision);
      expect(
        inventory.barWeight('barbell'),
        (Fixtures.inventory.barWeight('barbell')),
      );
      expect(inventory.bars.every((b) => b.measured), isTrue);
      final backup = file('inventory.rev1.$stamp.json');
      expect(backup.readAsStringSync(), legacyInventoryJson);
      expect(
        json('seeded.json')['inventoryRevision'],
        shippedInventoryRevision,
      );
    });

    test('raises a notice that says where the old copies are', () async {
      installV011();
      final r = repo(loader: shippedAt());
      await r.loadProgramme();

      final up = r.lastUpgrade!;
      expect(up.programmeFrom, 1);
      expect(up.programmeTo, shippedRevision);
      expect(up.programmeBackup, 'programme.rev1.$stamp.json');
      expect(up.programmeUnreadable, isFalse);
      expect(up.inventoryFrom, 1);
      expect(up.inventoryTo, shippedInventoryRevision);
      expect(up.inventoryBackup, 'inventory.rev1.$stamp.json');
      expect(up.keptStartDate, DateTime(2026, 10, 5));
      expect(up.at, now);
    });

    test('the notice survives a restart until it is dismissed', () async {
      installV011();
      await repo().loadProgramme();

      final restarted = repo();
      await restarted.ensureSeeded();
      expect(restarted.lastUpgrade, isNotNull);

      await restarted.dismissUpgradeNotice();
      expect(restarted.lastUpgrade, isNull);

      final again = repo();
      await again.ensureSeeded();
      expect(again.lastUpgrade, isNull);
    });

    test('a copy saved in the editor is flagged as edited', () async {
      // v0.11 shipped revision 1 and every save bumps it, so a v0.11 copy at
      // revision 4 has been saved three times.
      installV011(revision: 4);
      final r = repo();
      await r.loadProgramme();
      expect(r.lastUpgrade!.programmeWasEdited, isTrue);
      expect(file('programme.rev1.$stamp.json').existsSync(), isTrue);
    });

    test('a copy never saved is not flagged as edited', () async {
      installV011();
      final r = repo();
      await r.loadProgramme();
      expect(r.lastUpgrade!.programmeWasEdited, isFalse);
    });

    test('the second launch changes nothing', () async {
      installV011();
      await repo().loadProgramme();
      final after = names();
      final raw = file('programme.json').readAsStringSync();

      final second = repo();
      await second.loadProgramme();
      await second.loadInventory();

      expect(names(), after, reason: 'no second backup');
      expect(file('programme.json').readAsStringSync(), raw);
    });
  });

  group('an install already at the shipped revision', () {
    test('is left exactly as it is, edits and all', () async {
      final first = repo();
      final shipped = await first.loadProgramme();
      await first.saveProgramme(
        shipped.copyWith(startDate: DateTime(2026, 10, 12)),
      );
      final raw = file('programme.json').readAsStringSync();

      final r = repo();
      final programme = await r.loadProgramme();

      expect(file('programme.json').readAsStringSync(), raw);
      expect(programme.startDate, DateTime(2026, 10, 12));
      expect(programme.revision, shippedRevision + 1, reason: 'the save');
      expect(r.lastUpgrade, isNull);
      expect(names(), ['inventory.json', 'programme.json', 'seeded.json']);
      expect(await r.isModified, isTrue);
    });

    test('an edited kit is left alone too', () async {
      final first = repo();
      final inv = await first.loadInventory();
      await first.saveInventory(
        inv.copyWith(
          plates: [
            for (final pl in inv.plates)
              pl.weightKg == 20 ? pl.copyWith(count: 4) : pl,
          ],
        ),
      );

      final reloaded = await repo().loadInventory();
      expect(reloaded.plates.firstWhere((pl) => pl.weightKg == 20).count, 4);
      expect(reloaded.revision, shippedInventoryRevision);
    });
  });

  group('a later release', () {
    test(
      'replaces an edited copy, keeps its start date, and says so',
      () async {
        final first = repo();
        final shipped = await first.loadProgramme();
        await first.saveProgramme(
          shipped.copyWith(startDate: DateTime(2026, 10, 12)),
        );
        final editedRaw = file('programme.json').readAsStringSync();

        final r = repo(
          loader: shippedAt(programmeRevision: shippedRevision + 1),
        );
        final programme = await r.loadProgramme();

        expect(programme.revision, shippedRevision + 1);
        expect(programme.startDate, DateTime(2026, 10, 12));
        final up = r.lastUpgrade!;
        expect(up.programmeFrom, shippedRevision);
        expect(up.programmeTo, shippedRevision + 1);
        expect(up.programmeWasEdited, isTrue);
        expect(up.inventoryBackup, isNull, reason: 'the kit did not change');
        expect(
          file('programme.rev$shippedRevision.$stamp.json').readAsStringSync(),
          editedRaw,
        );
      },
    );

    test('an untouched copy is replaced and not flagged as edited', () async {
      await repo().loadProgramme();
      final r = repo(loader: shippedAt(programmeRevision: shippedRevision + 1));
      await r.loadProgramme();
      expect(r.lastUpgrade!.programmeWasEdited, isFalse);
    });

    test('never replaces a programme of the athlete\'s own', () async {
      // The next-cycle seeder writes a programme with a new id. It descends
      // from the shipped one but it is not a copy of it.
      await repo().loadProgramme();
      final own = json('programme.json')..['id'] = 'keller-twelve-c2';
      file('programme.json').writeAsStringSync(jsonEncode(own));
      final raw = file('programme.json').readAsStringSync();

      final r = repo(loader: shippedAt(programmeRevision: shippedRevision + 1));
      final programme = await r.loadProgramme();

      expect(programme.id, 'keller-twelve-c2');
      expect(file('programme.json').readAsStringSync(), raw);
      expect(r.lastUpgrade, isNull);
    });

    test('a new kit alone replaces only the kit', () async {
      await repo().loadProgramme();
      final programmeRaw = file('programme.json').readAsStringSync();

      final r = repo(
        loader: shippedAt(inventoryRevision: shippedInventoryRevision + 1),
      );
      final inventory = await r.loadInventory();

      expect(inventory.revision, shippedInventoryRevision + 1);
      expect(file('programme.json').readAsStringSync(), programmeRaw);
      final up = r.lastUpgrade!;
      expect(up.programmeBackup, isNull);
      expect(
        up.inventoryBackup,
        'inventory.rev$shippedInventoryRevision.$stamp.json',
      );
    });
  });

  group('damaged files never stop the app opening', () {
    test(
      'a corrupt programme falls back to the shipped one, and is kept',
      () async {
        const corrupt = '{"id": "keller-twelve", "blo';
        file('programme.json').writeAsStringSync(corrupt);

        final r = repo();
        final programme = await r.loadProgramme();

        expect(programme.revision, shippedRevision);
        expect(
          file('programme.json').readAsStringSync(),
          await diskAsset(ProgrammeRepository.assetProgramme),
        );
        expect(
          file('programme.unreadable.$stamp.json').readAsStringSync(),
          corrupt,
        );
        expect(r.lastUpgrade!.programmeUnreadable, isTrue);
      },
    );

    test('JSON that is not a programme counts as corrupt', () async {
      file('programme.json').writeAsStringSync('{"hello": 1}');
      final programme = await repo().loadProgramme();
      expect(programme.revision, shippedRevision);
      expect(file('programme.unreadable.$stamp.json').existsSync(), isTrue);
    });

    test('a corrupt kit falls back to the shipped kit', () async {
      await repo().loadProgramme();
      file('inventory.json').writeAsStringSync('[1, 2');

      final r = repo();
      final inventory = await r.loadInventory();

      expect(inventory.revision, shippedInventoryRevision);
      expect(
        file('inventory.unreadable.$stamp.json').readAsStringSync(),
        '[1, 2',
      );
      expect(r.lastUpgrade!.inventoryUnreadable, isTrue);
    });

    test('a corrupt record is read as "seeded from revision 1"', () async {
      installV011();
      file('seeded.json').writeAsStringSync('not json');

      final programme = await repo(loader: shippedAt()).loadProgramme();

      expect(programme.revision, shippedRevision);
      expect(programme.startDate, DateTime(2026, 10, 5));
    });

    test('an unreadable asset bundle still opens the phone\'s copy', () async {
      installV011();
      final r = repo(loader: (_) async => throw const FileSystemException('x'));

      final programme = await r.loadProgramme();

      expect(programme.name, 'The Keller Twelve (v0.11)');
      expect(r.lastUpgrade, isNull);
    });
  });

  group('a new plan (startsFresh, v4)', () {
    test('the shipped v4 file is a new plan starting 12 October', () async {
      final shipped = jsonDecode(
        await diskAsset(ProgrammeRepository.assetProgramme),
      ) as Map<String, dynamic>;
      expect(shipped['startsFresh'], isTrue);
      expect(shipped['startDate'], '2026-10-12');
    });

    test('takes its own start date over the old one, and says so', () async {
      final oldRaw = installV011(startDate: '2026-09-28', revision: 2);

      final r = repo();
      final programme = await r.loadProgramme();

      expect(programme.revision, shippedRevision);
      expect(programme.startDate, DateTime(2026, 10, 12));
      expect(json('programme.json')['startDate'], '2026-10-12');
      final up = r.lastUpgrade!;
      expect(up.newStartDate, DateTime(2026, 10, 12));
      expect(up.keptStartDate, isNull);
      // The old plan, with its old date, is kept beside it.
      expect(file(up.programmeBackup!).readAsStringSync(), oldRaw);
    });

    test('the notice survives a restart', () async {
      installV011(startDate: '2026-09-28', revision: 2);
      await repo().loadProgramme();
      final again = repo();
      await again.loadProgramme();
      expect(again.lastUpgrade?.newStartDate, DateTime(2026, 10, 12));
    });

    test('a later corrected revision keeps the date again', () async {
      final first = repo();
      final shipped = await first.loadProgramme();
      await first.saveProgramme(
        shipped.copyWith(startDate: DateTime(2026, 10, 19)),
      );
      final programme = await repo(
        loader: shippedAt(programmeRevision: shippedRevision + 1),
      ).loadProgramme();
      expect(programme.startDate, DateTime(2026, 10, 19));
    });
  });

  group('reset', () {
    test('re-copies the shipped programme and clears "modified"', () async {
      final r = repo();
      final shipped = await r.loadProgramme();
      await r.saveProgramme(
        shipped.copyWith(startDate: DateTime(2026, 10, 12)),
      );
      expect(await r.isModified, isTrue);

      final reset = await r.resetToShipped();

      expect(reset.startDate, shipped.startDate);
      expect(await r.isModified, isFalse);
    });
  });
}
