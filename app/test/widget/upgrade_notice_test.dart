import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/core/ui/ui.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/today/widgets/upgrade_notice.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final at = DateTime(2026, 9, 24, 7);

  group('describe', () {
    test('an upgrade names the revision, the start date and the backup', () {
      final (tone, title, body) = UpgradeNotice.describe(
        ProgrammeUpgrade(
          at: at,
          programmeFrom: 1,
          programmeTo: 2,
          programmeBackup: 'programme.rev1.x.json',
          programmeWasEdited: true,
          keptStartDate: DateTime(2026, 10, 5),
          inventoryFrom: 1,
          inventoryTo: 2,
          inventoryBackup: 'inventory.rev1.x.json',
        ),
      );
      expect(tone, Tone.info);
      expect(title, 'Programme updated to revision 2');
      expect(body, contains('Monday 5 October'));
      expect(body, contains('programme.rev1.x.json'));
      expect(body, contains('you had edited'));
      expect(body, contains('Every logged set is untouched'));
      expect(body, contains('definitive'));
    });

    test('an unreadable programme is a warning', () {
      final (tone, title, body) = UpgradeNotice.describe(
        ProgrammeUpgrade(
          at: at,
          programmeTo: 2,
          programmeBackup: 'programme.unreadable.x.json',
          programmeUnreadable: true,
        ),
      );
      expect(tone, Tone.warn);
      expect(title, contains('could not be read'));
      expect(body, contains('programme.unreadable.x.json'));
    });

    test('a new kit alone says so', () {
      final (tone, title, body) = UpgradeNotice.describe(
        ProgrammeUpgrade(
          at: at,
          inventoryFrom: 1,
          inventoryTo: 2,
          inventoryBackup: 'inventory.rev1.x.json',
        ),
      );
      expect(tone, Tone.info);
      expect(title, 'Equipment updated');
      expect(body, contains('inventory.rev1.x.json'));
    });
  });

  testWidgets('shows once after an upgrade, and dismissing it sticks', (
    tester,
  ) async {
    // Real file I/O behind the providers: each step of a write resumes in
    // the test's fake zone, so let the event loop run between frames.
    Future<void> settle() async {
      for (var i = 0; i < 24; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    final docs = Directory.systemTemp.createTempSync('kt_notice_');
    addTearDown(() {
      try {
        docs.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows holds the handle a moment longer.
      }
    });
    // A v0.11 phone: an old programme and no record of what was seeded.
    final old = Fixtures.programmeJson..['revision'] = 1;
    File('${docs.path}/programme.json').writeAsStringSync(jsonEncode(old));
    Future<String> disk(String key) => File(key).readAsString();
    final repo = ProgrammeRepository(documentsDir: docs, loadAsset: disk);
    await tester.runAsync(() async {
      await repo.loadProgramme();
      await repo.loadLibrary();
      await repo.loadInventory();
    });
    expect(repo.lastUpgrade, isNotNull);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [programmeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: UpgradeNotice()),
        ),
      ),
    );
    await settle();
    expect(find.textContaining('Programme updated to revision'), findsOne);

    await tester.tap(find.byTooltip('Dismiss'));
    await settle();
    expect(find.textContaining('Programme updated to revision'), findsNothing);

    // A restart does not bring it back.
    final restarted = ProgrammeRepository(documentsDir: docs, loadAsset: disk);
    await tester.runAsync(restarted.ensureSeeded);
    expect(restarted.lastUpgrade, isNull);
  });
}
