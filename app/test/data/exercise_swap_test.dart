import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/suggestion_service.dart';
import 'package:keller_twelve/domain/models/prescription.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/programme/programme_editor.dart';

import '../support/fixtures.dart';

/// Phase 8.1: "swap an exercise, history preserved — `set_logs` keep their own
/// `exercise_id`, and the engine looks up by `exercise_id`, never by
/// prescription id. **Test this.**"
///
/// The failure this guards against is quiet and dangerous: swap Bulgarian
/// split squats for reverse lunges because your knee hurts, and the app
/// suggests the split squat's load for a movement you have never done.
void main() {
  const editor = ProgrammeEditor();
  final inventory = Fixtures.inventory;
  final programme = Fixtures.programme;

  late AppDatabase db;
  late SuggestionService suggestions;

  setUp(() {
    db = AppDatabase.memory();
    suggestions = SuggestionService(db: db, inventory: inventory);
  });

  tearDown(() => db.close());

  Future<void> logWork({
    required String prescriptionId,
    required String exerciseId,
    required double kg,
    required int reps,
    required DateTime on,
  }) async {
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: programme.id,
            blockId: 'build',
            dayId: 'b-sat',
            weekNo: 5,
            plannedDate: on,
            scheduledDate: on,
          ),
        );
    for (var i = 1; i <= 3; i++) {
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: sessionId,
              prescriptionId: prescriptionId,
              exerciseId: exerciseId,
              setIndex: i,
              completedAt: on,
            ).copyWith(reps: Value(reps), loadKg: Value(kg)),
          );
    }
  }

  Prescription find(Programme p, String id) => p.blocks
      .expand((b) => b.days)
      .expand((d) => d.sections)
      .expand((s) => s.prescriptions)
      .firstWhere((pre) => pre.id == id);

  test('the old movement keeps its logs after the swap', () async {
    final slot = find(programme, 'b-sat-3a');
    expect(slot.exerciseId, 'bulgarian-split-squat');

    await logWork(
      prescriptionId: 'b-sat-3a',
      exerciseId: 'bulgarian-split-squat',
      kg: 10,
      reps: 8,
      on: DateTime(2026, 11, 2),
    );

    final after = editor.swapExercise(programme, 'b-sat-3a', 'reverse-lunge');
    expect(find(after, 'b-sat-3a').exerciseId, 'reverse-lunge');

    // The logs are untouched — they carry their own exercise_id.
    final kept = await db.lastSetsForExercise('bulgarian-split-squat');
    expect(kept, hasLength(3));
    expect(kept.first.loadKg, 10);
    expect(kept.first.exerciseId, 'bulgarian-split-squat');
  });

  test('the new movement does not inherit the old load', () async {
    await logWork(
      prescriptionId: 'b-sat-3a',
      exerciseId: 'bulgarian-split-squat',
      kg: 10,
      reps: 8,
      on: DateTime(2026, 11, 2),
    );

    final after = editor.swapExercise(programme, 'b-sat-3a', 'reverse-lunge');
    final history = await suggestions.historyFor(find(after, 'b-sat-3a'));

    expect(
      history,
      isEmpty,
      reason:
          'the reverse lunge picked up the split squat history through the '
          'prescription id',
    );
  });

  test('a swap back finds the original history again', () async {
    await logWork(
      prescriptionId: 'b-sat-3a',
      exerciseId: 'bulgarian-split-squat',
      kg: 10,
      reps: 8,
      on: DateTime(2026, 11, 2),
    );

    final swapped = editor.swapExercise(programme, 'b-sat-3a', 'reverse-lunge');
    final back = editor.swapExercise(
      swapped,
      'b-sat-3a',
      'bulgarian-split-squat',
    );

    final history = await suggestions.historyFor(find(back, 'b-sat-3a'));
    expect(history, hasLength(3));
    expect(history.first.loadKg, 10);
  });

  test('the new movement finds its own history from another slot', () async {
    await logWork(
      prescriptionId: 'some-other-slot',
      exerciseId: 'reverse-lunge',
      kg: 14,
      reps: 10,
      on: DateTime(2026, 11, 5),
    );

    final after = editor.swapExercise(programme, 'b-sat-3a', 'reverse-lunge');
    final history = await suggestions.historyFor(find(after, 'b-sat-3a'));

    expect(history, hasLength(3));
    expect(history.first.loadKg, 14);
  });

  test('two slots of the same lift still do not drive each other', () async {
    await logWork(
      prescriptionId: 'f-thu-3b',
      exerciseId: 'goblet-squat',
      kg: 8,
      reps: 10,
      on: DateTime(2026, 11, 2),
    );
    await logWork(
      prescriptionId: 'b-thu-3b',
      exerciseId: 'goblet-squat',
      kg: 8,
      reps: 12,
      on: DateTime(2026, 11, 5),
    );

    final foundation = await suggestions.historyFor(
      find(programme, 'f-thu-3b'),
    );
    expect(
      foundation.first.reps,
      10,
      reason: 'the Foundation slot read the Build slot history',
    );
  });

  test('the swap clears the old opening load', () {
    expect(find(programme, 'b-sat-3a').startLoadKg, isNotNull);
    final after = editor.swapExercise(programme, 'b-sat-3a', 'reverse-lunge');
    expect(find(after, 'b-sat-3a').startLoadKg, isNull);
  });

  test('stall counters are keyed per exercise and prescription', () async {
    await db.setStall('bulgarian-split-squat', 'b-sat-3a', 2);
    final other = await db.stallFor('reverse-lunge', 'b-sat-3a');
    expect(
      other?.count ?? 0,
      0,
      reason: 'the new movement inherited a stall it never earned',
    );
  });
}
