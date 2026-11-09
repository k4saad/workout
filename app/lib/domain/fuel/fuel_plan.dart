import 'package:collection/collection.dart';

/// The Monday of [d]'s week, at midnight: the week a plan is shopped for.
DateTime mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - d.weekday + 1);

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
    this.priceEurPerKg = 0,
    this.keeps = false,
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

  /// A discounter shelf price, estimated by the generator — enough to plan a
  /// student's week by, not a receipt.
  final double priceEurPerKg;

  /// Keeps for weeks — dry, tinned, bottled or frozen — so it is bought when
  /// it runs out, not every week.
  final bool keeps;

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
    priceEurPerKg: (j['priceEurPerKg'] as num?)?.toDouble() ?? 0,
    keeps: j['keeps'] as bool? ?? false,
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
    this.costEur = 0,
    this.protein,
    this.batch = false,
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

  /// What its food costs, at the generator's shelf prices.
  final double costEur;

  /// The main protein it is built around — `chicken`, `fish`, `mince`,
  /// `legumes`, `eggs` — or null for the dairy-and-oats backbone.
  final String? protein;

  /// Cooked on a prep night and eaten from the fridge.
  final bool batch;

  /// The mains that cost money: a day should buy one of these, not two.
  static const meatOrFish = {'chicken', 'fish', 'mince'};

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
    costEur: (j['costEur'] as num?)?.toDouble() ?? 0,
    protein: j['protein'] as String?,
    batch: j['batch'] as bool? ?? false,
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
    this.aroundSession = false,
  });

  final String id;
  final String name;

  /// `HH:mm`, placed around the day: the timetable and an evening session.
  final String time;

  /// On a training day, the meal that fuels the session — Fuel marks it.
  final bool aroundSession;

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
    aroundSession: j['aroundSession'] as bool? ?? false,
  );
}

/// An add-on: the booster when the scale stalls.
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

/// The default meals for one weekday: one main protein for lunch and
/// dinner, so it is bought and cooked once.
class RotationDay {
  const RotationDay({
    required this.weekday,
    required this.theme,
    required this.meals,
  });

  /// [DateTime.monday] (1) to [DateTime.sunday] (7).
  final int weekday;

  /// What the day is built around: "Chicken", "Lentils".
  final String theme;

  /// Slot id to meal id.
  final Map<String, String> meals;

  factory RotationDay.fromJson(Map<String, dynamic> j) => RotationDay(
    weekday: (j['weekday'] as num).toInt(),
    theme: j['theme'] as String,
    meals: (j['meals'] as Map).cast<String, String>(),
  );
}

/// One evening of cooking ahead.
class PrepSession {
  const PrepSession({
    required this.cookOn,
    required this.label,
    required this.covers,
  });

  /// The weekday it is cooked on.
  final int cookOn;
  final String label;

  /// The weekdays it feeds.
  final List<int> covers;

  factory PrepSession.fromJson(Map<String, dynamic> j) => PrepSession(
    cookOn: (j['cookOn'] as num).toInt(),
    label: j['label'] as String,
    covers: [for (final d in j['covers'] as List) (d as num).toInt()],
  );
}

/// How the week is cooked ahead: when, for which days, and which foods are
/// worth cooking in bulk.
class PrepPlan {
  const PrepPlan({
    required this.keepsDays,
    required this.sessions,
    required this.foods,
  });

  /// How long cooked food keeps in the fridge.
  final int keepsDays;
  final List<PrepSession> sessions;

  /// The foods a prep night cooks: the proteins and the starches. The salad
  /// is cut on the day.
  final Set<String> foods;

  factory PrepPlan.fromJson(Map<String, dynamic> j) => PrepPlan(
    keepsDays: (j['keepsDays'] as num).toInt(),
    sessions: [
      for (final s in j['sessions'] as List)
        PrepSession.fromJson(s as Map<String, dynamic>),
    ],
    foods: {for (final f in j['foods'] as List) f as String},
  );
}

/// What a student can spend on food.
class FuelBudget {
  const FuelBudget({
    required this.eurPerDay,
    required this.eurPerWeek,
    this.note,
  });

  final double eurPerDay;
  final double eurPerWeek;
  final String? note;

  factory FuelBudget.fromJson(Map<String, dynamic> j) => FuelBudget(
    eurPerDay: (j['eurPerDay'] as num).toDouble(),
    eurPerWeek: (j['eurPerWeek'] as num).toDouble(),
    note: j['note'] as String?,
  );
}

/// One meal a prep night cooks for.
class PrepMeal {
  const PrepMeal({required this.date, required this.slot, required this.meal});

