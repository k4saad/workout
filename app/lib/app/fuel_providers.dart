import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../data/fuel_service.dart';
import '../domain/fuel/fuel_plan.dart';
import 'providers.dart';
import 'session_providers.dart';

final fuelServiceProvider = Provider<FuelService>(
  (ref) => FuelService(ref.watch(databaseProvider)),
);

/// Which meal was chosen for each slot today, when it differs from the
/// default. Swapping is a per-day decision, so it lives with the day's logs.
final chosenMealsProvider =
    FutureProvider.family<Map<String, String>, DateTime>((ref, day) async {
      final rows = await ref.watch(fuelServiceProvider).mealsOn(day);
      return {for (final r in rows) r.slotId: r.templateId};
    });

/// How each slot on [day] was logged: eaten, half, skipped or just chosen.
/// What the meal cards' buttons and Today's next-meal card read.
final mealStatusProvider =
    FutureProvider.family<Map<String, MealStatus>, DateTime>((ref, day) async {
      final rows = await ref.watch(fuelServiceProvider).mealsOn(day);
      return {for (final r in rows) r.slotId: r.status};
    });

/// Calories he has APPLIED and not reverted, in force on [day].
final extraKcalProvider = FutureProvider.family<int, DateTime>(
  (ref, day) => ref.watch(fuelServiceProvider).appliedExtraKcal(on: day),
);

/// The plan for one date: the right phase, the right kind of day, his swaps
/// and his adjustments already folded in.
final fuelDayProvider = FutureProvider.family<FuelDay, DateTime>((
  ref,
  day,
) async {
  final plan = await ref.watch(fuelPlanProvider.future);
  final bundle = await ref.watch(bundleProvider.future);
  final planned = bundle.calendar.forDate(day);

  return plan.forDay(
    // Before the programme starts, and after it ends, eat like week one and
    // week twelve respectively rather than seeing nothing.
    weekNo: (planned.weekNo ?? 1).clamp(1, bundle.programme.totalWeeks),
    isTrainingDay: planned.day?.isTrainingDay ?? false,
    extraKcal: await ref.watch(extraKcalProvider(day).future),
    chosen: await ref.watch(chosenMealsProvider(day).future),
    weekday: day.weekday,
  );
});

/// The seven days from [monday]: what the Plan lays out, cooks ahead for
/// and shops for. Each day is [fuelDayProvider], so a swap on one day
/// refreshes the week.
final fuelWeekProvider = FutureProvider.family<List<FuelDay>, DateTime>((
  ref,
  monday,
) async {
  return [
    for (var i = 0; i < 7; i++)
      await ref.watch(
        fuelDayProvider(DateTime(monday.year, monday.month, monday.day + i))
            .future,
      ),
  ];
});

/// What has actually been eaten today.
final eatenTodayProvider = FutureProvider.family<EatenMacros, DateTime>(
  (ref, day) => ref.watch(fuelServiceProvider).eatenOn(day),
);

final waterTodayProvider = FutureProvider.family<int, DateTime>(
  (ref, day) => ref.watch(fuelServiceProvider).waterOn(day),
);

final supplementsTodayProvider = FutureProvider.family<Set<String>, DateTime>(
  (ref, day) => ref.watch(fuelServiceProvider).supplementsOn(day),
);

/// The last fortnight, which is what gates the "eat more" advice.
final fuelAdherenceProvider = FutureProvider<FuelAdherence>((ref) async {
  final today = ref.watch(todayProvider);
  return ref
      .watch(fuelServiceProvider)
      .adherence(
        from: DateTime(today.year, today.month, today.day - 13),
        to: today,
      );
});

final openAdjustmentsProvider = FutureProvider<List<NutritionAdjustment>>(
  (ref) => ref.watch(fuelServiceProvider).openAdjustments(),
);

