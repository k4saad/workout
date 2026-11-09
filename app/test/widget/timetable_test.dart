import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/router.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/notification_service.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/planner/planner.dart';
import 'package:keller_twelve/features/planner/planner_screen.dart';
import 'package:keller_twelve/features/planner/timetable_screen.dart';

/// "Your week" on the phone (docs/13-your-week-plan.md): the timetable as
/// something he changes in a few taps instead of a new build.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Recorder notifications;

  // Monday 9 November 2026: week 1, the day the week changed.
  final monday = DateTime(2026, 11, 9);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_week_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadProgramme();
    await repo.loadFuel();
    await repo.loadTimetable();
    notifications = _Recorder();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  List<Override> overrides() => [
    programmeRepositoryProvider.overrideWithValue(repo),
    databaseProvider.overrideWithValue(db),
    todayProvider.overrideWith(() => _Today(monday)),
    clockProvider.overrideWithValue(() => DateTime(2026, 11, 9, 7)),
    preferencesServiceProvider.overrideWithValue(
      PreferencesService(documentsDir: tmp),
    ),
    notificationServiceProvider.overrideWithValue(notifications),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 6400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(theme: AppTheme.dark, home: const TimetableScreen()),
      ),
    );
    await settle(tester);
  }

  /// Opens a sheet and waits for it to be up.
  Future<void> open(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  Future<Timetable> saved() => tester0(() => repo.loadTimetable(force: true));

  /// Waits for a batch of laid reminders that [shows] the change.
  Future<bool> rings(
    WidgetTester tester,
    bool Function(List<({DateTime at, String title, String body})>) shows,
  ) async {
    for (var i = 0; i < 150 && !notifications.laid.any(shows); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    return notifications.laid.any(shows);
  }

  testWidgets('the week day by day, and the semester under it', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(AppBar, 'Your week'), findsOneWidget);
    expect(find.text('Winter Semester 2026/27'), findsWidgets);
    for (final day in ['MONDAY', 'WEDNESDAY', 'SUNDAY']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('Geoinformation in Society'), findsNothing);
    expect(find.text('Spatial Justice'), findsOneWidget);
    expect(find.text('German'), findsNWidgets(7));
    expect(find.textContaining('Every day'), findsNWidgets(7));
    expect(find.textContaining('Tue, Fri'), findsNWidgets(2));
    expect(find.text('Winter break'), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(
      find.text('Back to the shipped week'),
      findsNothing,
      reason: 'nothing changed yet',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a block added with chips and steppers is saved, and rings', (
    tester,
  ) async {
    await pump(tester);
    await open(tester, find.text('Add to the week'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Study'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Thesis reading');
    await tester.pump();
    // Monday is preselected: today. Saturday and Sunday instead.
    await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
    await tester.tap(find.widgetWithText(FilterChip, 'Sat'));
    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('An hour later').first);
      await tester.pump();
    }
    expect(find.text('14:00'), findsOneWidget, reason: '10:00 + 4 h');
    expect(find.text('15:30'), findsOneWidget, reason: 'the length moves too');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Library'));
    await tester.pump();
    await tapVisible(tester, find.text('Add · Weekends 14:00–15:30'));
    await settle(tester, rounds: 14);

    final week = await saved();
    final b = week.block('thesis-reading')!;
    expect(b.kind, PlanKind.study);
    expect(b.days, [Weekday.sat, Weekday.sun]);
    expect(b.start, 14 * 60);
    expect(b.end, 15 * 60 + 30);
    expect(b.place, 'library');
    expect(await tester0(() => repo.timetableIsEdited), isTrue);
    expect(find.text('Thesis reading'), findsNWidgets(2));
    expect(
      await rings(
        tester,
        (r) => r.any(
          (x) =>
              x.title == 'Thesis reading · 14:00' &&
              x.body.startsWith('Leave by 13:30'),
        ),
      ),
      isTrue,
    );
    expect(find.text('Back to the shipped week'), findsOneWidget);
  });

  testWidgets('German, half an hour later, every day at once', (tester) async {
    await pump(tester);
    await open(tester, find.text('German').first);
    expect(find.text('Change it every week'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Later').first);
      await tester.pump();
    }
    await tapVisible(tester, find.text('Save · Every day 20:30–21:30'));
    await settle(tester, rounds: 14);

    final german = (await saved()).block('german')!;
    expect(german.start, 20 * 60 + 30);
    expect(german.end, 21 * 60 + 30);
    expect(german.days, Weekday.values);
    expect(find.text('20:30'), findsNWidgets(7));
  });

  testWidgets('a clash is named before it is saved', (tester) async {
    await pump(tester);
    await open(tester, find.text('German').first);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('An hour earlier').first);
      await tester.pump();
    }
    expect(find.textContaining('is on top of Library'), findsNWidgets(2));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
  });

  testWidgets('a block deleted goes, and Undo brings it back', (tester) async {
    await pump(tester);
    await open(tester, find.text('Spatial Justice'));
    await tapVisible(tester, find.text('Delete from the week'));
    await settle(tester, rounds: 14);

    expect(find.text('Spatial Justice'), findsNothing);
    expect((await saved()).block('sj-wed'), isNull);
    expect(find.text('Spatial Justice is off your week.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester, rounds: 14);
    expect((await saved()).block('sj-wed'), isNotNull);
    expect(find.text('Spatial Justice'), findsOneWidget);
  });

  testWidgets('the travel time, on a stepper', (tester) async {
    await pump(tester);
    await open(tester, find.text('Travel'));
    await tester.tap(find.byTooltip('Shorter'));
    await tester.pump();
    await tester.tap(find.byTooltip('Shorter'));
    await tester.pump();
    await tapVisible(tester, find.text('Save · 20 min'));
    await settle(tester, rounds: 14);
    expect((await saved()).travelMinutes, 20);
  });

  testWidgets('a place in use cannot be deleted; a new one can be added', (
    tester,
  ) async {
    await pump(tester);
    await open(tester, find.text('Campus'));
    final delete = find.widgetWithText(TextButton, 'Delete the place');
    expect(tester.widget<TextButton>(delete).onPressed, isNull);
    expect(find.textContaining('Move them first'), findsOneWidget);
    await tester.tapAt(const Offset(200, 20)); // away from the sheet
    await settle(tester);

    await open(tester, find.text('Add a place'));
    await tester.enterText(find.byType(TextField), 'Café');
    await tester.pump();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Add'));
    await settle(tester, rounds: 14);
    expect((await saved()).places['cafe'], 'Café');
  });

  testWidgets('back to the shipped week, after asking', (tester) async {
    await pump(tester);
    await open(tester, find.text('Travel'));
    await tester.tap(find.byTooltip('Longer'));
    await tester.pump();
    await tapVisible(tester, find.text('Save · 35 min'));
    await settle(tester, rounds: 14);
    expect(await tester0(() => repo.timetableIsEdited), isTrue);

    await tapVisible(tester, find.text('Back to the shipped week'));
    await settle(tester);
    await tester.tap(find.text('Go back'));
    await settle(tester, rounds: 14);
    expect(await tester0(() => repo.timetableIsEdited), isFalse);
    expect((await saved()).travelMinutes, 30);
  });

  testWidgets('from the planner and back again', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await settle(tester);
    router.go('/week/planner');
    await settle(tester);
    expect(find.byType(PlannerScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Your week'));
    await settle(tester);
    expect(find.byType(TimetableScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TimetableScreen), findsNothing);
    expect(find.byType(PlannerScreen), findsOneWidget);
  });
}

/// Runs [body] outside the fake clock: files and the database work on real
/// time.
Future<T> tester0<T>(Future<T> Function() body) => body();

class _Today extends TodayNotifier {
  _Today(this.d);
  final DateTime d;
  @override
  DateTime build() => DateTime(d.year, d.month, d.day);
}

/// Remembers every batch of planner reminders laid.
class _Recorder implements NotificationService {
  final laid = <List<({DateTime at, String title, String body})>>[];

  @override
  Future<void> schedulePlannerReminders(
    List<({DateTime at, String title, String body})> reminders,
  ) async => laid.add(reminders);
  @override
  Future<void> cancelPlannerReminders() async => laid.add(const []);
  @override
  bool get canScheduleExact => false;
  @override
  bool get isAndroid => false;
  @override
  Future<void> init({void Function(String? payload)? onTap}) async {}
  @override
  Future<void> scheduleRestEnd(
    DateTime at, {
    required String exerciseName,
    required int setNumber,
    String? payload,
  }) async {}
  @override
  Future<void> scheduleIntervalCues(
    List<({DateTime at, String title, String body})> cues, {
    int max = 24,
  }) async {}
  @override
  Future<void> cancelSessionReminders() async {}
  @override
  Future<void> cancelRest() async {}
  @override
  Future<void> cancelIntervals() async {}
  @override
  Future<void> cancelAll() async {}
}
