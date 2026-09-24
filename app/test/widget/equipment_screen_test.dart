import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/plates/kit_summary.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/plates/plate_solver.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/settings/calibration_screen.dart';

/// "Your equipment" against the REAL shipped kit and programme: every number
/// on it must come from inventory.json and keller-twelve.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeRepository repo;
  late ProgrammeBundle bundle;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_equipment_');
    repo = ProgrammeRepository(documentsDir: tmp);
    final programme = await repo.loadProgramme();
    final library = await repo.loadLibrary();
    final inventory = await repo.loadInventory();
    bundle = (
      programme: programme,
      library: library,
      inventory: inventory,
      calendar: ProgrammeCalendar(programme),
      resolver: BlockResolver(programme),
      lattice: Lattice(inventory),
    );
  });

  tearDownAll(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  Future<void> pump(WidgetTester tester) async {
    // Tall: the ListView builds lazily and the targets sit far down.
    tester.view.physicalSize = const Size(412, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundleProvider.overrideWith((ref) => bundle),
          programmeRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const CalibrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  /// Every string on screen, Text and RichText alike.
  List<String> allText(WidgetTester tester) => [
    for (final w in tester.widgetList<RichText>(find.byType(RichText)))
      w.text.toPlainText(),
  ];

  testWidgets('is called Your equipment and draws without throwing', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Your equipment'), findsOneWidget);
    expect(find.text('Every whole kilogram, on every bar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists every bar and plate from the inventory', (tester) async {
    await pump(tester);
    for (final bar in bundle.inventory.bars) {
      expect(find.text(bar.name), findsOneWidget);
    }
    expect(find.text('collars included'), findsNWidgets(3));
    for (final plate in bundle.inventory.plates) {
      final tile = find.byKey(ValueKey('plate-${plate.weightKg}'));
      expect(tile, findsOneWidget, reason: '${plate.weightKg} kg');
      expect(
        find.descendant(of: tile, matching: find.text(fmt(plate.weightKg))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text('× ${plate.count}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('names the small plates that make every whole kilogram', (
    tester,
  ) async {
    await pump(tester);
    final small = KitSummary.wholeKgPlates(bundle.inventory);
    expect(small.map((p) => p.weightKg), [1.0, 0.5]);
    final note = allText(tester).singleWhere(
      (s) => s.contains('small plates that make every whole kilogram'),
    );
    for (final p in small) {
      expect(note, contains('${fmt(p.weightKg)} kg × ${p.count}'));
    }
    expect(note, contains('1.25 kg'), reason: 'the smallest plate without');
  });

  testWidgets('summarises what each implement reaches', (tester) async {
    await pump(tester);
    for (final mode in KitSummary.implements) {
      final r = KitSummary.reach(bundle.inventory, mode);
      final row = find.byKey(ValueKey('reach-${mode.name}'));
      expect(row, findsOneWidget, reason: mode.name);
      expect(
        find.descendant(
          of: row,
          matching: find.text('${fmt(r.baseKg)}–${fmt(r.maxKg)}'),
        ),
        findsOneWidget,
        reason: mode.name,
      );
    }
  });

  testWidgets('shows the plates for every week-12 target in the programme', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('LOADING YOUR WEEK-12 TARGETS'), findsOneWidget);
    final solver = PlateSolver(bundle.inventory);
    var shown = 0;
    for (final t in bundle.programme.strengthTargets) {
      final ex = bundle.library[t.exerciseId];
      if (t.week12Kg == null || ex == null) continue;
      if (!ex.defaultLoadMode.isPlateLoaded) continue;
      final kg = t.week12Kg!.last;
      final s = solver.solve(kg, ex.defaultLoadMode);
      final row = find.byKey(ValueKey('target-${t.exerciseId}'));
      expect(row, findsOneWidget, reason: t.exerciseId);
      expect(
        find.descendant(of: row, matching: find.text(ex.name)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(fmt(kg))),
        findsOneWidget,
      );
      final perSide = s.perSide.map((p) => p.toString()).join(' + ');
      final text = tester
          .widgetList<RichText>(
            find.descendant(of: row, matching: find.byType(RichText)),
          )
          .map((w) => w.text.toPlainText())
          .join('|');
      expect(text, contains(perSide), reason: t.exerciseId);
      shown++;
    }
    expect(shown, greaterThanOrEqualTo(5), reason: 'the barbell targets');
  });

  testWidgets('never says placeholder, estimate, bathroom scale or weigh', (
    tester,
  ) async {
    await pump(tester);
    final banned = RegExp(
      r'placeholder|estimate|bathroom|\bweigh(ed|ing|s)?\b|calibrat',
      caseSensitive: false,
    );
    for (final s in allText(tester)) {
      expect(banned.hasMatch(s), isFalse, reason: s);
    }
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    for (final s in allText(tester)) {
      expect(banned.hasMatch(s), isFalse, reason: 'editing: $s');
    }
  });

  testWidgets('steppers edit a plate count, and Save writes it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('plate-20.0-plus')), findsNothing);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final twenty = bundle.inventory.plates.firstWhere((p) => p.weightKg == 20);
    await tester.tap(find.byKey(const ValueKey('plate-20.0-plus')));
    await tester.pumpAndSettle();
    expect(find.text('${twenty.count + 1}'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    // The save is real file I/O: let the event loop run between frames.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    final onDisk = jsonDecode(
      File('${tmp.path}/inventory.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final saved = (onDisk['plates'] as List).firstWhere(
      (p) => (p as Map)['weightKg'] == 20,
    );
    expect((saved as Map)['count'], twenty.count + 1);
    expect(onDisk['revision'], bundle.inventory.revision, reason: 'kept');
    expect(find.text('Edit'), findsOneWidget, reason: 'back to viewing');
  });
}
