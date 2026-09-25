import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/metrics/session_summary.dart';

/// The numbers on the screen that ends a session.
void main() {
  final start = DateTime(2026, 10, 19, 18, 5);

  SummarySet set(
    String ex, {
    double? kg,
    int? reps,
    int? seconds,
    bool warmup = false,
  }) => (
    exerciseId: ex,
    loadKg: kg,
    reps: reps,
    durationSec: seconds,
    warmup: warmup,
  );

  test('counts working sets and movements, not warm-ups', () {
    final s = SessionSummary.of(
      sets: [
        set('squat', kg: 20, reps: 5, warmup: true),
        set('squat', kg: 40, reps: 8),
        set('squat', kg: 40, reps: 7),
        set('row', kg: 30, reps: 10),
      ],
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 47)),
    );
    expect(s.workingSets, 3);
    expect(s.movements, 2);
  });

  test(
    'kilos lifted is load times reps; bodyweight and timed sets add none',
    () {
      final s = SessionSummary.of(
        sets: [
          set('squat', kg: 40, reps: 8),
          set('squat', kg: 42.5, reps: 6),
          set('pull-up', reps: 5),
          set('plank', seconds: 45),
          set('squat', kg: 20, reps: 5, warmup: true),
        ],
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 30)),
      );
      expect(s.volumeKg, closeTo(40 * 8 + 42.5 * 6, 1e-9));
      expect(s.workingSets, 4);
    },
  );

  test('the time is start to finish', () {
    final s = SessionSummary.of(
      sets: const [],
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 52, seconds: 40)),
    );
    expect(s.duration, const Duration(minutes: 52, seconds: 40));
  });

  test(
    'no time for a session logged from memory, or one left open overnight',
    () {
      expect(
        SessionSummary.of(
          sets: const [],
          startedAt: null,
          finishedAt: start,
        ).duration,
        isNull,
      );
      expect(
        SessionSummary.of(
          sets: const [],
          startedAt: start,
          finishedAt: start.add(const Duration(hours: 13)),
        ).duration,
        isNull,
      );
    },
  );
}