/// The day the food last changed: an adjustment applied, or one taken off.
/// The flat rule gives a change its weeks on the scale from here.
final lastCalorieChangeProvider = FutureProvider<DateTime?>((ref) async {
  DateTime? last;
  for (final a in await ref.watch(fuelServiceProvider).allAdjustments()) {
    for (final d in [a.appliedOn, a.revertedOn]) {
      if (d != null && (last == null || d.isAfter(last))) last = d;
    }
  }
  return last;
});

/// Applies and takes off the calorie changes the Body page advises.
class AdjustmentController {
  const AdjustmentController(this.ref);

  final Ref ref;

  /// Records a change he agreed to, from [on]. When the Fuel plan has a
  /// booster of exactly that size (not a phase step), it is named, so Fuel
  /// can show the change as food rather than as a number.
  Future<void> apply({
    required DateTime on,
    required int kcalDelta,
    required String reason,
  }) async {
    final plan = await ref.read(fuelPlanProvider.future);
    final phaseModules = {for (final p in plan.phases) p.moduleId};
    final booster = plan.modules.firstWhereOrNull(
      (m) => m.kcal == kcalDelta && !phaseModules.contains(m.id),
    );
    await ref
        .read(fuelServiceProvider)
        .applyAdjustment(
          on: on,
          kcalDelta: kcalDelta,
          reason: reason,
          moduleId: booster?.id,
        );
    _refresh();
  }

  Future<void> takeOff(int id, {required DateTime on}) async {
    await ref.read(fuelServiceProvider).revertAdjustment(id, on: on);
    _refresh();
  }

  void _refresh() {
    ref
      ..invalidate(extraKcalProvider)
      ..invalidate(fuelDayProvider)
      ..invalidate(fuelWeekProvider)
      ..invalidate(openAdjustmentsProvider)
      ..invalidate(lastCalorieChangeProvider);
  }
}

final adjustmentControllerProvider = Provider(AdjustmentController.new);

/// Records a decision about one meal and refreshes the day.
class MealLogController {
  const MealLogController(this.ref);

  final Ref ref;

  Future<void> log({
    required DateTime day,
    required PlannedMeal slot,
    required MealStatus status,
  }) async {
    final m = slot.chosen;
    await ref
        .read(fuelServiceProvider)
        .logMeal(
          on: day,
          slotId: slot.slot.id,
          templateId: m.id,
          status: status,
          macros: (
            kcal: m.kcal.toDouble(),
            proteinG: m.proteinG,
            carbsG: m.carbsG,
            fatG: m.fatG,
          ),
        );
    _refresh(day);
  }

  /// Swapping is recorded as `planned`: chosen, not yet eaten. Counting it as
  /// eaten would make every morning look like a day already won.
  Future<void> swap({
    required DateTime day,
    required PlannedMeal slot,
    required Meal to,
  }) async {
    await ref
        .read(fuelServiceProvider)
        .logMeal(
          on: day,
          slotId: slot.slot.id,
          templateId: to.id,
          status: MealStatus.planned,
          macros: (
            kcal: to.kcal.toDouble(),
            proteinG: to.proteinG,
            carbsG: to.carbsG,
            fatG: to.fatG,
          ),
        );
    _refresh(day);
  }

  Future<void> water(DateTime day, int ml) async {
    await ref.read(fuelServiceProvider).addWater(day, ml);
    ref.invalidate(waterTodayProvider(day));
  }

  Future<void> supplement(
    DateTime day,
    String id, {
    required bool taken,
  }) async {
    await ref.read(fuelServiceProvider).setSupplement(day, id, taken: taken);
    ref.invalidate(supplementsTodayProvider(day));
  }

  void _refresh(DateTime day) {
    ref
      ..invalidate(chosenMealsProvider(day))
      ..invalidate(mealStatusProvider(day))
      ..invalidate(eatenTodayProvider(day))
      ..invalidate(fuelDayProvider(day))
      ..invalidate(fuelAdherenceProvider);
  }
}

final mealLogControllerProvider = Provider(MealLogController.new);
