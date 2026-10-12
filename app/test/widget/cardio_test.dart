import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/notification_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/features/cardio/cardio_screen.dart';

/// The Cardio page, as it is used: timers that stop when told, runs that
/// are recorded with GPS or logged on steppers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late _Cues cues;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_cardio_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadProgramme();
    cues = _Cues();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// The Cardio page pushed over a home page, so back has somewhere to go.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(cues),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardioScreen(),
                    ),
                  ),
                  child: const Text('Open cardio'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open cardio'));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('runs are recorded with GPS, not sent to another app', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Record a run'), findsOneWidget);
    expect(find.textContaining('already has a running app'), findsNothing);
    expect(find.textContaining('No GPS'), findsNothing);
  });

  testWidgets('a run logged by hand is set on steppers and saved', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Log one by hand'));
    await settle(tester);
    // Let the sheet finish rising before reaching for its button.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsNothing, reason: 'no keyboard');

    // 30 min by default: two big steps up is 40.
    await tester.tap(find.byTooltip('Up 5'));
    await tester.tap(find.byTooltip('Up 5'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Up 0.1'));
    }
    await tester.pump();
    await tester.tap(find.text('Save the run'));
    await settle(tester);
    await settle(tester);

    final rows = await tester.runAsync(() => db.select(db.cardioLogs).get());
    expect(rows, hasLength(1));
    expect(rows!.single.kind, CardioKind.run);
    expect(rows.single.durationSec, 40 * 60);
    expect(rows.single.distanceM, 300);
  });

  testWidgets('Stop silences the round cues', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skipping · 6 × 45 s'));
    await settle(tester);
    expect(cues.scheduled, 1);

    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(cues.cancelled, 1, reason: 'the phone must not call round 4');
  });

  testWidgets('leaving mid-interval asks, then stops the cues', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skipping · 6 × 45 s'));
    await settle(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Stop the timer?'), findsOneWidget);
    await tester.tap(find.text('Stop and leave'));
    await settle(tester);
    await settle(tester);

    expect(find.text('Open cardio'), findsOneWidget);
    expect(cues.cancelled, greaterThanOrEqualTo(1));
  });
}

class _Cues implements NotificationService {
  int scheduled = 0;
  int cancelled = 0;

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
  }) async => scheduled++;
  @override
  Future<void> cancelSessionReminders() async {}
  @override
  Future<void> schedulePlannerReminders(
    List<({DateTime at, String title, String body})> reminders,
  ) async {}
  @override
  Future<void> cancelPlannerReminders() async {}
  @override
  Future<void> cancelRest() async {}
  @override
  Future<void> cancelIntervals() async => cancelled++;
  @override
  Future<void> cancelAll() async {}
}
