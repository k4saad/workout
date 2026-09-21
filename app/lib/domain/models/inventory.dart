import 'enums.dart';

/// A bar or handle.
class Bar {
  const Bar({
    required this.id,
    required this.name,
    required this.weightKg,
    this.measured = false,
  });

  final String id;
  final String name;
  final double weightKg;

  /// False until it has actually been on a bathroom scale. The plate solver is
  /// garbage-in until this is true for every bar (docs/04-calibration.md).
  final bool measured;

  factory Bar.fromJson(Map<String, dynamic> j) => Bar(
    id: j['id'] as String,
    name: j['name'] as String,
    weightKg: (j['weightKg'] as num).toDouble(),
    measured: j['measured'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weightKg': weightKg,
    'measured': measured,
  };

  Bar copyWith({String? name, double? weightKg, bool? measured}) => Bar(
    id: id,
    name: name ?? this.name,
    weightKg: weightKg ?? this.weightKg,
    measured: measured ?? this.measured,
  );
}

/// A plate size and how many of them exist.
class PlateStock {
  const PlateStock({
    required this.weightKg,
    required this.count,
    this.bore = 'standard',
  });

  final double weightKg;
  final int count;

  /// 'standard' (~30 mm) or 'olympic' (50 mm). A plate that does not fit the
  /// bar is not inventory, however heavy it is.
  final String bore;

  factory PlateStock.fromJson(Map<String, dynamic> j) => PlateStock(
    weightKg: (j['weightKg'] as num).toDouble(),
    count: (j['count'] as num).toInt(),
    bore: j['bore'] as String? ?? 'standard',
  );

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'count': count,
    'bore': bore,
  };

  PlateStock copyWith({double? weightKg, int? count, String? bore}) =>
      PlateStock(
        weightKg: weightKg ?? this.weightKg,
        count: count ?? this.count,
        bore: bore ?? this.bore,
      );
}

class FixedDumbbell {
  const FixedDumbbell({required this.weightKg, this.count = 2});
  final double weightKg;
  final int count;

  factory FixedDumbbell.fromJson(Map<String, dynamic> j) => FixedDumbbell(
    weightKg: (j['weightKg'] as num).toDouble(),
    count: (j['count'] as num?)?.toInt() ?? 2,
  );

  Map<String, dynamic> toJson() => {'weightKg': weightKg, 'count': count};
}

class RoomDimensions {
  const RoomDimensions({
    this.ceilingLiftingCm,
    this.ceilingSkippingCm,
    this.pullUpClearanceCm,
    this.carryLengthM,
  });

  final int? ceilingLiftingCm;
  final int? ceilingSkippingCm;
  final int? pullUpClearanceCm;
  final double? carryLengthM;

  bool get isMeasured => ceilingLiftingCm != null && ceilingSkippingCm != null;

