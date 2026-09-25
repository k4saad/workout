import 'package:drift/drift.dart';

import 'db/database.dart';
import 'db/tables.dart';

/// What a set of logged meals actually delivered.
typedef EatenMacros = ({
  double kcal,
  double proteinG,
  double carbsG,
  double fatG,
});

/// How much of the plan was actually eaten.
class FuelAdherence {
  const FuelAdherence({required this.planned, required this.eaten});

  /// Meals logged at all — planned meals he made a decision about.
  final int planned;

  /// Counting a half as a half. Eating half a meal is not the same as
  /// skipping it, and a plan that scores them the same teaches nothing.
  final double eaten;

  double get rate => planned == 0 ? 0 : eaten / planned;
  int get percent => (rate * 100).round();

  /// The threshold the "eat more" advice is gated on. Below this the answer
  /// is not more calories, it is the calories already planned.
  static const goodEnough = 0.85;

  bool get isFollowingThePlan => rate >= goodEnough;
}

/// Meals, water, supplements, and the calorie adjustments he has applied.
class FuelService {
  FuelService(this.db);

  final AppDatabase db;

  static DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  // ------------------------------------------------------------- meals ----

  /// Records a decision about one slot.
  ///
  /// Keyed on (date, slot), so logging the same slot again CORRECTS it. The
  /// alternative — appending — double-counts the moment he taps "eaten" after
  /// having tapped "half".
  Future<void> logMeal({
    required DateTime on,
    required String slotId,
    required String templateId,
    required MealStatus status,
    required EatenMacros macros,
    String? note,
  }) => db
      .into(db.mealLogs)
      .insertOnConflictUpdate(
        MealLogsCompanion.insert(
          loggedOn: _d(on),
          slotId: slotId,
          templateId: templateId,
          status: status,
          portion: Value(status.portion),
          kcal: Value(macros.kcal.round()),
          proteinG: Value(macros.proteinG),
          carbsG: Value(macros.carbsG),
          fatG: Value(macros.fatG),
          loggedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
          note: Value(note),
        ),
      );

  Future<List<MealLog>> mealsOn(DateTime day) =>
      (db.select(db.mealLogs)..where((m) => m.loggedOn.equals(_d(day)))).get();

  /// What was eaten, scaled by the portion. A skipped meal contributes
  /// nothing; a half contributes half.
  Future<EatenMacros> eatenOn(DateTime day) async {
    final rows = await mealsOn(day);
    var kcal = 0.0, p = 0.0, c = 0.0, f = 0.0;
    for (final r in rows) {
      kcal += r.kcal * r.portion;
      p += r.proteinG * r.portion;
      c += r.carbsG * r.portion;
      f += r.fatG * r.portion;
    }
    return (kcal: kcal, proteinG: p, carbsG: c, fatG: f);
  }

  Future<void> clearMeal(DateTime day, String slotId) => (db.delete(
    db.mealLogs,
  )..where((m) => m.loggedOn.equals(_d(day)) & m.slotId.equals(slotId))).go();

  // ------------------------------------------------------------- water ----

  Future<int> waterOn(DateTime day) async {
    final row = await (db.select(
      db.waterLogs,
    )..where((w) => w.loggedOn.equals(_d(day)))).getSingleOrNull();
    return row?.ml ?? 0;
  }

  /// Adds [ml] to the day. Negative undoes a mis-tap; the total never goes
  /// below zero.
  Future<void> addWater(DateTime day, int ml) async {
    final next = (await waterOn(day)) + ml;
    await db
        .into(db.waterLogs)
        .insertOnConflictUpdate(
          WaterLogsCompanion.insert(
            loggedOn: _d(day),
            ml: Value(next < 0 ? 0 : next),
          ),
        );
  }

  // -------------------------------------------------------- supplements ----

  Future<Set<String>> supplementsOn(DateTime day) async {
    final rows = await (db.select(
      db.supplementLogs,
    )..where((s) => s.loggedOn.equals(_d(day)))).get();
    return {for (final r in rows) r.supplementId};
  }

  Future<void> setSupplement(
    DateTime day,
    String supplementId, {
    required bool taken,
  }) async {
    if (!taken) {
      await (db.delete(db.supplementLogs)..where(
            (s) =>
                s.loggedOn.equals(_d(day)) &
                s.supplementId.equals(supplementId),
          ))
          .go();
      return;
    }
    await db
        .into(db.supplementLogs)
        .insertOnConflictUpdate(
          SupplementLogsCompanion.insert(
            loggedOn: _d(day),
            supplementId: supplementId,
            takenAtMs: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  // ---------------------------------------------------------- adherence ----

  Future<FuelAdherence> adherence({
    required DateTime from,
    required DateTime to,
  }) async {
    final logged = await (db.select(
      db.mealLogs,
    )..where((m) => m.loggedOn.isBetweenValues(_d(from), _d(to)))).get();
    // A swap is recorded as `planned`: a choice of meal, not a decision
    // about eating it. Counted, a week swapped ahead on the Plan would read
    // as a week of missed meals.
    final rows = [
      for (final r in logged)
        if (r.status != MealStatus.planned) r,
    ];
    var eaten = 0.0;
    for (final r in rows) {
      eaten += r.portion;
    }
    return FuelAdherence(planned: rows.length, eaten: eaten);
  }

  // -------------------------------------------------------- adjustments ----

  /// Records a calorie change he has AGREED to, from [on] until it is
  /// reverted.
  ///
  /// This table is the fix for v2's worst nutrition bug. The +250 was derived
  /// on every read from "has the rolling average been flat for two weeks?",
  /// and stored nowhere. So it applied, the weight started moving, the
  /// condition stopped being true, and the extra 250 kcal silently vanished —
  /// at which point the weight stalled again and the whole loop repeated. An
  /// adjustment is a decision, and decisions are stored.
  Future<int> applyAdjustment({
    required DateTime on,
    required int kcalDelta,
    required String reason,
    String? moduleId,
  }) => db
      .into(db.nutritionAdjustments)
      .insert(
        NutritionAdjustmentsCompanion.insert(
          appliedOn: _d(on),
          kcalDelta: kcalDelta,
          reason: reason,
          moduleId: Value(moduleId),
        ),
      );

  Future<void> revertAdjustment(int id, {required DateTime on}) =>
      (db.update(db.nutritionAdjustments)..where((a) => a.id.equals(id))).write(
        NutritionAdjustmentsCompanion(revertedOn: Value(_d(on))),
      );

  /// Every adjustment ever made, standing or taken off.
  Future<List<NutritionAdjustment>> allAdjustments() =>
      db.select(db.nutritionAdjustments).get();

  /// Everything still standing, so the UI can show what is being added and
  /// let him take it back.
  Future<List<NutritionAdjustment>> openAdjustments() =>
      (db.select(db.nutritionAdjustments)
            ..where((a) => a.revertedOn.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.appliedOn)]))
          .get();

  /// The calories in force on [on]: applied on or before that day, and either
  /// never reverted or reverted after it.
  Future<int> appliedExtraKcal({required DateTime on}) async {
    final day = _d(on);
    final rows = await db.select(db.nutritionAdjustments).get();
    var total = 0;
    for (final a in rows) {
      if (a.appliedOn.isAfter(day)) continue;
      final rev = a.revertedOn;
      if (rev != null && !rev.isAfter(day)) continue;
      total += a.kcalDelta;
    }
    return total;
  }
}