  final DateTime date;
  final MealSlot slot;
  final Meal meal;
}

/// One food to cook, and how much of it — weighed as the meal weighs it
/// (rice, lentils and pasta dry).
class PrepItem {
  const PrepItem({required this.food, required this.grams});

  final Food food;
  final double grams;
}

/// A prep night, resolved against the meals actually chosen.
class PrepNight {
  const PrepNight({
    required this.session,
    required this.cookDate,
    required this.meals,
    required this.cook,
  });

  final PrepSession session;
  final DateTime cookDate;
  final List<PrepMeal> meals;
  final List<PrepItem> cook;
}

/// One slot on one day: what is planned, and what else it could be.
/// When a meal is eaten on one particular day, from the day planner: the
/// slot's time is only a target, and a 07:00 shift moves breakfast.
class MealTiming {
  const MealTiming({
    required this.time,
    this.packed = false,
    this.quick = false,
    this.takeAlong = false,
    this.sessionFuel = false,
  });

  /// `HH:mm`.
  final String time;

  /// Nowhere free to eat it but a shift: take it to work.
  final bool packed;

  /// Squeezed into a short gap.
  final bool quick;

  /// Eaten on a break in his study away from home: take it with you.
  final bool takeAlong;

  /// The last meal before the session.
  final bool sessionFuel;
}

class PlannedMeal {
  const PlannedMeal({
    required this.slot,
    required this.chosen,
    required this.choices,
    this.timing,
  });

  final MealSlot slot;
  final Meal chosen;
  final List<Meal> choices;

  /// Today's timing, when the day was planned; the slot's target otherwise.
  final MealTiming? timing;

  /// `HH:mm`: when it is eaten today.
  String get time => timing?.time ?? slot.time;
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

  /// What those whole packets cost at the till.
  double get costEur => packs * food.packG / 1000 * food.priceEurPerKg;

