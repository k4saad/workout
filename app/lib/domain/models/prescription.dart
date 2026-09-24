import 'package:collection/collection.dart';

import 'enums.dart';

/// Which `cardioProgression` column drives a `cardioTable` run.
enum CardioColumn {
  /// `longRunMin`: the Sunday run.
  long,

  /// `secondRunMin`: the midweek run.
  second;

  /// Lenient, like every enum here: an unknown column reads as none.
  static CardioColumn? fromJson(String? v) =>
      CardioColumn.values.where((e) => e.name == v).firstOrNull;

  String toJson() => name;
}

/// The progression rule attached to a prescription.
class Progression {
  const Progression({
    required this.type,
    this.incrementKg = 0,
    this.incrementSec = 0,
    this.deloadPct = 0.10,
    this.stallLimit = 2,
    this.historyWindowDays = 21,
    this.maxJumpPct = 0.10,
    this.table,
  });

  final ProgressionType type;

  /// The *desired* jump. The engine may use a smaller lattice step, or refuse
  /// the jump entirely and rep-creep instead.
  final double incrementKg;
  final int incrementSec;
  final double deloadPct;
  final int stallLimit;

  /// History older than this is ignored and `startLoadKg` is used instead.
  /// Makes the history-vs-cold-start precedence explicit (audit B4).
  final int historyWindowDays;

  /// Above this fraction of current load, one lattice step is too big a jump
  /// and rep creep engages instead. The clamp must never reduce a jump below
  /// one lattice step — that is what deadlocked v1 (audit A1).
  final double maxJumpPct;

  /// `cardioTable` only: which `cardioProgression` column sets this run's
  /// length each week. The block resolver applies it (audit C4); a week
  /// whose column is empty has no such run.
  final CardioColumn? table;

  static const Progression none = Progression(type: ProgressionType.none);

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
    type: ProgressionType.fromJson(j['type'] as String),
    incrementKg: (j['incrementKg'] as num?)?.toDouble() ?? 0,
    incrementSec: (j['incrementSec'] as num?)?.toInt() ?? 0,
    deloadPct: (j['deloadPct'] as num?)?.toDouble() ?? 0.10,
    stallLimit: (j['stallLimit'] as num?)?.toInt() ?? 2,
    historyWindowDays: (j['historyWindowDays'] as num?)?.toInt() ?? 21,
    maxJumpPct: (j['maxJumpPct'] as num?)?.toDouble() ?? 0.10,
    table: CardioColumn.fromJson(j['table'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    if (incrementKg != 0) 'incrementKg': incrementKg,
    if (incrementSec != 0) 'incrementSec': incrementSec,
    'deloadPct': deloadPct,
    'stallLimit': stallLimit,
    'historyWindowDays': historyWindowDays,
    'maxJumpPct': maxJumpPct,
    // Without this an in-app edit saved every run without its column, and
    // the schema requires one for cardioTable.
    if (table != null) 'table': table!.toJson(),
  };

  Progression copyWith({
    ProgressionType? type,
    double? incrementKg,
    int? incrementSec,
    double? deloadPct,
    int? stallLimit,
    int? historyWindowDays,
    double? maxJumpPct,
    CardioColumn? table,
  }) => Progression(
    type: type ?? this.type,
    incrementKg: incrementKg ?? this.incrementKg,
    incrementSec: incrementSec ?? this.incrementSec,
    deloadPct: deloadPct ?? this.deloadPct,
    stallLimit: stallLimit ?? this.stallLimit,
    historyWindowDays: historyWindowDays ?? this.historyWindowDays,
    maxJumpPct: maxJumpPct ?? this.maxJumpPct,
    table: table ?? this.table,
  );

  @override
  bool operator ==(Object other) =>
      other is Progression &&
      other.type == type &&
      other.incrementKg == incrementKg &&
      other.incrementSec == incrementSec &&
      other.deloadPct == deloadPct &&
      other.stallLimit == stallLimit &&
      other.historyWindowDays == historyWindowDays &&
      other.maxJumpPct == maxJumpPct &&
      other.table == table;

  @override
  int get hashCode => Object.hash(
    type,
    incrementKg,
    incrementSec,
    deloadPct,
    stallLimit,
    historyWindowDays,
    maxJumpPct,
    table,
  );
}

/// One prescribed movement inside a section.
///
/// Immutable. `copyWith` is how block overrides and multipliers are applied —
/// the resolver never mutates the source programme.
class Prescription {
  const Prescription({
    required this.id,
    required this.exerciseId,
    required this.order,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSec,
    required this.loadMode,
    this.groupId,
    this.unit = RepUnit.reps,
    this.repsCreepMax,
    this.targetRir,
    this.startLoadKg,
    this.perSide = false,
    this.unilateral = false,
    this.warmupRamp = false,
    this.optional = false,
    this.progression = Progression.none,
    this.substitutes = const [],
    this.coachNote,
    this.tempo,
  });

