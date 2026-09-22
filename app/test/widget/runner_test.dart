import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/notification_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/plates/lattice.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';
import 'package:keller_twelve/features/session/session_runner_screen.dart';

/// Walks the runner the way a session actually goes: open it, log a set,
/// watch the rest timer appear, move on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProgrammeBundle bundle;
  late AppDatabase db;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('kt_runner_');
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

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Widget harness(Widget child) => ProviderScope(
    overrides: [
      bundleProvider.overrideWith((ref) => bundle),
      databaseProvider.overrideWithValue(db),
      // No platform channels in a widget test. The runner must not depend on
      // the phone being able to buzz.
      notificationServiceProvider.overrideWithValue(_SilentNotifications()),
      todayProvider.overrideWith(
        () => _FixedToday(ProgrammeCalendar(bundle.programme).startOfWeek(5)),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Brings a movement pill into view — the strip scrolls horizontally, so
  /// later movements are simply not built until you get to them.
  Future<void> focusMovement(WidgetTester tester, String name) async {
    await tester.dragUntilVisible(
      find.text(name),
      find.byKey(const ValueKey('movement-strip')),
      const Offset(-120, 0),
    );
    await tester.pump();
    await tester.tap(find.text(name).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, String dayId, {int week = 5}) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(SessionRunnerScreen(weekNo: week, dayId: dayId)),
    );
    // Boot does real (fast, in-memory) async work; give it frames.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('opens on the first movement of the day', (tester) async {
    await open(tester, 'b-mon');
    expect(find.text('Lower A · Squat'), findsOneWidget);
    expect(find.text('Barbell back squat'), findsWidgets);
    expect(find.textContaining('Set 1 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warnings block the work until acknowledged', (tester) async {
    await open(tester, 'b-thu');
    // Deadlift day carries the bar-height warning.
    expect(find.textContaining('Bar height'), findsOneWidget);
    expect(find.textContaining('Read it'), findsOneWidget);

    await tester.tap(find.textContaining('Read it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Bar height'), findsNothing);
  });

  testWidgets('the load stepper starts at the prescribed weight', (
    tester,
  ) async {
    await open(tester, 'b-mon');
    // Squat starts at 21 kg on the lattice.
    expect(find.text('21'), findsWidgets);
    expect(find.text('kg'), findsWidgets);
  });

  testWidgets('logging a set records it and starts the rest timer', (
    tester,
  ) async {
    await open(tester, 'b-mon');

    expect(find.textContaining('0 / 25 sets'), findsOneWidget);

    await tester.tap(find.textContaining('Log set 1'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The set landed in the database.
    final sets = await db.select(db.setLogs).get();
    expect(sets, hasLength(1));
    expect(sets.single.exerciseId, 'barbell-back-squat');
    expect(sets.single.loadKg, 21.0);

    // And the rest timer is up.
    expect(find.text('RESTING'), findsOneWidget);
    expect(find.text('Skip rest'), findsOneWidget);
    expect(find.textContaining('Set 2 of 4'), findsOneWidget);
  });

  testWidgets('the reps stepper changes what gets logged', (tester) async {
    await open(tester, 'b-mon');

    // Squat is 4 x 5; bump to 6 reps.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.textContaining('Log set 1'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final sets = await db.select(db.setLogs).get();
    expect(sets.single.reps, 6);
  });

  testWidgets('skipping the rest clears the bar', (tester) async {
    await open(tester, 'b-mon');
    await tester.tap(find.textContaining('Log set 1'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('RESTING'), findsOneWidget);

    await tester.tap(find.text('Skip rest'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('RESTING'), findsNothing);
  });

  testWidgets('a per-side movement asks for a side', (tester) async {
    await open(tester, 'b-mon');
    // Bulgarian split squat is the third pill.
    await focusMovement(tester, 'Bulgarian split squat');
    expect(find.textContaining('left'), findsOneWidget);
    expect(find.textContaining('Log set 1 (L)'), findsOneWidget);
  });

  testWidgets('the first superset member logs without starting a rest', (
    tester,
  ) async {
    await open(tester, 'b-mon');
    await focusMovement(tester, 'Bulgarian split squat');
    await tester.tap(find.textContaining('Log set 1 (L)'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // You go straight to the right side, not into a rest.
    expect(find.text('RESTING'), findsNothing);
    expect(find.textContaining('Log set 1 (R)'), findsOneWidget);
  });

  testWidgets('a timed movement asks for seconds, not reps', (tester) async {
    await open(tester, 'b-sun');
    await focusMovement(tester, 'Heavy bag rounds');
    expect(find.textContaining('SECONDS'), findsOneWidget);
    expect(find.textContaining('REPS  ·'), findsNothing);
  });

  testWidgets('undo removes the set from the database', (tester) async {
    await open(tester, 'b-mon');
    await tester.tap(find.textContaining('Log set 1'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await db.select(db.setLogs).get(), hasLength(1));

    await tester.tap(find.textContaining('Undo last set'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await db.select(db.setLogs).get(), isEmpty);
  });

  testWidgets('reopening the day resumes rather than starting over', (
    tester,
  ) async {
    await open(tester, 'b-mon');
    await tester.tap(find.textContaining('Log set 1'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Tear the screen down as if the app had been killed, then reopen.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await open(tester, 'b-mon');

    expect(await db.select(db.sessions).get(), hasLength(1));
    expect(find.textContaining('Set 2 of 4'), findsOneWidget);
    expect(find.textContaining('1 / 25 sets'), findsOneWidget);
  });

  testWidgets('a deload day offers the deloaded weight', (tester) async {
    await open(tester, 'b-mon', week: 8);
    // 21 * 0.70 = 14.7
    expect(find.text('14.7'), findsWidgets);
  });

  group('the progression engine reaches the screen', () {
    testWidgets('a cold start says so and shows the plate breakdown', (
      tester,
    ) async {
      await open(tester, 'b-mon');
      expect(find.textContaining('Programme start'), findsOneWidget);
      // 21 kg = bar 9 + 6 per side
      expect(find.textContaining('bar 9'), findsOneWidget);
      expect(find.textContaining('per side'), findsOneWidget);
    });

    testWidgets('an earned jump is explained, not just applied', (
      tester,
    ) async {
      // Seed a clean session last week: every set at the top with RIR met.
      final session = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'build',
              dayId: 'b-mon',
              weekNo: 4,
              plannedDate: DateTime.now().subtract(const Duration(days: 7)),
              scheduledDate: DateTime.now().subtract(const Duration(days: 7)),
              status: const Value(SessionStatus.completed),
            ),
          );
      for (var i = 1; i <= 4; i++) {
        await db
            .into(db.setLogs)
            .insert(
              SetLogsCompanion.insert(
                sessionId: session,
                prescriptionId: 'b-mon-1',
                exerciseId: 'barbell-back-squat',
                setIndex: i,
                reps: const Value(5),
                loadKg: const Value(21),
                rir: const Value(2),
                targetRepsMin: const Value(5),
                targetRepsMax: const Value(5),
                completedAt: DateTime.now().subtract(const Duration(days: 7)),
              ),
            );
      }

      await open(tester, 'b-mon');
      expect(find.textContaining('Earned'), findsOneWidget);
      // 21 + 2.5 = 23.5, which is on the 0.5 kg lattice.
      expect(find.textContaining('23.5 kg'), findsWidgets);
    });

    testWidgets('a stall is explained rather than silently repeated', (
      tester,
    ) async {
      final session = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'build',
              dayId: 'b-mon',
              weekNo: 4,
              plannedDate: DateTime.now().subtract(const Duration(days: 7)),
              scheduledDate: DateTime.now().subtract(const Duration(days: 7)),
              status: const Value(SessionStatus.completed),
            ),
          );
      for (final reps in [5, 4, 3, 3]) {
        await db
            .into(db.setLogs)
            .insert(
              SetLogsCompanion.insert(
                sessionId: session,
                prescriptionId: 'b-mon-1',
                exerciseId: 'barbell-back-squat',
                setIndex: reps,
                reps: Value(reps),
                loadKg: const Value(21),
                rir: const Value(0),
                targetRepsMin: const Value(5),
                targetRepsMax: const Value(5),
                completedAt: DateTime.now().subtract(const Duration(days: 7)),
              ),
            );
      }

      await open(tester, 'b-mon');
      expect(find.textContaining('stall 1 of 2'), findsOneWidget);
    });
  });
}

class _SilentNotifications implements NotificationService {
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
  Future<void> cancelRest() async {}
  @override
  Future<void> cancelIntervals() async {}
  @override
  Future<void> cancelAll() async {}
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this._date);
  final DateTime _date;

  @override
  DateTime build() => DateTime(_date.year, _date.month, _date.day);
}
