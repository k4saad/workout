import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:drift/drift.dart' show Value;
import 'package:keller_twelve/features/editor/cycle_seed_screen.dart';
import 'package:keller_twelve/features/editor/day_editor_screen.dart';
import 'package:keller_twelve/features/editor/programme_editor_screen.dart';

/// The editor, driven the way it will actually be used: standing in a
/// basement on a 400 px phone, one-handed, changing something mid-block.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_editor_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    // Warm the asset-backed reads out here, where real async works. Inside a
    // pumped widget test the bundle channel never resolves, and the screen
    // would sit on a spinner forever.
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadProgramme();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle open for a moment after the last write.
      // A leftover temp directory is not worth failing a test over.
    }
  });

  Widget harness(Widget child) => ProviderScope(
    overrides: [
      programmeRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Lets the real file IO behind the providers finish, then settles frames.
  ///
  /// The editor genuinely reads and writes the programme file, so these tests
  /// need the event loop to run rather than fake-clock pumping.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(child));
    await settle(tester);
    await settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    // A twelve-week programme is taller than any phone; scroll to it first.
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
    await settle(tester);
  }

  Programme onDisk() => Programme.fromJson(
    jsonDecode(File('${tmp.path}/programme.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  testWidgets('the editor lists every block without overflowing', (
    tester,
  ) async {
    await pump(tester, const ProgrammeEditorScreen());

    expect(find.text('Foundation'), findsOneWidget);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('Deload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inheriting block says so and offers a way out', (
    tester,
  ) async {
    await pump(tester, const ProgrammeEditorScreen());

    expect(find.textContaining('Runs the same days as'), findsWidgets);
    expect(find.text('Detach and duplicate'), findsWidgets);
  });

  testWidgets('detaching a block writes it to disk', (tester) async {
    await pump(tester, const ProgrammeEditorScreen());
    final before = onDisk();
    expect(before.blockById('push')!.inheritsDaysFrom, 'build');

    await tapAndSettle(tester, find.text('Detach and duplicate').last);
    await tapAndSettle(tester, find.text('Detach'));

    final after = onDisk();
    expect(after.blockById('push')!.inheritsDaysFrom, isNull);
    expect(after.blockById('push')!.days, isNotEmpty);
    expect(after.revision, before.revision + 1);
  });

  testWidgets('a day opens, showing its movements and warnings', (
    tester,
  ) async {
    await pump(tester, const DayEditorScreen(blockId: 'build', dayId: 'b-mon'));

    expect(find.text('Barbell back squat'), findsWidgets);
    expect(find.textContaining('3 x 6'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a superset is labelled and can be unpaired', (tester) async {
    await pump(tester, const DayEditorScreen(blockId: 'build', dayId: 'b-mon'));

    expect(find.textContaining('rest once at the end'), findsWidgets);

    await tapAndSettle(tester, find.text('Unpair').first);

    final after = onDisk();
    final tue = after
        .blockById('build')!
        .days
        .firstWhere((d) => d.id == 'b-mon');
    final row = tue.allPrescriptions.firstWhere((p) => p.id == 'b-mon-2b');
    expect(row.groupId, isNull);
    expect(row.restSec, greaterThan(0));
  });

  testWidgets('editing sets through the sheet persists', (tester) async {
    await pump(tester, const DayEditorScreen(blockId: 'build', dayId: 'b-mon'));

    await tapAndSettle(tester, find.text('Barbell back squat').first);

    expect(find.text('Sets'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    // One tap on the plus beside "Sets".
    final setsRow = find.ancestor(
      of: find.text('Sets'),
      matching: find.byType(Row),
    );
    await tapAndSettle(
      tester,
      find.descendant(of: setsRow.first, matching: find.byIcon(Icons.add)),
    );

    await tapAndSettle(tester, find.text('Save'));

    final squat = onDisk()
        .blockById('build')!
        .days
        .firstWhere((d) => d.id == 'b-mon')
        .allPrescriptions
        .firstWhere((p) => p.id == 'b-mon-1');
    expect(squat.sets, 4);
  });

  testWidgets('the load stepper can only produce loadable weights', (
    tester,
  ) async {
    await pump(tester, const DayEditorScreen(blockId: 'build', dayId: 'b-mon'));
    await tapAndSettle(tester, find.text('Barbell back squat').first);

    final loadRow = find.ancestor(
      of: find.text('Opening load'),
      matching: find.byType(Row),
    );
    await tapAndSettle(
      tester,
      find.descendant(of: loadRow.first, matching: find.byIcon(Icons.add)),
    );
    await tapAndSettle(tester, find.text('Save'));

    final inventory = await repo.loadInventory();
    final squat = onDisk()
        .blockById('build')!
        .days
        .firstWhere((d) => d.id == 'b-mon')
        .allPrescriptions
        .firstWhere((p) => p.id == 'b-mon-1');

    expect(squat.startLoadKg, isNot(21.0));
    expect(
      Lattice(inventory).isValid(squat.startLoadKg!, squat.loadMode),
      isTrue,
      reason: 'the stepper produced a weight the plates cannot build',
    );
  });

  testWidgets('a broken programme is called out, with the gate named', (
    tester,
  ) async {
    // Write an unloadable weight straight into the file, as a bad import or a
    // hand edit on the PC would.
    final file = File('${tmp.path}/programme.json');
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final build = (raw['blocks'] as List).firstWhere(
      (b) => (b as Map)['id'] == 'build',
    );
    final tue = ((build as Map)['days'] as List).firstWhere(
      (d) => (d as Map)['id'] == 'b-mon',
    );
    final main = (((tue as Map)['sections']) as List).firstWhere(
      (s) => (s as Map)['type'] == 'main',
    );
    ((main as Map)['prescriptions'] as List).first['startLoadKg'] = 20.3;
    file.writeAsStringSync(jsonEncode(raw));
    repo.invalidateProgramme();

    await pump(tester, const ProgrammeEditorScreen());

    expect(find.textContaining('cannot work with'), findsOneWidget);
    expect(find.textContaining('V6'), findsWidgets);
  });

  testWidgets('a day can be added and then removed again', (tester) async {
    await pump(tester, const ProgrammeEditorScreen());
    final before = onDisk().blocks
        .expand((b) => b.days)
        .where((d) => d.id.startsWith('build'))
        .length;

    // Build already owns all seven weekdays, so adding is refused rather
    // than silently producing a second Monday.
    await tapAndSettle(tester, find.text('Add a day').first);
    final after = onDisk().blocks
        .expand((b) => b.days)
        .where((d) => d.id.startsWith('build'))
        .length;
    expect(after, before);
    expect(find.textContaining('already has a day'), findsOneWidget);
  });

  testWidgets('a coach note survives an edit and a reload', (tester) async {
    await pump(tester, const DayEditorScreen(blockId: 'build', dayId: 'b-mon'));
    await tapAndSettle(tester, find.text('Barbell back squat').first);

    await tester.enterText(
      find.widgetWithText(TextField, 'Coach note'),
      'Brace before the unrack.',
    );
    await settle(tester);
    await tapAndSettle(tester, find.text('Save'));

    final squat = onDisk()
        .blockById('build')!
        .days
        .firstWhere((d) => d.id == 'b-mon')
        .allPrescriptions
        .firstWhere((p) => p.id == 'b-mon-1');
    expect(squat.coachNote, 'Brace before the unrack.');
  });

  group('week 13', () {
    Future<void> logTestWeek(String exerciseId, double kg, int reps) async {
      final id = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'test',
              dayId: 't-mon',
              weekNo: 12,
              plannedDate: DateTime(2026, 12, 29),
              scheduledDate: DateTime(2026, 12, 29),
            ),
          );
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: id,
              prescriptionId: 't-mon-1',
              exerciseId: exerciseId,
              setIndex: 1,
              completedAt: DateTime(2026, 12, 29, 19),
            ).copyWith(reps: Value(reps), loadKg: Value(kg)),
          );
    }

    testWidgets('the diff explains every number before anything is applied', (
      tester,
    ) async {
      await logTestWeek('barbell-back-squat', 36, 5);
      await pump(tester, const CycleSeedScreen());

      expect(find.textContaining('Cycle 2'), findsWidgets);
      expect(find.text('Barbell back squat'), findsWidgets);
      expect(find.textContaining('estimated max'), findsWidgets);
      expect(find.text('Start this cycle'), findsOneWidget);

      // Nothing is written until the button is pressed.
      expect(onDisk().blockById('foundation'), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no test week logged it says so rather than pretending', (
      tester,
    ) async {
      await pump(tester, const CycleSeedScreen());
      expect(find.textContaining('No test-week sets logged'), findsOneWidget);
    });

    testWidgets('applying it replaces the programme and keeps the logs', (
      tester,
    ) async {
      await logTestWeek('barbell-back-squat', 36, 5);
      await pump(tester, const CycleSeedScreen());

      await tapAndSettle(tester, find.text('Start this cycle'));
      await tapAndSettle(tester, find.text('Start it'));

      final after = onDisk();
      expect(after.blockById('foundation'), isNull);
      expect(after.totalWeeks, 8);

      final logs = await db.select(db.setLogs).get();
      expect(logs, hasLength(1), reason: 'a new cycle must not erase history');
    });
  });
}
