import 'package:collection/collection.dart';

/// One food as the packet states it, per 100 g.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.packG,
    this.note,
  });

  final String id;

  /// The German shelf name, because that is what is on the packet he is
  /// standing in front of.
  final String name;
  final String category;

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// The size it is sold in. A shopping list in grams is useless at the
  /// shelf; this is what turns 640 g of quark into two tubs.
  final int packG;

  final String? note;

  factory Food.fromJson(Map<String, dynamic> j) => Food(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['proteinG'] as num).toDouble(),
    carbsG: (j['carbsG'] as num).toDouble(),
    fatG: (j['fatG'] as num).toDouble(),
    packG: (j['packG'] as num).toInt(),
    note: j['note'] as String?,
  );
}

/// A weighed amount of one food.
class MealItem {
  const MealItem({required this.foodId, required this.grams});

  final String foodId;
  final double grams;

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
    foodId: j['foodId'] as String,
    grams: (j['grams'] as num).toDouble(),
  );
}

/// What a set of items adds up to.
class Macros {
  const Macros({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Macros operator +(Macros o) => Macros(
    kcal: kcal + o.kcal,
    proteinG: proteinG + o.proteinG,
    carbsG: carbsG + o.carbsG,
    fatG: fatG + o.fatG,
  );

  Macros scaled(double by) => Macros(
    kcal: kcal * by,
    proteinG: proteinG * by,
    carbsG: carbsG * by,
    fatG: fatG * by,
  );
}

/// One of the interchangeable meals for a slot.
class Meal {
  const Meal({
    required this.id,
    required this.slotId,
    required this.name,
    required this.items,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.note,
  });

  final String id;
  final String slotId;
  final String name;
  final String? note;
  final List<MealItem> items;

  /// Generated from the grams by `tools/gen_fuel.py`, never typed.
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Macros get macros => Macros(
    kcal: kcal.toDouble(),
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
  );

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
    id: j['id'] as String,
    slotId: j['slotId'] as String,
    name: j['name'] as String,
    note: j['note'] as String?,
    items: (j['items'] as List)
        .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num).toDouble(),
    carbsG: (j['carbsG'] as num).toDouble(),
    fatG: (j['fatG'] as num).toDouble(),
  );
}

/// When in the day a meal happens, and on which kind of day.
class MealSlot {
  const MealSlot({
    required this.id,
    required this.name,
    required this.time,
    required this.days,
    required this.kcal,
    required this.proteinG,
  });

  final String id;
  final String name;

  /// `HH:mm`, placed around an 18:30 session.
  final String time;

  /// `training`, `rest` or `both`.
  final String days;

  final int kcal;
  final int proteinG;

  bool appliesTo({required bool training}) =>
      days == 'both' || (training ? days == 'training' : days == 'rest');

  factory MealSlot.fromJson(Map<String, dynamic> j) => MealSlot(
    id: j['id'] as String,
    name: j['name'] as String,
    time: j['time'] as String,
    days: j['days'] as String,
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num).toInt(),
  );
}

/// An add-on: the phase step-ups, and the +250 when the scale stalls.
class FuelModule {
  const FuelModule({
    required this.id,
    required this.name,
    required this.kcal,
    required this.proteinG,
    required this.items,
    this.note,
  });

  final String id;
  final String name;
  final int kcal;
  final int proteinG;
  final String? note;
  final List<MealItem> items;

  factory FuelModule.fromJson(Map<String, dynamic> j) => FuelModule(
    id: j['id'] as String,
    name: j['name'] as String,
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num).toInt(),
    note: j['note'] as String?,
    items: (j['items'] as List)
        .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// The calorie target for a stretch of weeks.
class FuelPhase {
  const FuelPhase({
    required this.weeks,
    required this.kcal,
    required this.proteinG,
    this.moduleId,
  });

  final List<int> weeks;
  final int kcal;
  final int proteinG;
  final String? moduleId;

  bool covers(int week) => weeks.contains(week);

  factory FuelPhase.fromJson(Map<String, dynamic> j) => FuelPhase(
    weeks: (j['weeks'] as List).map((e) => (e as num).toInt()).toList(),
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num).toInt(),
    moduleId: j['moduleId'] as String?,
  );
}

class Supplement {
  const Supplement({
    required this.id,
    required this.name,
    required this.dose,
    required this.timing,
    required this.note,
  });

