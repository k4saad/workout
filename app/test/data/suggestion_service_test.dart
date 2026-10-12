import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/suggestion_service.dart';
import 'package:keller_twelve/domain/models/day.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/programme/block_resolver.dart';

import '../support/fixtures.dart';

/// The history the engine is handed decides everything it suggests. v2 handed
/// it the wrong history in two ways the coach found (review §0 item 3): the
/// deload week, and — mid-session — the session being run.
void main() {
  final programme = Fixtures.programme;
  final resolver = BlockResolver(programme);

  late AppDatabase db;
  late SuggestionService svc;

  setUp(() {
    db = AppDatabase.memory();
    svc = SuggestionService(
      db: db,
      inventory: Fixtures.inventory,
      programme: programme,
    );
  });
  tearDown(() => db.close());

  DateTime monday(int week) =>
      programme.anchorMonday.add(Duration(days: 7 * (week - 1)));

  Day day(String blockId, int week, String dayId) => resolver
      .resolveDays(programme.blockById(blockId)!, week)
      .firstWhere((d) => d.id == dayId);

  Prescription pres(String blockId, int week, String id) => resolver
      .resolveDays(programme.blockById(blockId)!, week)
      .expand((d) => d.allPrescriptions)
      .firstWhere((p) => p.id == id);

  Future<int> session(String blockId, int week, {String dayId = 'b-mon'}) => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          programmeId: programme.id,
          blockId: blockId,
          dayId: dayId,
          weekNo: week,
          plannedDate: monday(week),
          scheduledDate: monday(week),
          status: const Value(SessionStatus.completed),
        ),
      );

  /// Sets at the top of a 6-rep target, RIR met.
  Future<void> squats(
    int sessionId,
    int week, {
    required double kg,
    required int sets,
    int rir = 2,
    String prescriptionId = 'b-mon-1',
  }) async {
    for (var i = 1; i <= sets; i++) {
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: sessionId,
              prescriptionId: prescriptionId,
              exerciseId: 'barbell-back-squat',
              setIndex: i,
              reps: const Value(6),
              loadKg: Value(kg),
              rir: Value(rir),
              targetRepsMin: const Value(6),
              targetRepsMax: const Value(6),
              targetLoadKg: Value(kg),
              completedAt: monday(week).add(Duration(hours: 18, minutes: i)),
            ),
          );
    }
  }

  group('deload weeks are not history', () {
    test('week 9 progresses from week 7, not from the 70% week', () async {
      await squats(await session('build', 7), 7, kg: 25, sets: 3);
      await squats(await session('deload', 8), 8, kg: 18.5, sets: 3, rir: 4);

      final s = await svc.suggest(
        pres('push', 9, 'b-mon-1'),
        now: monday(9).add(const Duration(hours: 18)),
      );
      expect(s.suggestedKg, 27, reason: s.reason);
    });

    test('the fallback by exercise skips the deload too', () async {
      await squats(await session('build', 7), 7, kg: 25, sets: 3);
      await squats(await session('deload', 8), 8, kg: 18.5, sets: 3, rir: 4);

      // A prescription with no history of its own, e.g. after an edit.
      final renamed = pres('push', 9, 'b-mon-1').copyWith(id: 'b-mon-1-new');
      final history = await svc.historyFor(renamed);
      expect(history.map((s) => s.loadKg).toSet(), {25.0});
    });

    test('a 5RM test week is not training history either', () async {
      await squats(await session('build', 7), 7, kg: 25, sets: 3);
      await squats(
        await session('test', 12, dayId: 't-mon'),
        12,
        kg: 34,
        sets: 1,
        rir: 0,
        prescriptionId: 't-mon-1',
      );
      final history = await svc.historyFor(
        pres('push', 9, 'b-mon-1').copyWith(id: 'cycle-2-squat'),
      );
      expect(history.map((s) => s.loadKg).toSet(), {25.0});
    });
  });

  test('the session being run is not its own history', () async {
    await squats(await session('build', 7), 7, kg: 25, sets: 3);
    final today = await session('push', 9);
    // Two sets in, the app is killed and reopened.
    await squats(today, 9, kg: 27, sets: 2);

    final s = await svc.suggest(
      pres('push', 9, 'b-mon-1'),
      now: monday(9).add(const Duration(hours: 19)),
      excludeSessionId: today,
    );
    expect(s.suggestedKg, 27, reason: 'still one jump on from week 7');
  });

  group('forSession', () {
    test('suggests every logged movement, at the block multiplier', () async {
      await squats(await session('build', 7), 7, kg: 25, sets: 3);
      final deloadId = await session('deload', 8);
      final row = (await db.sessionById(deloadId))!;
      final tuesday8 = day('deload', 8, 'b-mon');

      final map = await svc.forSession(
        row,
        tuesday8,
        now: monday(8).add(const Duration(hours: 18)),
      );
      expect(
        map.keys.toSet(),
        tuesday8.loggedPrescriptions.map((p) => p.id).toSet(),
      );
      // One earned jump on from week 7 (25 -> 27), then the deload's 70%,
      // snapped down: 18.9 -> 18.5. Scaled once.
      expect(map['b-mon-1']!.suggestedKg, 18.5);
      expect(map['b-mon-1']!.reason.toLowerCase(), contains('deload'));
    });

    test('a cold start in the deload is not scaled twice', () async {
      final row = (await db.sessionById(await session('deload', 8)))!;
      final map = await svc.forSession(
        row,
        day('deload', 8, 'b-mon'),
        now: monday(8),
      );
      final start = pres('deload', 8, 'b-mon-1').startLoadKg!;
      expect(
        map['b-mon-1']!.suggestedKg,
        svc.solver
            .solve(start, pres('deload', 8, 'b-mon-1').loadMode)
            .achievableKg,
      );
    });
  });

  test('without a programme nothing is excluded (older callers)', () async {
    final plain = SuggestionService(db: db, inventory: Fixtures.inventory);
    await squats(await session('deload', 8), 8, kg: 18.5, sets: 3, rir: 4);
    final history = await plain.historyFor(pres('push', 9, 'b-mon-1'));
    expect(history, hasLength(3));
  });
}
