import 'package:collection/collection.dart';

import 'block.dart';
import 'enums.dart';

class Athlete {
  const Athlete({
    this.startWeightKg,
    this.heightCm,
    this.targetWeightKg,
    this.ageYears,
    this.sex,
    this.experience,
    this.trainsAlone = false,
  });

  final double? startWeightKg;
  final int? heightCm;
  final double? targetWeightKg;
  final int? ageYears;
  final String? sex;
  final String? experience;
  final bool trainsAlone;

  factory Athlete.fromJson(Map<String, dynamic> j) => Athlete(
    startWeightKg: (j['startWeightKg'] as num?)?.toDouble(),
    heightCm: (j['heightCm'] as num?)?.toInt(),
    targetWeightKg: (j['targetWeightKg'] as num?)?.toDouble(),
    ageYears: (j['ageYears'] as num?)?.toInt(),
    sex: j['sex'] as String?,
    experience: j['experience'] as String?,
    trainsAlone: j['trainsAlone'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'startWeightKg': startWeightKg,
    'heightCm': heightCm,
    'targetWeightKg': targetWeightKg,
    'ageYears': ageYears,
    'sex': sex,
    'experience': experience,
    'trainsAlone': trainsAlone,
  };
}

/// One escalating nutrition target. TDEE rises with bodyweight, so a fixed
/// number becomes maintenance by week 10 (audit C11).
class NutritionPhase {
  const NutritionPhase({
    required this.weeks,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.note,
  });

  final List<int> weeks;
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String? note;

  /// kcal implied by the macros. Should agree with [kcal] to within rounding —
  /// v1's was 85 kcal short of its own headline (audit C10).
  int get macroKcal => proteinG * 4 + carbsG * 4 + fatG * 9;

  bool coversWeek(int w) => weeks.contains(w);

  factory NutritionPhase.fromJson(Map<String, dynamic> j) => NutritionPhase(
    weeks: (j['weeks'] as List).map((e) => (e as num).toInt()).toList(),
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num?)?.toInt() ?? 0,
    carbsG: (j['carbsG'] as num?)?.toInt() ?? 0,
    fatG: (j['fatG'] as num?)?.toInt() ?? 0,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'weeks': weeks,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'note': note,
  };
}

class NutritionRules {
  const NutritionRules({
    this.gainKgPerWeek = 0.3,
    this.flatWeeksBeforeBump = 2,
    this.kcalBumpWhenFlat = 250,
    this.useRollingAverage = true,
    this.rollingAverageDays = 7,
    this.waistGrowthLimitCm = 3.0,
    this.kcalCutWhenWaistGrows = 200,
  });

  final double gainKgPerWeek;
  final int flatWeeksBeforeBump;
  final int kcalBumpWhenFlat;

  /// Daily bodyweight swings a kilo on water and gut content. The flat-weight
  /// rule runs off the rolling average or it just chases noise.
  final bool useRollingAverage;
  final int rollingAverageDays;

  final double waistGrowthLimitCm;
  final int kcalCutWhenWaistGrows;

  factory NutritionRules.fromJson(Map<String, dynamic> j) => NutritionRules(
    gainKgPerWeek: (j['gainKgPerWeek'] as num?)?.toDouble() ?? 0.3,
    flatWeeksBeforeBump: (j['flatWeeksBeforeBump'] as num?)?.toInt() ?? 2,
    kcalBumpWhenFlat: (j['kcalBumpWhenFlat'] as num?)?.toInt() ?? 250,
    useRollingAverage: j['useRollingAverage'] as bool? ?? true,
    rollingAverageDays: (j['rollingAverageDays'] as num?)?.toInt() ?? 7,
    waistGrowthLimitCm: (j['waistGrowthLimitCm'] as num?)?.toDouble() ?? 3.0,
    kcalCutWhenWaistGrows: (j['kcalCutWhenWaistGrows'] as num?)?.toInt() ?? 200,
  );

