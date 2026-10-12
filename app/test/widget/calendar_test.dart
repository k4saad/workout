import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/calendar/calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeBundle bundle;
  late AppDatabase db;
  late ProgrammeCalendar cal;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_cal_');
    final repo = ProgrammeRepository(documentsDir: tmp);
    final programme = await repo.loadProgramme();
    final library = await repo.loadLibrary();
    final inventory = await repo.loadInventory();
    cal = ProgrammeCalendar(programme);
    bundle = (
      programme: programme,
      library: library,
      inventory: inventory,
      calendar: cal,
      resolver: BlockResolver(programme),
      lattice: Lattice(inventory),
    );
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  DateTime day(int week, int offset) =>
      ProgrammeCalendar.addDays(cal.startOfWeek(week), offset);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String title(DateTime m) => DateFormat('MMMM yyyy').format(m);

  /// In the grid, not in the key under it, which repeats every mark.
  Finder inGrid(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('month-grid')),
    matching: f,
  );

  Future<void> seedSession(
    int week,
    int offset,
    String dayId,
    SessionStatus status, {
    int? movedTo,
  }) => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          programmeId: 'keller-twelve',
          blockId: 'build',
          dayId: dayId,
          weekNo: week,
          plannedDate: day(week, offset),
          scheduledDate: day(week, movedTo ?? offset),
          status: Value(status),
        ),
      );

  Widget harness({DateTime? today}) => ProviderScope(
    overrides: [
      bundleProvider.overrideWith((ref) => bundle),
      databaseProvider.overrideWithValue(db),
      todayProvider.overrideWith(() => _FixedToday(today ?? day(6, 0))),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: const CalendarScreen()),
  );

  Future<void> draw(WidgetTester tester, {DateTime? today}) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(today: today));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('renders a month grid without overflowing', (tester) async {
    await draw(tester);
    expect(tester.takeException(), isNull);
    // Monday-first weekday header, in words a glance can read.
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('shows programme week numbers, not ISO weeks', (tester) async {
    await draw(tester, today: day(5, 0));
    // Week 5 of the programme falls in this month.
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('a completed session gets a tick', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed);
    await draw(tester, today: day(6, 0));
    expect(inGrid(find.text('✓')), findsOneWidget);
  });

  testWidgets('a past unlogged required session reads as missed', (
    tester,
  ) async {
    await draw(tester, today: day(6, 0));
    // Week 5 has three required sessions, none logged.
    expect(inGrid(find.text('✕')), findsWidgets);
  });

  testWidgets('a moved session shows the moved glyph', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed, movedTo: 1);
    await draw(tester, today: day(6, 0));
    expect(inGrid(find.text('↷')), findsOneWidget);
  });

  testWidgets('adherence and streak are shown', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed);
    await seedSession(5, 2, 'b-wed', SessionStatus.completed);
    await draw(tester, today: day(5, 4));
    // Against what was due, not against all thirty-six sessions.
    expect(find.textContaining('of what was due'), findsOneWidget);
    expect(find.textContaining('of the programme'), findsOneWidget);
    expect(find.textContaining('streak 2'), findsWidgets);
  });

  testWidgets('tapping a past unlogged day offers retroactive logging', (
    tester,
  ) async {
    await draw(tester, today: day(6, 0));

    // Week 5 Monday is in the past and unlogged.
    final target = day(5, 0);
    await tester.tap(find.text('${target.day}').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('Log it from memory'), findsWidgets);
    expect(find.textContaining('Mark as skipped'), findsWidgets);
    expect(find.textContaining('never got logged'), findsWidgets);
  });

  testWidgets('tapping today offers to start the session', (tester) async {
    final today = day(5, 0);
    await draw(tester, today: today);
    await tester.tap(find.text('${today.day}').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('Start session'), findsWidgets);
  });

  testWidgets('tapping a rest day explains rather than offering a session', (
    tester,
  ) async {
    final thu = day(5, 3);
    await draw(tester, today: thu);
    await tester.tap(find.text('${thu.day}').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('Start session'), findsNothing);
    expect(find.textContaining('Complete rest'), findsWidgets);
  });

  testWidgets('paging months keeps working', (tester) async {
    await draw(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a swipe turns the month, and Today comes back', (tester) async {
    final today = day(5, 0);
    await draw(tester, today: today);
    expect(find.text(title(today)), findsOneWidget);
    expect(find.text('Today'), findsNothing, reason: 'already on today');

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await settle(tester);
    final next = DateTime(today.year, today.month + 1);
    expect(find.text(title(next)), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text(title(today)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skipped and missed read differently', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.skipped);
    await draw(tester, today: day(5, 4));
    expect(inGrid(find.text('⊘')), findsOneWidget, reason: 'Monday, skipped');
    expect(
      inGrid(find.text('✕')),
      findsWidgets,
      reason: 'Wednesday, never logged',
    );
  });

  testWidgets('a moved session leaves an arrow, not a cross', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed, movedTo: 1);
    await draw(tester, today: day(5, 2));
    expect(inGrid(find.text('→')), findsOneWidget, reason: 'Monday: away');
    // A cell carries one glyph, so Monday's arrow is Monday not being ✕.
    expect(inGrid(find.text('↷')), findsOneWidget, reason: 'Tuesday: here');
  });

  testWidgets('two sessions on one date are both on the sheet', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed, movedTo: 2);
    await seedSession(5, 2, 'b-wed', SessionStatus.completed);
    await draw(tester, today: day(5, 4));
    expect(find.text('✓+1'), findsOneWidget, reason: 'the cell counts both');

    await tester.tap(find.text('✓+1'));
    await settle(tester);
    expect(find.text('LOGGED HERE: TWO SESSIONS'), findsOneWidget);
    expect(find.textContaining('Moved here from'), findsOneWidget);
    expect(find.text('Correct it'), findsNWidgets(2));
  });

  testWidgets('the date a session left says where it went', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed, movedTo: 1);
    await draw(tester, today: day(5, 3));
    await tester.tap(inGrid(find.text('→')));
    await settle(tester);
    expect(find.textContaining('Moved to'), findsOneWidget);
    expect(
      find.text('Log it from memory'),
      findsNothing,
      reason: 'it was done, just not here',
    );
  });

  testWidgets('a checkpoint week carries a flag, and a weigh-in a mark', (
    tester,
  ) async {
    final week4 = day(4, 1);
    await db.upsertBodyweight(week4, 50.6);
    await draw(tester, today: day(4, 3));
    // The month's grid runs from week 1 to week 5; 1 and 4 are checkpoints.
    expect(inGrid(find.byIcon(Icons.flag_rounded)), findsNWidgets(2));
    expect(inGrid(find.byIcon(Icons.monitor_weight_outlined)), findsOneWidget);
    expect(find.text('WHAT THE MARKS MEAN'), findsOneWidget);
  });

  testWidgets('the month is summed up under the grid', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed);
    final today = day(5, 2);
    await draw(tester, today: today);
    expect(
      find.text(DateFormat('MMMM').format(today).toUpperCase()),
      findsOneWidget,
    );
    expect(find.textContaining('sessions due'), findsOneWidget);
  });
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._date);
  final DateTime _date;

  @override
  DateTime build() => DateTime(_date.year, _date.month, _date.day);
}