  final String id;
  final String exerciseId;
  final int order;

  /// Superset grouping. Members share a `groupId`, are performed alternating,
  /// and only the LAST member carries the rest. This is how a five-movement
  /// session fits inside sixty minutes.
  final String? groupId;

  final RepUnit unit;
  final int sets;
  final int repsMin;
  final int repsMax;

  /// Ceiling the rep range may extend to when one lattice step is a bigger
  /// jump than `progression.maxJumpPct`. Null disables rep creep.
  final int? repsCreepMax;

  final int restSec;

  /// Null means "inherit `block.defaultRir`". v1 declared `defaultRir` on
  /// every block and never consumed it (audit C2).
  final int? targetRir;

  final LoadMode loadMode;

  /// COLD-START value only, used when no history exists inside
  /// `progression.historyWindowDays`. Must be lattice-valid (gate V6).
  final double? startLoadKg;

  /// Whether `sets` means sets *per side*. v1 could only express this in an
  /// unparseable `coachNote` (audit C5).
  final bool perSide;
  final bool unilateral;

  /// Generate lattice-aware ramp sets before the first work set.
  final bool warmupRamp;

  /// Droppable when short on time, and the first thing the runner offers to
  /// cut at the 45-minute mark.
  final bool optional;

  final Progression progression;
  final List<String> substitutes;
  final String? coachNote;
  final String? tempo;

  /// True when this prescription is part of a superset.
  bool get isSuperset => groupId != null;

  /// Total working sets actually performed (per-side prescriptions do double).
  int get totalWorkingSets => perSide ? sets * 2 : sets;

  /// A single rep target renders as "8", a range as "6–8".
  String get repRangeLabel =>
      repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
    id: j['id'] as String,
    exerciseId: j['exerciseId'] as String,
    order: (j['order'] as num).toInt(),
    groupId: j['groupId'] as String?,
    unit: RepUnit.fromJson(j['unit'] as String?),
    sets: (j['sets'] as num).toInt(),
    repsMin: (j['repsMin'] as num).toInt(),
    repsMax: (j['repsMax'] as num).toInt(),
    repsCreepMax: (j['repsCreepMax'] as num?)?.toInt(),
    restSec: (j['restSec'] as num).toInt(),
    targetRir: (j['targetRir'] as num?)?.toInt(),
    loadMode: LoadMode.fromJson(j['loadMode'] as String),
    startLoadKg: (j['startLoadKg'] as num?)?.toDouble(),
    perSide: j['perSide'] as bool? ?? false,
    unilateral: j['unilateral'] as bool? ?? false,
    warmupRamp: j['warmupRamp'] as bool? ?? false,
    optional: j['optional'] as bool? ?? false,
    progression: j['progression'] == null
        ? Progression.none
        : Progression.fromJson(j['progression'] as Map<String, dynamic>),
    substitutes:
        (j['substitutes'] as List?)?.cast<String>().toList() ?? const [],
    coachNote: j['coachNote'] as String?,
    tempo: j['tempo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'order': order,
    'groupId': groupId,
    'unit': unit.toJson(),
    'sets': sets,
    'repsMin': repsMin,
    'repsMax': repsMax,
    'repsCreepMax': repsCreepMax,
    'restSec': restSec,
    'targetRir': targetRir,
    'loadMode': loadMode.toJson(),
    'startLoadKg': startLoadKg,
    'perSide': perSide,
    'unilateral': unilateral,
    'warmupRamp': warmupRamp,
    'optional': optional,
    'progression': progression.toJson(),
    'substitutes': substitutes,
    'coachNote': coachNote,
    'tempo': tempo,
  };

