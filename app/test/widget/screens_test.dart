import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/day/day_detail_screen.dart';
import 'package:keller_twelve/features/today/today_screen.dart';
import 'package:keller_twelve/features/week/week_screen.dart';

/// Renders the Phase 1 screens against the REAL shipped programme.
///
/// A viewer that renders a hand-made fixture proves nothing. The point of
/// these is that the actual twelve weeks of data draw without overflowing or
/// throwing.
///
/// The bundle is loaded ONCE, outside the test's fake-async zone, and injected
/// as a resolved value. Letting the FutureProvider do real file I/O inside a
/// widget test means `pumpAndSettle` waits forever on a spinner that never
/// stops animating.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeBundle bundle;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_widget_');
    final repo = ProgrammeRepository(documentsDir: tmp);
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
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Pins "now" so tests do not drift with the wall clock.
  Widget harness(Widget child, {DateTime? today, int? week}) => ProviderScope(
    overrides: [
      bundleProvider.overrideWith((ref) => bundle),
      todayProvider.overrideWith(
        () => _FixedToday(today ?? bundle.programme.startDate),
      ),
      if (week != null)
        selectedWeekProvider.overrideWith(() => _PinnedWeek(week)),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Pumps a couple of frames. No pumpAndSettle: the data is already resolved,
  /// and settling would block on any indeterminate progress animation.
  Future<void> draw(
    WidgetTester tester,
    Widget w, {
    DateTime? today,
    int? week,
  }) async {
    await tester.pumpWidget(harness(w, today: today, week: week));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  void phoneSized(WidgetTester tester, [Size size = const Size(400, 900)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Today renders on day one', (tester) async {
    phoneSized(tester);
    await draw(tester, const TodayScreen());
    expect(find.text('The Keller Twelve'), findsOneWidget);
    expect(find.textContaining('Week 1 of 12'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today no longer nags about bar weights', (tester) async {
    // v3 ships the definitive kit (measured: true, collars included), so the
    // "bars are still estimates" nag and the "weigh both bars" copy are gone
    // — on day one and before it. Tall viewport: ListView builds lazily.
    expect(bundle.inventory.bars.every((b) => b.measured), isTrue);
    phoneSized(tester, const Size(400, 2600));
    final before = ProgrammeCalendar.addDays(bundle.programme.startDate, -3);
    for (final today in [bundle.programme.startDate, before]) {
      await draw(tester, const TodayScreen(), today: today);
      expect(find.textContaining('still estimates'), findsNothing);
      expect(find.textContaining('bathroom'), findsNothing);
      expect(find.textContaining(RegExp('weigh both bars')), findsNothing);
    }

    // What to do before week 1 is the programme's own week-1 checkpoint.
    for (final item in bundle.programme.checkpointForWeek(1)!.items) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
  });

  testWidgets('Week renders seven day cards', (tester) async {
    phoneSized(tester, const Size(400, 1600));
    await draw(tester, const WeekScreen());
    expect(find.textContaining('Week 1 of 12'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Rest'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every authored day renders without throwing', (tester) async {
    phoneSized(tester, const Size(400, 2400));

    // Foundation, Build and Test own their days; Deload and Push resolve from
    // Build, so one representative week of each covers the inheritance paths.
    const cases = <(int, String)>[
      (1, 'foundation'),
      (5, 'build'),
      (8, 'deload'),
      (9, 'push'),
      (12, 'test'),
    ];

    var rendered = 0;
    for (final (week, blockId) in cases) {
      final block = bundle.programme.blockById(blockId)!;
      final days = bundle.resolver.resolveDays(block, week);
      for (final d in days) {
        await draw(tester, DayDetailScreen(weekNo: week, dayId: d.id));
        expect(
          tester.takeException(),
          isNull,
          reason: 'week $week / ${d.id} threw while rendering',
        );
        rendered++;
      }
    }
    expect(rendered, 35); // 5 blocks x 7 weekdays
  });

  testWidgets('a deload day shows deloaded loads, not the build loads', (
    tester,
  ) async {
    phoneSized(tester, const Size(400, 2400));
    await draw(tester, const DayDetailScreen(weekNo: 8, dayId: 'b-mon'));

    // 21 kg * 0.70 = 14.7, and the build number must not survive.
    expect(find.textContaining('14.7'), findsWidgets);
    expect(find.text('21 kg'), findsNothing);
  });

  testWidgets('warnings render above the work', (tester) async {
    phoneSized(tester, const Size(400, 2400));
    await draw(tester, const DayDetailScreen(weekNo: 5, dayId: 'b-thu'));

    expect(find.textContaining('Bar height'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('supersets render as one grouped unit', (tester) async {
    phoneSized(tester, const Size(400, 2400));
    await draw(tester, const DayDetailScreen(weekNo: 5, dayId: 'b-tue'));

    expect(find.textContaining('alternate, rest'), findsWidgets);
    expect(find.textContaining('SS1'), findsWidgets);
    expect(find.textContaining('SS2'), findsWidgets);
  });

  testWidgets('a deload day shows NO supersets', (tester) async {
    phoneSized(tester, const Size(400, 2400));
    await draw(tester, const DayDetailScreen(weekNo: 8, dayId: 'b-tue'));
    expect(find.textContaining('alternate, rest'), findsNothing);
  });

  testWidgets('the rest day says why it exists', (tester) async {
    phoneSized(tester);
    await draw(tester, const DayDetailScreen(weekNo: 5, dayId: 'b-sat'));
    expect(find.textContaining('Muscle is built on the days'), findsOneWidget);
  });

  testWidgets('week 13 tells you the programme is done', (tester) async {
    phoneSized(tester);
    final after = ProgrammeCalendar.addDays(
      ProgrammeCalendar(bundle.programme).lastDate,
      1,
    );
    await draw(tester, const TodayScreen(), today: after);
    expect(find.textContaining('Twelve weeks, done'), findsOneWidget);
  });

  testWidgets('before the start it names the date, not a countdown', (
    tester,
  ) async {
    phoneSized(tester);
    final before = ProgrammeCalendar.addDays(bundle.programme.startDate, -3);
    await draw(tester, const TodayScreen(), today: before);

    // "In three days" is a number you have to do arithmetic on before you can
    // use it. A date is one you can hold against a calendar.
    expect(find.text('Week 1 starts'), findsOneWidget);
    expect(
      find.text(DateFormat('EEEE d MMMM').format(bundle.programme.startDate)),
      findsOneWidget,
    );
    expect(find.textContaining('Starts in'), findsNothing);
  });

  testWidgets('day detail shows per-side reps for unilateral work', (
    tester,
  ) async {
    phoneSized(tester, const Size(400, 2400));
    await draw(tester, const DayDetailScreen(weekNo: 5, dayId: 'b-mon'));
    // Bulgarian split squats are 3 x 8 per side, not 3 x 8 total.
    expect(find.textContaining('/ side'), findsWidgets);
  });

  testWidgets('the test week labels itself', (tester) async {
    phoneSized(tester, const Size(400, 2000));
    await draw(tester, const WeekScreen(), week: 12);
    expect(find.textContaining('Test week'), findsOneWidget);
  });

  testWidgets('the deload week warns you not to skip it', (tester) async {
    phoneSized(tester, const Size(400, 2000));
    await draw(tester, const WeekScreen(), week: 8);
    expect(find.textContaining('Deload week'), findsOneWidget);
    expect(find.textContaining('turn into muscle'), findsOneWidget);
  });
}

class _PinnedWeek extends SelectedWeekNotifier {
  _PinnedWeek(this._week);
  final int _week;

  @override
  int? build() => _week;
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._date);
  final DateTime _date;

  @override
  DateTime build() => DateTime(_date.year, _date.month, _date.day);
}
