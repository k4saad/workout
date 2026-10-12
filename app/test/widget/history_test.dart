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
import 'package:keller_twelve/features/history/history_screen.dart';

/// History across a change of plan: sessions logged under v3 stay readable
/// after v4 replaced the days they were logged on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_history_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
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
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> logged(String dayId, DateTime on, int weekNo) async {
    final id = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'foundation',
            dayId: dayId,
            weekNo: weekNo,
            plannedDate: on,
            scheduledDate: on,
            status: const Value(SessionStatus.completed),
          ),
        );
    await db
        .into(db.setLogs)
        .insert(
          SetLogsCompanion.insert(
            sessionId: id,
            prescriptionId: '$dayId-1',
            exerciseId: 'barbell-back-squat',
            setIndex: 1,
            completedAt: on.add(const Duration(hours: 19)),
          ).copyWith(reps: const Value(8), loadKg: const Value(10)),
        );
  }

  testWidgets('a session from the replaced plan is named, not an id', (
    tester,
  ) async {
    final programme = await repo.loadProgramme();
    // v3's Tuesday, two weeks before v4 began: a day the plan has no more.
    await logged('f-tue', DateTime(2026, 9, 29), 1);
    // v4's first Monday.
    await logged('f-mon', programme.startDate, 1);

    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HistoryScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Week 1 · Earlier plan'), findsOneWidget);
    expect(find.textContaining('f-tue'), findsNothing);
    expect(find.text('Week 1 · Full Body A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
