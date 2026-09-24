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
import 'package:keller_twelve/features/week/week_screen.dart';

/// The Week tab says what got done, not only what was planned.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeBundle bundle;
  late AppDatabase db;
  late ProgrammeCalendar cal;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_week_');
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

  Future<void> seed(
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

  Future<void> draw(WidgetTester tester, DateTime today) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundleProvider.overrideWith((ref) => bundle),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _Today(today)),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const WeekScreen()),
      ),
    );
    await _settle(tester);
  }

  testWidgets('each day says what happened to it', (tester) async {
    await seed(5, 0, 'b-mon', SessionStatus.completed);
    await seed(5, 1, 'b-tue', SessionStatus.skipped);
    await seed(5, 3, 'b-thu', SessionStatus.completed, movedTo: 2);
    await draw(tester, day(5, 4));

    expect(find.text('done'), findsOneWidget, reason: 'Monday');
    expect(find.text('skipped'), findsOneWidget, reason: 'Tuesday');
    expect(find.textContaining('moved to'), findsOneWidget, reason: 'Thu');
    expect(find.textContaining('session done here'), findsOneWidget);
    expect(find.text('✕'), findsNothing, reason: 'nothing was missed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the week counts sessions against the required ones', (
    tester,
  ) async {
    await seed(5, 0, 'b-mon', SessionStatus.completed);
    await draw(tester, day(5, 3));
    expect(find.text('1 of 5 sessions done'), findsOneWidget);
    expect(find.textContaining('✕ 1 missed'), findsOneWidget);
    expect(find.textContaining('3 to come'), findsOneWidget);
  });

  testWidgets('a week not started yet just says what is in it', (tester) async {
    await draw(tester, day(1, 0));
    await tester.tap(find.byTooltip('Next week'));
    await _settle(tester);
    expect(find.textContaining('Week 2 of 12'), findsOneWidget);
    expect(find.textContaining('sessions this week'), findsOneWidget);
    expect(find.textContaining('missed'), findsNothing);
  });

  testWidgets('a swipe changes the week and This week comes back', (
    tester,
  ) async {
    await draw(tester, day(3, 2));
    expect(find.textContaining('Week 3 of 12'), findsOneWidget);
    expect(find.text('This week'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _settle(tester);
    expect(find.textContaining('Week 4 of 12'), findsOneWidget);

    await tester.tap(find.text('This week'));
    await _settle(tester);
    expect(find.textContaining('Week 3 of 12'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('a checkpoint week lists what it asks for', (tester) async {
    await draw(tester, day(4, 0));
    expect(find.text('Checkpoint'), findsOneWidget);
    for (final item in bundle.programme.checkpointForWeek(4)!.items) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('Take the photos'), findsOneWidget);
  });

  testWidgets('tapping a day opens its sheet', (tester) async {
    await draw(tester, day(5, 3));
    await tester.tap(find.text('THU ${day(5, 3).day}'));
    await _settle(tester);
    expect(find.text('Start session'), findsOneWidget);
    expect(find.text('See the session'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Today extends TodayNotifier {
  _Today(this.d);
  final DateTime d;
  @override
  DateTime build() => DateTime(d.year, d.month, d.day);
}
