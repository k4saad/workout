import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/quote_providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/content/quotes.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/today/today_screen.dart';

/// Today is built around the day: the session until it is done, then the
/// rest of the day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeBundle bundle;
  late AppDatabase db;
  late ProgrammeCalendar cal;

  const quote = Quote(
    id: 'g-epictetus-habit',
    tradition: QuoteTradition.greek,
    text:
        'Every habit and faculty is maintained and increased by the '
        'corresponding actions: the habit of walking by walking, the habit '
        'of running by running.',
    attribution: 'Epictetus, Discourses 2.18',
    translator: 'George Long (1877)',
  );

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_today_');
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

  Future<void> draw(WidgetTester tester, DateTime today) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundleProvider.overrideWith((ref) => bundle),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _Today(today)),
          quoteOfDayProvider.overrideWith(
            (ref) async => (quote: quote, fresh: false),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const TodayScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('the session to do is the one thing on the screen', (
    tester,
  ) async {
    await draw(tester, day(1, 1));
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('done, it is said quietly and not offered again', (tester) async {
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'foundation',
            dayId: 'f-tue',
            weekNo: 1,
            plannedDate: day(1, 1),
            scheduledDate: day(1, 1),
            status: const Value(SessionStatus.completed),
          ),
        );
    await draw(tester, day(1, 1));
    expect(find.text('Done today. Eat, and sleep.'), findsOneWidget);
    expect(find.text('Start session'), findsNothing);
  });

  testWidgets('a rest day says rest, and offers no session', (tester) async {
    await draw(tester, day(1, 2));
    expect(find.text('Rest'), findsWidgets);
    expect(find.text('Start session'), findsNothing);
    // It names what is due, so a rest day is not a blank.
    expect(find.text('Next: Full Body B, tomorrow'), findsOneWidget);
  });

  testWidgets('the quote of the day sits under the day', (tester) async {
    await draw(tester, day(1, 0));
    expect(find.text(quote.text), findsOneWidget);
    expect(find.text(quote.attribution), findsOneWidget);
  });

  testWidgets('the weigh-in is one tap away, and says when it is done', (
    tester,
  ) async {
    await draw(tester, day(1, 1));
    expect(find.text('Not weighed in yet'), findsOneWidget);
    expect(find.text('Weigh in'), findsOneWidget);

    await db.upsertBodyweight(day(1, 1), 50.4);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('50.4 kg this morning'), findsOneWidget);
    expect(find.text('Weigh in'), findsNothing);
  });

  testWidgets('the week strip counts the week', (tester) async {
    await draw(tester, day(1, 2));
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.textContaining('of 3 done'), findsOneWidget);
  });
}

class _Today extends TodayNotifier {
  _Today(this.d);
  final DateTime d;
  @override
  DateTime build() => DateTime(d.year, d.month, d.day);
}