  /// Applies a shallow merge from a `prescriptionOverrides` map, exactly as
  /// the block resolver needs. Unknown keys are ignored rather than throwing —
  /// a bad edit in the in-app editor must not brick the app.
  Prescription applyOverride(Map<String, dynamic> o) => copyWith(
    sets: (o['sets'] as num?)?.toInt(),
    repsMin: (o['repsMin'] as num?)?.toInt(),
    repsMax: (o['repsMax'] as num?)?.toInt(),
    repsCreepMax: (o['repsCreepMax'] as num?)?.toInt(),
    restSec: (o['restSec'] as num?)?.toInt(),
    targetRir: (o['targetRir'] as num?)?.toInt(),
    clearTargetRir: o.containsKey('targetRir') && o['targetRir'] == null,
    exerciseId: o['exerciseId'] as String?,
    loadMode: o['loadMode'] == null
        ? null
        : LoadMode.fromJson(o['loadMode'] as String),
    startLoadKg: (o['startLoadKg'] as num?)?.toDouble(),
    optional: o['optional'] as bool?,
    warmupRamp: o['warmupRamp'] as bool?,
    coachNote: o['coachNote'] as String?,
    tempo: o['tempo'] as String?,
    unit: o['unit'] == null ? null : RepUnit.fromJson(o['unit'] as String),
  );

  Prescription copyWith({
    String? id,
    String? exerciseId,
    int? order,
    String? groupId,
    bool clearGroupId = false,
    RepUnit? unit,
    int? sets,
    int? repsMin,
    int? repsMax,
    int? repsCreepMax,
    int? restSec,
    int? targetRir,
    bool clearTargetRir = false,
    LoadMode? loadMode,
    double? startLoadKg,
    bool? perSide,
    bool? unilateral,
    bool? warmupRamp,
    bool? optional,
    Progression? progression,
    List<String>? substitutes,
    String? coachNote,
    bool clearCoachNote = false,
    String? tempo,
  }) => Prescription(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    order: order ?? this.order,
    groupId: clearGroupId ? null : (groupId ?? this.groupId),
    unit: unit ?? this.unit,
    sets: sets ?? this.sets,
    repsMin: repsMin ?? this.repsMin,
    repsMax: repsMax ?? this.repsMax,
    repsCreepMax: repsCreepMax ?? this.repsCreepMax,
    restSec: restSec ?? this.restSec,
    targetRir: clearTargetRir ? null : (targetRir ?? this.targetRir),
    loadMode: loadMode ?? this.loadMode,
    startLoadKg: startLoadKg ?? this.startLoadKg,
    perSide: perSide ?? this.perSide,
    unilateral: unilateral ?? this.unilateral,
    warmupRamp: warmupRamp ?? this.warmupRamp,
    optional: optional ?? this.optional,
    progression: progression ?? this.progression,
    substitutes: substitutes ?? this.substitutes,
    coachNote: clearCoachNote ? null : (coachNote ?? this.coachNote),
    tempo: tempo ?? this.tempo,
  );

  @override
  bool operator ==(Object other) =>
      other is Prescription &&
      other.id == id &&
      other.exerciseId == exerciseId &&
      other.order == order &&
      other.groupId == groupId &&
      other.unit == unit &&
      other.sets == sets &&
      other.repsMin == repsMin &&
      other.repsMax == repsMax &&
      other.repsCreepMax == repsCreepMax &&
      other.restSec == restSec &&
      other.targetRir == targetRir &&
      other.loadMode == loadMode &&
      other.startLoadKg == startLoadKg &&
      other.perSide == perSide &&
      other.unilateral == unilateral &&
      other.warmupRamp == warmupRamp &&
      other.optional == optional &&
      other.progression == progression &&
      const ListEquality<String>().equals(other.substitutes, substitutes) &&
      other.coachNote == coachNote &&
      other.tempo == tempo;

  @override
  int get hashCode => Object.hash(
    id,
    exerciseId,
    order,
    groupId,
    unit,
    sets,
    repsMin,
    repsMax,
    repsCreepMax,
    restSec,
    targetRir,
    loadMode,
    startLoadKg,
    Object.hash(
      perSide,
      unilateral,
      warmupRamp,
      optional,
      progression,
      const ListEquality<String>().hash(substitutes),
      coachNote,
      tempo,
    ),
  );

  @override
  String toString() => 'Prescription($id, $exerciseId, ${sets}x$repRangeLabel)';
}
