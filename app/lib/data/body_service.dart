import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../domain/metrics/bodyweight_trend.dart';
import 'db/database.dart';
import 'db/tables.dart';

/// Bodyweight, food and cardio logging.
class BodyService {
  BodyService(this.db);

  final AppDatabase db;

  Future<List<WeightEntry>> weightHistory() async {
    final rows = await db.bodyweightHistory();
    return rows.map((r) => WeightEntry(date: r.measuredOn, kg: r.kg)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Waist change from the first measurement to the latest.
  ///
  /// The counterweight to the flat rule: gaining is the goal, but not if it
  /// is mostly going on the waist.
  Future<double?> waistChangeCm() async {
    final rows = await db.measurementsFor(MeasurementSite.waist);
    if (rows.length < 2) return null;
    return rows.last.cm - rows.first.cm;
  }

  Future<FoodLog?> foodFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return (db.select(
      db.foodLogs,
    )..where((f) => f.loggedOn.equals(d))).getSingleOrNull();
  }

  Future<void> logFood(
    DateTime date, {
    required bool hitTarget,
    int? kcal,
    int? proteinG,
    String? note,
  }) {
    final d = DateTime(date.year, date.month, date.day);
    return db
        .into(db.foodLogs)
        .insertOnConflictUpdate(
          FoodLogsCompanion.insert(
            loggedOn: d,
            hitTarget: Value(hitTarget),
            kcal: Value(kcal),
            proteinG: Value(proteinG),
            note: Value(note),
          ),
        );
  }

  /// Consecutive days up to [today] on which the target was hit.
  ///
  /// Today only counts once it has been ticked, so the streak never claims a
  /// day that has not finished yet.
  Future<int> foodStreak(DateTime today) async {
    final rows = await db.select(db.foodLogs).get();
    final byDate = {for (final r in rows) _key(r.loggedOn): r};

    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    for (var i = 0; i < 400; i++) {
      final row = byDate[_key(cursor)];
      if (row == null || !row.hitTarget) break;
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> logCardio({
    required CardioKind kind,
    required DateTime on,
    int? durationSec,
    int? distanceM,
    int? rounds,
    int? effort,
    int? sessionId,
    String? note,
  }) => db
      .into(db.cardioLogs)
      .insert(
        CardioLogsCompanion.insert(
          kind: kind,
          measuredOn: DateTime(on.year, on.month, on.day),
          durationSec: Value(durationSec),
          distanceM: Value(distanceM),
          rounds: Value(rounds),
          effort: Value(effort),
          sessionId: Value(sessionId),
          note: Value(note),
        ),
      );

  Future<List<CardioLog>> recentCardio({int limit = 60}) =>
      (db.select(db.cardioLogs)
            ..orderBy([(c) => OrderingTerm.desc(c.measuredOn)])
            ..limit(limit))
          .get();

  /// Total running minutes in a date range, for the cardio summary.
  Future<int> runningMinutes(DateTime from, DateTime to) async {
    final rows = await db.select(db.cardioLogs).get();
    final seconds = rows
        .where(
          (r) =>
              r.kind == CardioKind.run &&
              !r.measuredOn.isBefore(from) &&
              !r.measuredOn.isAfter(to),
        )
        .fold<int>(0, (a, r) => a + (r.durationSec ?? 0));
    return seconds ~/ 60;
  }
}