  Map<String, dynamic> toJson() => {
    'gainKgPerWeek': gainKgPerWeek,
    'flatWeeksBeforeBump': flatWeeksBeforeBump,
    'kcalBumpWhenFlat': kcalBumpWhenFlat,
    'useRollingAverage': useRollingAverage,
    'rollingAverageDays': rollingAverageDays,
    'waistGrowthLimitCm': waistGrowthLimitCm,
    'kcalCutWhenWaistGrows': kcalCutWhenWaistGrows,
  };
}

/// What happens at week `totalWeeks + 1`. Without this the calendar returns
/// null forever and the app has nothing to say (audit C8).
class OnComplete {
  const OnComplete({
    required this.action,
    this.skipBlocks = const [],
    this.seedFrom,
    this.bodyweightTargetKg,
  });

  final CompletionAction action;
  final List<String> skipBlocks;
  final String? seedFrom;
  final double? bodyweightTargetKg;

  factory OnComplete.fromJson(Map<String, dynamic> j) => OnComplete(
    action: CompletionAction.fromJson(j['action'] as String),
    skipBlocks: (j['skipBlocks'] as List?)?.cast<String>().toList() ?? const [],
    seedFrom: j['seedFrom'] as String?,
    bodyweightTargetKg: (j['bodyweightTargetKg'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'action': action.toJson(),
    'skipBlocks': skipBlocks,
    'seedFrom': seedFrom,
    'bodyweightTargetKg': bodyweightTargetKg,
  };
}

/// One row of the cardio table.
///
/// Authoritative for every prescription whose progression type is
/// `cardioTable`; the prescription's own reps are ignored in that case, which
/// is the rule v1 never stated (audit C4).
class CardioWeek {
  const CardioWeek({
    required this.weeks,
    this.longRunMin,
    this.secondRunMin,
    this.skipping,
    this.bag,
    this.note,
  });

  final List<int> weeks;
  final List<int>? longRunMin;
  final List<int>? secondRunMin;
  final String? skipping;
  final String? bag;
  final String? note;

  bool coversWeek(int w) => weeks.contains(w);

  String? get longRunLabel => longRunMin == null
      ? null
      : longRunMin!.first == longRunMin!.last
      ? '${longRunMin!.first} min'
      : '${longRunMin!.first}–${longRunMin!.last} min';

  static List<int>? _range(dynamic v) =>
      v == null ? null : (v as List).map((e) => (e as num).toInt()).toList();

  factory CardioWeek.fromJson(Map<String, dynamic> j) => CardioWeek(
    weeks: (j['weeks'] as List).map((e) => (e as num).toInt()).toList(),
    longRunMin: _range(j['longRunMin']),
    secondRunMin: _range(j['secondRunMin']),
    skipping: j['skipping'] as String?,
    bag: j['bag'] as String?,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'weeks': weeks,
    'longRunMin': longRunMin,
    'secondRunMin': secondRunMin,
    'skipping': skipping,
    'bag': bag,
    'note': note,
  };
}

/// What the app can see for itself, so a checkpoint item ticks without
/// being asked twice.
enum CheckKind {
  /// A shoot of every pose.
  photos,

  /// Every site in [Programme.measurementSites].
  measurements,

  /// Any weigh-in.
  weighIn,

  /// Every required session so far accounted for: done, or skipped on
  /// purpose. No holes.
  sessionsLogged;

  static CheckKind? fromJson(String s) =>
      values.where((k) => k.name == s).firstOrNull;
}

class Checkpoint {
  const Checkpoint({
    required this.week,
    required this.items,
    this.expectedWeightKg,
    this.autoTick = const {},
  });

  final int week;
  final List<String> items;
  final List<double>? expectedWeightKg;

  /// Which item each kind of evidence ticks, by index into [items]. The
  /// rest are ticked by hand.
  final Map<CheckKind, int> autoTick;

  /// The kind of evidence that ticks item [index], if any.
  CheckKind? autoFor(int index) {
    for (final MapEntry(:key, :value) in autoTick.entries) {
      if (value == index) return key;
    }
    return null;
  }

  factory Checkpoint.fromJson(Map<String, dynamic> j) => Checkpoint(
    week: (j['week'] as num).toInt(),
    items: (j['items'] as List).cast<String>().toList(),
    expectedWeightKg: j['expectedWeightKg'] == null
        ? null
        : (j['expectedWeightKg'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
    autoTick: {
      for (final MapEntry(:key, :value)
          in ((j['autoTick'] as Map?) ?? const {}).entries)
        // An unknown kind is dropped, not a crash: older builds reading a
        // newer programme.
        ?CheckKind.fromJson(key as String): (value as num).toInt(),
    },
  );

  Map<String, dynamic> toJson() => {
    'week': week,
    'expectedWeightKg': expectedWeightKg,
    'items': items,
    if (autoTick.isNotEmpty)
      'autoTick': {for (final e in autoTick.entries) e.key.name: e.value},
  };
}

/// A per-lift target.
///
/// [isFloor] means this is what the programme's own increments produce, not a
/// goal — missing it is not failure, and the UI must say so. v1 published
/// targets its own arithmetic could not reach (audit B6).
class StrengthTarget {
  const StrengthTarget({
    required this.exerciseId,
    this.week4Kg,
    this.week12Kg,
    this.reps = 5,
    this.isFloor = true,
    this.note,
  });

  final String exerciseId;
  final List<double>? week4Kg;
  final List<double>? week12Kg;
  final int reps;
  final bool isFloor;
  final String? note;

  /// Epley. ALWAYS label this as an estimate in the UI.
  double? get week12E1rm =>
      week12Kg == null ? null : week12Kg!.last * (1 + reps / 30);

  static List<double>? _range(dynamic v) =>
      v == null ? null : (v as List).map((e) => (e as num).toDouble()).toList();

  factory StrengthTarget.fromJson(Map<String, dynamic> j) => StrengthTarget(
    exerciseId: j['exerciseId'] as String,
    week4Kg: _range(j['week4Kg']),
    week12Kg: _range(j['week12Kg']),
    reps: (j['reps'] as num?)?.toInt() ?? 5,
    isFloor: j['isFloor'] as bool? ?? true,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'week4Kg': week4Kg,
    'week12Kg': week12Kg,
    'reps': reps,
    'isFloor': isFloor,
    'note': note,
  };
}

/// The programme root.
class Programme {
  const Programme({
    required this.id,
    required this.name,
    required this.schemaVersion,
    required this.revision,
    required this.startDate,
    required this.totalWeeks,
    required this.blocks,
    this.notes,
    this.athlete = const Athlete(),
    this.nutritionPhases = const [],
    this.nutritionRules = const NutritionRules(),
    this.onComplete,
    this.rules = const [],
    this.cardioProgression = const [],
    this.checkpoints = const [],
    this.strengthTargets = const [],
    this.measurementSites = const [],
  });

  final String id;
  final String name;
  final int schemaVersion;
  final int revision;
  final DateTime startDate;
  final int totalWeeks;
  final String? notes;
  final Athlete athlete;
  final List<NutritionPhase> nutritionPhases;
  final NutritionRules nutritionRules;
  final OnComplete? onComplete;
  final List<String> rules;
  final List<CardioWeek> cardioProgression;
  final List<Checkpoint> checkpoints;
  final List<StrengthTarget> strengthTargets;
  final List<Block> blocks;

  /// The tape-measure sites a checkpoint asks for, by name (`waist`,
  /// `upperArm`, ...). The Measure screen leads with these.
  final List<String> measurementSites;

  Block? blockForWeek(int week) =>
      blocks.firstWhereOrNull((b) => b.coversWeek(week));

  Block? blockById(String id) => blocks.firstWhereOrNull((b) => b.id == id);

  NutritionPhase? nutritionForWeek(int week) =>
      nutritionPhases.firstWhereOrNull((p) => p.coversWeek(week));

  CardioWeek? cardioForWeek(int week) =>
      cardioProgression.firstWhereOrNull((c) => c.coversWeek(week));

  Checkpoint? checkpointForWeek(int week) =>
      checkpoints.firstWhereOrNull((c) => c.week == week);

  /// Monday of the ISO week containing [startDate]. The programme's days are
  /// keyed by weekday, so week 1 is Monday-anchored even when the start date
  /// falls mid-week.
  DateTime get anchorMonday {
    final d = DateTime(startDate.year, startDate.month, startDate.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  factory Programme.fromJson(Map<String, dynamic> j) => Programme(
    id: j['id'] as String,
    name: j['name'] as String,
    schemaVersion: (j['schemaVersion'] as num).toInt(),
    revision: (j['revision'] as num).toInt(),
    startDate: DateTime.parse(j['startDate'] as String),
    totalWeeks: (j['totalWeeks'] as num).toInt(),
    notes: j['notes'] as String?,
    athlete: j['athlete'] == null
        ? const Athlete()
        : Athlete.fromJson(j['athlete'] as Map<String, dynamic>),
    nutritionPhases: (j['nutritionPhases'] as List? ?? const [])
        .map((e) => NutritionPhase.fromJson(e as Map<String, dynamic>))
        .toList(),
    nutritionRules: j['nutritionRules'] == null
        ? const NutritionRules()
        : NutritionRules.fromJson(j['nutritionRules'] as Map<String, dynamic>),
    onComplete: j['onComplete'] == null
        ? null
        : OnComplete.fromJson(j['onComplete'] as Map<String, dynamic>),
    rules: (j['rules'] as List?)?.cast<String>().toList() ?? const [],
    cardioProgression: (j['cardioProgression'] as List? ?? const [])
        .map((e) => CardioWeek.fromJson(e as Map<String, dynamic>))
        .toList(),
    checkpoints: (j['checkpoints'] as List? ?? const [])
        .map((e) => Checkpoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    strengthTargets: (j['strengthTargets'] as List? ?? const [])
        .map((e) => StrengthTarget.fromJson(e as Map<String, dynamic>))
        .toList(),
    measurementSites:
        (j['measurementSites'] as List?)?.cast<String>().toList() ?? const [],
    blocks: (j['blocks'] as List)
        .map((e) => Block.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'schemaVersion': schemaVersion,
    'revision': revision,
    'startDate':
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
    'totalWeeks': totalWeeks,
    'notes': notes,
    'athlete': athlete.toJson(),
    'nutritionPhases': nutritionPhases.map((e) => e.toJson()).toList(),
    'nutritionRules': nutritionRules.toJson(),
    if (onComplete != null) 'onComplete': onComplete!.toJson(),
    'rules': rules,
    'cardioProgression': cardioProgression.map((e) => e.toJson()).toList(),
    'checkpoints': checkpoints.map((e) => e.toJson()).toList(),
    'strengthTargets': strengthTargets.map((e) => e.toJson()).toList(),
    if (measurementSites.isNotEmpty) 'measurementSites': measurementSites,
    'blocks': blocks.map((e) => e.toJson()).toList(),
  };

  Programme copyWith({
    int? revision,
    DateTime? startDate,
    List<Block>? blocks,
  }) => Programme(
    id: id,
    name: name,
    schemaVersion: schemaVersion,
    revision: revision ?? this.revision,
    startDate: startDate ?? this.startDate,
    totalWeeks: totalWeeks,
    notes: notes,
    athlete: athlete,
    nutritionPhases: nutritionPhases,
    nutritionRules: nutritionRules,
    onComplete: onComplete,
    rules: rules,
    cardioProgression: cardioProgression,
    checkpoints: checkpoints,
    strengthTargets: strengthTargets,
    measurementSites: measurementSites,
    blocks: blocks ?? this.blocks,
  );

  @override
  String toString() =>
      'Programme($id rev$revision, $totalWeeks weeks, ${blocks.length} blocks)';
}