  final String id;
  final String name;
  final String dose;
  final String timing;
  final String note;

  factory Supplement.fromJson(Map<String, dynamic> j) => Supplement(
    id: j['id'] as String,
    name: j['name'] as String,
    dose: j['dose'] as String,
    timing: j['timing'] as String,
    note: j['note'] as String,
  );
}

class GuideEntry {
  const GuideEntry({required this.title, required this.body});

  final String title;
  final String body;

  factory GuideEntry.fromJson(Map<String, dynamic> j) =>
      GuideEntry(title: j['title'] as String, body: j['body'] as String);
}

/// One slot on one day: what is planned, and what else it could be.
class PlannedMeal {
  const PlannedMeal({
    required this.slot,
    required this.chosen,
    required this.choices,
  });

  final MealSlot slot;
  final Meal chosen;
  final List<Meal> choices;
}

/// One food to buy, and how many packets that is.
class GroceryLine {
  const GroceryLine({
    required this.food,
    required this.grams,
    required this.packs,
  });

  final Food food;
  final double grams;

  /// Rounded UP. Half a tub of quark is not a thing you can buy.
  final int packs;
}

/// A day of eating, resolved.
class FuelDay {
  const FuelDay({
    required this.plan,
    required this.weekNo,
    required this.isTrainingDay,
    required this.slots,
    required this.phase,
    required this.module,
    required this.extraKcal,
  });

  final FuelPlan plan;
  final int weekNo;
  final bool isTrainingDay;
  final List<PlannedMeal> slots;
  final FuelPhase? phase;

  /// The phase step-up, shown as real food rather than a number to add.
  final FuelModule? module;

  /// An adjustment he APPLIED — the +250 when the scale stalled. Carried
  /// separately so the UI can say where the extra came from.
  final int extraKcal;

  Macros get totals {
    var m = const Macros();
    for (final s in slots) {
      m = m + s.chosen.macros;
    }
    if (module != null) m = m + plan.macrosOf(module!.items);
    if (extraKcal > 0) {
      // An applied booster is calories he has agreed to add on top. It is not
      // modelled as food because he chooses how to take it.
      m = m + Macros(kcal: extraKcal.toDouble());
    }
    return m;
  }

  /// The same day with one slot swapped. Unknown ids are ignored — a stale
  /// choice saved against an edited plan must not throw mid-meal.
  FuelDay choosing(String slotId, String mealId) => FuelDay(
    plan: plan,
    weekNo: weekNo,
    isTrainingDay: isTrainingDay,
    phase: phase,
    module: module,
    extraKcal: extraKcal,
    slots: [
      for (final s in slots)
        if (s.slot.id != slotId)
          s
        else
          PlannedMeal(
            slot: s.slot,
            chosen:
                s.choices.firstWhereOrNull((c) => c.id == mealId) ?? s.chosen,
            choices: s.choices,
          ),
    ],
  );

  /// The next meal due at [time], or the first of tomorrow when the day is
  /// done. Drives the card on Today.
  PlannedMeal? nextAfter(String time) =>
      slots.firstWhereOrNull((s) => s.slot.time.compareTo(time) >= 0);
}

/// The eating plan: `assets/nutrition/fuel.json`, generated.
///
/// Pure Dart, no I/O — handed the decoded JSON so it can be tested without a
/// device, like everything else in `lib/domain/`.
class FuelPlan {
  FuelPlan({
    required this.foods,
    required this.slots,
    required this.meals,
    required this.modules,
    required this.phases,
    required this.supplements,
    required this.buyingGuide,
    required this.hydrationMl,
    required this.trainingExtraMl,
    this.hydrationNote,
  }) : _foodById = {for (final f in foods) f.id: f};

  final List<Food> foods;
  final List<MealSlot> slots;
  final List<Meal> meals;
  final List<FuelModule> modules;
  final List<FuelPhase> phases;
  final List<Supplement> supplements;
  final List<GuideEntry> buyingGuide;
  final int hydrationMl;
  final int trainingExtraMl;
  final String? hydrationNote;

  final Map<String, Food> _foodById;

  Food? food(String id) => _foodById[id];

  FuelPhase? phaseForWeek(int week) {
    final exact = phases.firstWhereOrNull((p) => p.covers(week));
    if (exact != null) return exact;
    // Week 13 arrives the day the programme ends. Carrying the last phase
    // forward beats showing him an empty plate.
    return phases.isEmpty ? null : (week < 1 ? phases.first : phases.last);
  }