  /// How many of these days one packet covers — for a week's list, how
  /// many weeks a packet of cupboard food lasts.
  double get packLastsWeeks => grams <= 0 ? 0 : food.packG / grams;
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
    this.weekday,
  });

  final FuelPlan plan;
  final int weekNo;
  final bool isTrainingDay;

  /// Which day of the week it is, when known: it picks the default meals.
  final int? weekday;
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
    if (extraKcal != 0) {
      // An applied change is calories he has agreed to add on top (or, for
      // the waist rule, take off). It is not modelled as food because he
      // chooses how to take it.
      m = m + Macros(kcal: extraKcal.toDouble());
    }
    return m;
  }

  /// What the day's food costs, module included.
  double get costEur =>
      slots.fold<double>(0, (a, s) => a + s.chosen.costEur) +
      (module == null ? 0 : plan.costOf(module!.items));

  /// The meat and fish the day's meals are built around. More than one is
  /// two things to buy and cook.
  Set<String> get meatOrFish => {
    for (final s in slots)
      if (s.chosen.protein case final p? when Meal.meatOrFish.contains(p)) p,
  };

  /// The same day with one slot swapped. Unknown ids are ignored — a stale
  /// choice saved against an edited plan must not throw mid-meal.
  FuelDay choosing(String slotId, String mealId) => FuelDay(
    plan: plan,
    weekNo: weekNo,
    isTrainingDay: isTrainingDay,
    weekday: weekday,
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
            timing: s.timing,
          ),
    ],
  );

  /// The next meal to eat at [now] (`HH:mm`): the first one not yet
  /// [logged] whose time is no more than [graceMinutes] gone. Null when the
  /// day's food is done. Drives the card on Today.
  ///
  /// v3 compared the clock only, so a meal vanished the minute its time
  /// passed — eaten or not — and one already eaten stayed "next" until then.
  PlannedMeal? nextToEat({
    required String now,
    Set<String> logged = const {},
    int graceMinutes = 120,
  }) {
    int minutes(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final from = minutes(now) - graceMinutes;
    return slots.firstWhereOrNull(
      (s) => !logged.contains(s.slot.id) && minutes(s.time) >= from,
    );
  }
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
    this.rotation = const [],
    this.prep,
    this.budget,
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

  /// The default meals, a weekday at a time.
  final List<RotationDay> rotation;
  final PrepPlan? prep;
  final FuelBudget? budget;

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

  /// What a list of weighed items costs.
  double costOf(List<MealItem> items) {
    var eur = 0.0;
    for (final i in items) {
      final f = _foodById[i.foodId];
      if (f != null) eur += f.priceEurPerKg * i.grams / 1000;
    }
    return eur;
  }

  RotationDay? rotationFor(int weekday) =>
      rotation.firstWhereOrNull((r) => r.weekday == weekday);

  List<Meal> mealsFor(String slotId) =>
      meals.where((m) => m.slotId == slotId).toList();

  /// The day's plan.
  ///
  /// Each slot is his swap if he made one, else [weekday]'s default from the
  /// rotation, else the slot's first meal. v3 always took the first — which
  /// put chicken at lunch AND salmon at dinner, every day of the week.
  ///
  /// [timing] is the day planner's, by slot id: when each meal is eaten on
  /// that date. Without it each meal sits at its slot's target.
  ///
  /// [extraKcal] is an adjustment he has APPLIED and that is still standing —
  /// v2 recomputed the bump on every read and stored nothing, so the moment it
  /// worked the target silently fell back to where it had stalled.
  FuelDay forDay({
    required int weekNo,
    required bool isTrainingDay,
    int extraKcal = 0,
    Map<String, String> chosen = const {},
    int? weekday,
    Map<String, MealTiming> timing = const {},
  }) {
    final phase = phaseForWeek(weekNo);
    final defaults = weekday == null ? null : rotationFor(weekday)?.meals;
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
      weekday: weekday,
      slots: [
        for (final s in applicable)
          if (mealsFor(s.id).isNotEmpty)
            () {
              final options = mealsFor(s.id);
              Meal? find(String? id) =>
                  options.firstWhereOrNull((m) => m.id == id);
              return PlannedMeal(
                slot: s,
                choices: options,
                chosen:
                    find(chosen[s.id]) ??
                    find(defaults?[s.id]) ??
                    options.first,
                timing: timing[s.id],
              );
            }(),
      ],
    );
  }

  /// A prep night reads in the order it is cooked: the protein first, then
  /// the pulses, then the starches, heaviest first within each.
  static int _cookingOrder(PrepItem a, PrepItem b) {
    const order = ['meat', 'fish', 'legume', 'grain', 'veg'];
    int rank(PrepItem i) {
      final r = order.indexOf(i.food.category);
      return r < 0 ? order.length : r;
    }

    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : b.grams.compareTo(a.grams);
  }

  /// The prep nights for the week starting [monday], resolved against the
  /// meals chosen in [week] (Monday first).
  ///
  /// A night cooks the prep foods of every batch meal on the days it covers,
  /// summed per food; a night whose days have nothing to cook ahead — he
  /// swapped it all away — is left out. A night can fall before the week:
  /// Sunday's cooking is for Monday.
  List<PrepNight> prepNights({
    required DateTime monday,
    required List<FuelDay> week,
  }) {
    final p = prep;
    if (p == null) return const [];
    final start = DateTime(monday.year, monday.month, monday.day);
    DateTime dateOf(int weekday) =>
        DateTime(start.year, start.month, start.day + weekday - 1);

    final nights = <PrepNight>[];
    for (final session in p.sessions) {
      final covered = [
        for (final wd in session.covers)
          if (wd >= 1 && wd <= week.length) wd,
      ];
      if (covered.isEmpty) continue;
      final ahead = (covered.first - session.cookOn) % 7;
      final first = dateOf(covered.first);
      final cookDate = DateTime(first.year, first.month, first.day - ahead);

      final meals = <PrepMeal>[];
      final grams = <String, double>{};
      for (final wd in covered) {
        for (final s in week[wd - 1].slots) {
          if (!s.chosen.batch) continue;
          meals.add(PrepMeal(date: dateOf(wd), slot: s.slot, meal: s.chosen));
          for (final i in s.chosen.items) {
            if (!p.foods.contains(i.foodId)) continue;
            grams[i.foodId] = (grams[i.foodId] ?? 0) + i.grams;
          }
        }
      }
      if (meals.isEmpty) continue;

      final cook = [
        for (final e in grams.entries)
          if (_foodById[e.key] case final f?) PrepItem(food: f, grams: e.value),
      ]..sort(_cookingOrder);
      nights.add(
        PrepNight(
          session: session,
          cookDate: cookDate,
          meals: meals,
          cook: cook,
        ),
      );
    }
    nights.sort((a, b) => a.cookDate.compareTo(b.cookDate));
    return nights;
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
      rotation: [
        for (final r in j['rotation'] as List? ?? const [])
          RotationDay.fromJson(r as Map<String, dynamic>),
      ],
      prep: switch (j['prep']) {
        final Map<String, dynamic> m => PrepPlan.fromJson(m),
        _ => null,
      },
      budget: switch (j['budget']) {
        final Map<String, dynamic> m => FuelBudget.fromJson(m),
        _ => null,
      },
    );
  }
}
