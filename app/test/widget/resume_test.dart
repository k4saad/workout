import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../qa/qa_harness.dart';

/// Picking up a session that was left open: the banner on Today must open
/// THAT session, not start a second one for the same day.
void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_resume_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  testWidgets('a session left open last night resumes, it does not double', (
    tester,
  ) async {
    // A session started 26 hours ago and never finished: yesterday's, by
    // the real clock the runner times it with.
    final started = DateTime.now().subtract(const Duration(hours: 26));
    final yesterday = DateTime(started.year, started.month, started.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await repo.ensureSeeded();
      final programme = await repo.loadProgramme();
      final id = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: programme.id,
              blockId: 'foundation',
              dayId: 'f-mon',
              weekNo: 1,
              plannedDate: yesterday,
              scheduledDate: yesterday,
              startedAt: Value(started),
              status: const Value(SessionStatus.inProgress),
            ),
          );
      expect(id, greaterThan(0));
    });

    final app = QaApp(db: db, repo: repo, tmp: tmp);
    await app.pump(tester, today: today);
    expect(find.text('Session in progress'), findsOneWidget);

    await tester.tap(find.text('Session in progress'));
    await QaApp.settle(tester);
    await QaApp.settle(tester);

    final sessions = await tester.runAsync(() => db.select(db.sessions).get());
    expect(
      sessions,
      hasLength(1),
      reason: 'a second session for that day would orphan the first',
    );
    expect(find.text('Full Body A'), findsWidgets);

    // Its clock ran all night: that is an interruption, not a slow session.
    expect(find.text('Running long'), findsNothing);
    expect(find.textContaining(RegExp(r'/ \d+ min')), findsNothing);
    expect(find.textContaining('picked up again'), findsOneWidget);
  });
}