  FuelModule? module(String id) => modules.firstWhereOrNull((m) => m.id == id);

  Macros macrosOf(List<MealItem> items) {
    var m = const Macros();
    for (final i in items) {
      final f = _foodById[i.foodId];
      if (f == null) continue;
      m =
          m +
          Macros(
            kcal: f.kcal * i.grams / 100,
            proteinG: f.proteinG * i.grams / 100,
            carbsG: f.carbsG * i.grams / 100,
            fatG: f.fatG * i.grams / 100,
          );
    }
    return m;
  }

  List<Meal> mealsFor(String slotId) =>
      meals.where((m) => m.slotId == slotId).toList();

  /// The day's plan.
  ///
  /// [extraKcal] is an adjustment he has APPLIED and that is still standing —
  /// v2 recomputed the bump on every read and stored nothing, so the moment it
  /// worked the target silently fell back to where it had stalled.
  FuelDay forDay({
    required int weekNo,
    required bool isTrainingDay,
    int extraKcal = 0,
    Map<String, String> chosen = const {},
  }) {
    final phase = phaseForWeek(weekNo);
    final mod = phase?.moduleId == null ? null : module(phase!.moduleId!);

    final applicable =
        slots.where((s) => s.appliesTo(training: isTrainingDay)).toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    return FuelDay(
      plan: this,
      weekNo: weekNo,
      isTrainingDay: isTrainingDay,
      phase: phase,
      module: mod,
      extraKcal: extraKcal,
      slots: [
        for (final s in applicable)
          if (mealsFor(s.id).isNotEmpty)
            () {
              final options = mealsFor(s.id);
              final pick = chosen[s.id];
              return PlannedMeal(
                slot: s,
                choices: options,
                chosen:
                    options.firstWhereOrNull((m) => m.id == pick) ??
                    options.first,
              );
            }(),
      ],
    );
  }

  /// Everything a set of days needs, by food, rounded up to whole packets and
  /// ordered by category so the list walks the aisles rather than zig-zagging.
  List<GroceryLine> groceries(List<FuelDay> days) {
    final grams = <String, double>{};
    void add(List<MealItem> items) {
      for (final i in items) {
        grams[i.foodId] = (grams[i.foodId] ?? 0) + i.grams;
      }
    }

    for (final d in days) {
      for (final s in d.slots) {
        add(s.chosen.items);
      }
      if (d.module != null) add(d.module!.items);
    }

    final lines = <GroceryLine>[];
    grams.forEach((id, g) {
      final f = _foodById[id];
      if (f == null || g <= 0) return;
      lines.add(GroceryLine(food: f, grams: g, packs: (g / f.packG).ceil()));
    });
    lines.sort((a, b) {
      final c = a.food.category.compareTo(b.food.category);
      return c != 0 ? c : a.food.name.compareTo(b.food.name);
    });
    return lines;
  }

  factory FuelPlan.fromJson(Map<String, dynamic> j) {
    final hydration = (j['hydration'] as Map?)?.cast<String, dynamic>() ?? {};
    return FuelPlan(
      foods: (j['foods'] as List)
          .map((e) => Food.fromJson(e as Map<String, dynamic>))
          .toList(),
      slots: (j['slots'] as List)
          .map((e) => MealSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      meals: (j['meals'] as List)
          .map((e) => Meal.fromJson(e as Map<String, dynamic>))
          .toList(),
      modules: (j['modules'] as List? ?? const [])
          .map((e) => FuelModule.fromJson(e as Map<String, dynamic>))
          .toList(),
      phases: (j['phases'] as List? ?? const [])
          .map((e) => FuelPhase.fromJson(e as Map<String, dynamic>))
          .toList(),
      supplements: (j['supplements'] as List? ?? const [])
          .map((e) => Supplement.fromJson(e as Map<String, dynamic>))
          .toList(),
      buyingGuide: (j['buyingGuide'] as List? ?? const [])
          .map((e) => GuideEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      hydrationMl: (hydration['dailyMl'] as num?)?.toInt() ?? 3000,
      trainingExtraMl: (hydration['trainingExtraMl'] as num?)?.toInt() ?? 700,
      hydrationNote: hydration['note'] as String?,
    );
  }
}
