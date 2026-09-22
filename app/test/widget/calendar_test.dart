import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    // Monday-first weekday header.
    expect(find.text('M'), findsWidgets);
  });

  testWidgets('shows programme week numbers, not ISO weeks', (tester) async {
    await draw(tester, today: day(5, 0));
    // Week 5 of the programme falls in this month.
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('a completed session gets a tick', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed);
    await draw(tester, today: day(6, 0));
    expect(find.text('✓'), findsWidgets);
  });

  testWidgets('a past unlogged required session reads as missed', (
    tester,
  ) async {
    await draw(tester, today: day(6, 0));
    // Week 5 has five required sessions, none logged.
    expect(find.text('✕'), findsWidgets);
  });

  testWidgets('a moved session shows the moved glyph', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed, movedTo: 2);
    await draw(tester, today: day(6, 0));
    expect(find.text('↷'), findsWidgets);
  });

  testWidgets('adherence and streak are shown', (tester) async {
    await seedSession(5, 0, 'b-mon', SessionStatus.completed);
    await seedSession(5, 1, 'b-tue', SessionStatus.completed);
    await draw(tester, today: day(5, 2));
    expect(find.textContaining('adherence'), findsWidgets);
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
    final sat = day(5, 5);
    await draw(tester, today: sat);
    await tester.tap(find.text('${sat.day}').first);
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
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._date);
  final DateTime _date;

  @override
  DateTime build() => DateTime(_date.year, _date.month, _date.day);
}
