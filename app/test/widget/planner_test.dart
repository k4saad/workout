import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/notification_service.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/planner/planner.dart';
import 'package:keller_twelve/features/planner/planner_screen.dart';

/// The planner on the phone: the week at a glance, a day as a timeline,
/// and every change he can make to it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Recorder notifications;

  // Week 1: Monday 12 October 2026, the first day of term.
  final monday = DateTime(2026, 10, 12);
  DateTime day(int offset) =>
      DateTime(monday.year, monday.month, monday.day + offset);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_planner_');
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

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pump(WidgetTester tester, {DateTime? open}) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _Today(monday)),
          preferencesServiceProvider.overrideWithValue(
            PreferencesService(documentsDir: tmp),
          ),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: PlannerScreen(initialDate: open),
        ),
      ),
    );
    await settle(tester);
  }

  /// Waits for a batch of laid reminders that [shows] the change: laying
  /// them reads files and the database on real time, and an earlier re-lay
  /// can still be landing. Empty when none ever does.
  Future<List<({DateTime at, String title, String body})>> laidWhere(
    WidgetTester tester,
    bool Function(List<({DateTime at, String title, String body})>) shows,
  ) async {
    for (var i = 0; i < 150 && !notifications.laid.any(shows); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    return notifications.laid.lastWhere(shows, orElse: () => const []);
  }

  Future<List<PlannerEntry>> rows() => tester0(
    () async => [
      for (final r in await db.select(db.plannerEntries).get())
        PlannerEntry.stored(
          id: r.id,
          date: r.onDate,
          kind: r.kind,
          blockId: r.blockId,
          title: r.title,
          start: r.startMin,
          end: r.endMin,
          remind: r.remind,
          category: r.category,
        ),
    ],
  );

  testWidgets('Monday: the class, the shift, the ride, the session', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Week 1 of 12'), findsOneWidget);
    expect(find.text('Monday 12 October'), findsOneWidget);
    expect(find.text('Geoinformation in Society'), findsOneWidget);
    expect(find.text('Job 2'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('10:15'), findsWidgets);
    expect(find.text('18:00'), findsWidgets);
    expect(find.textContaining('Room 242'), findsOneWidget);
    expect(find.textContaining('packed, at work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on Tuesday shows its free afternoon', (tester) async {
    await pump(tester);
    await tester.tap(find.text('13'));
    await settle(tester);
    expect(find.text('Tuesday 13 October'), findsOneWidget);
    expect(find.text('Free 13:45–16:15 · 2 h 30'), findsOneWidget);
  });

  testWidgets('Friday: Job 2 is off until he marks it', (tester) async {
    await pump(tester, open: day(4));
    expect(find.text('Job 2 this Friday'), findsOneWidget);
    expect(find.text('Analysis of Spatio-Temporal Data'), findsOneWidget);
    expect(find.text('Job 2'), findsNothing);

    await tester.tap(find.byType(Switch));
    await settle(tester, rounds: 12);
    expect(find.text('Job 2'), findsOneWidget);
    final saved = await rows();
    expect(saved.single.kind, EntryKind.mark);
    final laid = await laidWhere(
      tester,
      (b) => b.any((r) => r.title == 'Job 2 · 07:00'),
    );
    expect(laid, isNotEmpty, reason: 'a marked shift rings');
  });

  testWidgets('a class skipped goes, can come back, and stops ringing', (
    tester,
  ) async {
    await pump(tester, open: day(3));
    await tester.tap(find.text('SII exercise'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400)); // sheet open
    expect(find.text('Room'), findsNothing);
    expect(find.textContaining('StudLab 130'), findsWidgets);
    await tester.tap(find.text('Skip this one'));
    await settle(tester, rounds: 12);

    expect(find.text('SKIPPED'), findsOneWidget);
    expect(find.text('Bring back'), findsOneWidget);
    expect((await rows()).single.blockId, 'sii-ex-thu');
    final laid = await laidWhere(
      tester,
      // This Thursday's; next Thursday's exercise still rings.
      (b) =>
          b.any((r) => r.title.startsWith('SII lecture') && r.at.day == 15) &&
          !b.any((r) => r.title.startsWith('SII exercise') && r.at.day == 15),
    );
    expect(laid, isNotEmpty, reason: 'the lecture rings, the exercise not');

    await tester.tap(find.text('Bring back'));
    await settle(tester, rounds: 12);
    expect(find.text('SKIPPED'), findsNothing);
    expect(await rows(), isEmpty);
  });

  testWidgets('the session moves fifteen minutes a tap', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Full Body A'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400)); // sheet open
    expect(find.text('Start session'), findsOneWidget, reason: 'it is today');
    await tester.tap(find.byTooltip('Later'));
    await tester.pump();
    await tester.tap(find.text('Move to 18:15'));
    await settle(tester, rounds: 12);
    final moved = (await rows()).single;
    expect(moved.kind, EntryKind.sessionTime);
    expect(moved.start, 18 * 60 + 15);
    expect(find.textContaining('moved'), findsOneWidget);
  });

  testWidgets('something of his own, added with chips and steppers', (
    tester,
  ) async {
    await pump(tester, open: day(5));
    await tester.tap(find.text('Add to this day'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400)); // sheet open
    await tester.tap(find.widgetWithText(ChoiceChip, 'Exam'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Later'));
      await tester.pump();
    }
    expect(find.text('11:00'), findsOneWidget, reason: '10:00 + 4 x 15');
    await tester.tap(find.text('Add · 11:00–12:00'));
    await settle(tester, rounds: 12);

    final e = (await rows()).single;
    expect(e.kind, EntryKind.event);
    expect(e.title, 'Exam');
    expect(e.category, 'exam');
    expect(e.start, 11 * 60);
    expect(e.remind, isTrue);
    expect(find.text('Exam'), findsOneWidget);
    final laid = await laidWhere(
      tester,
      (b) => b.any((r) => r.title == 'Exam · 11:00'),
    );
    expect(laid, isNotEmpty);
  });

  testWidgets('the winter break says so, and has no lectures', (tester) async {
    await pump(tester, open: DateTime(2026, 12, 23));
    expect(find.text('Winter break'), findsOneWidget);
    expect(find.text('Job 1'), findsOneWidget);
    expect(find.text('Spatial Justice'), findsNothing);
  });
}

/// Runs [body] outside the fake clock: the database works on real time.
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