  factory RoomDimensions.fromJson(Map<String, dynamic> j) => RoomDimensions(
    ceilingLiftingCm: (j['ceilingLiftingCm'] as num?)?.toInt(),
    ceilingSkippingCm: (j['ceilingSkippingCm'] as num?)?.toInt(),
    pullUpClearanceCm: (j['pullUpClearanceCm'] as num?)?.toInt(),
    carryLengthM: (j['carryLengthM'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'ceilingLiftingCm': ceilingLiftingCm,
    'ceilingSkippingCm': ceilingSkippingCm,
    'pullUpClearanceCm': pullUpClearanceCm,
    'carryLengthM': carryLengthM,
  };
}

/// Everything the plate solver needs to know about the basement.
///
/// This is the single most consequential piece of configuration in the app: a
/// wrong bar weight makes every suggested load wrong by the same amount, and
/// wrong plate counts make the solver propose weights that cannot be built.
class Inventory {
  const Inventory({
    this.bars = const [],
    this.plates = const [],
    this.fixedDumbbells = const [],
    this.kettlebells = const [],
    this.collarWeightKg = 0,
    this.room = const RoomDimensions(),
  });

  final List<Bar> bars;
  final List<PlateStock> plates;
  final List<FixedDumbbell> fixedDumbbells;
  final List<double> kettlebells;
  final double collarWeightKg;
  final RoomDimensions room;

  /// True once every bar has actually been weighed. Until then the app should
  /// say so loudly rather than pretending its numbers are real.
  bool get isCalibrated => bars.isNotEmpty && bars.every((b) => b.measured);

  Bar? bar(String id) {
    for (final b in bars) {
      if (b.id == id) return b;
    }
    return null;
  }

  double barWeight(String id) => bar(id)?.weightKg ?? 0;

  /// The base weight for a load mode, before any plates.
  double baseWeightFor(LoadMode mode) => switch (mode) {
    LoadMode.barbell => barWeight('barbell'),
    LoadMode.ezBar => barWeight('ezBar'),
    LoadMode.dumbbellPair || LoadMode.dumbbellSingle => barWeight('dbHandle'),
    _ => 0,
  };

  /// How many plates of each size one *set* of this mode consumes.
  ///
  /// A barbell takes one plate per side (2). A PAIR of dumbbells takes two
  /// sides times two handles (4) — the budget-halving that is easy to get
  /// wrong and that silently doubles every dumbbell suggestion.
  int platesConsumedPer(LoadMode mode) => switch (mode) {
    LoadMode.barbell || LoadMode.ezBar || LoadMode.dumbbellSingle => 2,
    LoadMode.dumbbellPair => 4,
    _ => 0,
  };

  /// Plate sizes available to one side, largest first, with the per-side count
  /// budget already applied for [mode].
  List<({double kg, int count})> budgetFor(LoadMode mode) {
    final div = platesConsumedPer(mode);
    if (div == 0) return const [];
    final out = plates
        .map((p) => (kg: p.weightKg, count: p.count ~/ div))
        .where((e) => e.count > 0)
        .toList();
    out.sort((a, b) => b.kg.compareTo(a.kg));
    return out;
  }

  /// The smallest plate that exists at all, in kilograms. This one number
  /// decides whether progression is smooth or unusable.
  double? get smallestPlateKg {
    if (plates.isEmpty) return null;
    return plates.map((p) => p.weightKg).reduce((a, b) => a < b ? a : b);
  }

  factory Inventory.fromJson(Map<String, dynamic> j) => Inventory(
    bars: (j['bars'] as List? ?? const [])
        .map((e) => Bar.fromJson(e as Map<String, dynamic>))
        .toList(),
    plates: (j['plates'] as List? ?? const [])
        .map((e) => PlateStock.fromJson(e as Map<String, dynamic>))
        .toList(),
    fixedDumbbells: (j['fixedDumbbells'] as List? ?? const [])
        .map((e) => FixedDumbbell.fromJson(e as Map<String, dynamic>))
        .toList(),
    kettlebells: (j['kettlebells'] as List? ?? const [])
        .map((e) => ((e as Map<String, dynamic>)['weightKg'] as num).toDouble())
        .toList(),
    collarWeightKg: (j['collarWeightKg'] as num?)?.toDouble() ?? 0,
    room: j['room'] == null
        ? const RoomDimensions()
        : RoomDimensions.fromJson(j['room'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'bars': bars.map((e) => e.toJson()).toList(),
    'plates': plates.map((e) => e.toJson()).toList(),
    'fixedDumbbells': fixedDumbbells.map((e) => e.toJson()).toList(),
    'kettlebells': kettlebells.map((e) => {'weightKg': e}).toList(),
    'collarWeightKg': collarWeightKg,
    'room': room.toJson(),
  };

  Inventory copyWith({
    List<Bar>? bars,
    List<PlateStock>? plates,
    List<FixedDumbbell>? fixedDumbbells,
    List<double>? kettlebells,
    double? collarWeightKg,
    RoomDimensions? room,
  }) => Inventory(
    bars: bars ?? this.bars,
    plates: plates ?? this.plates,
    fixedDumbbells: fixedDumbbells ?? this.fixedDumbbells,
    kettlebells: kettlebells ?? this.kettlebells,
    collarWeightKg: collarWeightKg ?? this.collarWeightKg,
    room: room ?? this.room,
  );
}
