/// Enumerations mirroring `assets/programmes/schema.json`.
///
/// Every one of these parses leniently on read (unknown value -> a documented
/// fallback) because a bad programme edit must never brick the app, and
/// strictly on write (always emits the canonical wire name).
library;

/// Day of week. Monday-first, matching the programme's weekday keys and the
/// German calendar convention.
enum Weekday {
  mon(1),
  tue(2),
  wed(3),
  thu(4),
  fri(5),
  sat(6),
  sun(7);

  const Weekday(this.isoDay);

  /// 1 = Monday .. 7 = Sunday, matching `DateTime.weekday`.
  final int isoDay;

  static Weekday fromJson(String v) => Weekday.values.firstWhere(
    (e) => e.name == v,
    orElse: () => throw FormatException('unknown weekday: $v'),
  );

  static Weekday fromDateTime(DateTime d) =>
      Weekday.values.firstWhere((e) => e.isoDay == d.weekday);

  String toJson() => name;
}

/// What kind of day this is. Drives the calendar cell colour and whether the
/// session runner opens at all.
enum DayKind {
  lift,
  cardio,
  rest,
  mobility;

  static DayKind fromJson(String v) =>
      DayKind.values.firstWhere((e) => e.name == v, orElse: () => DayKind.lift);

  String toJson() => name;
}

/// Section within a day.
enum SectionType {
  warmup,
  main,
  finisher,
  cooldown,
  cardio;

  static SectionType fromJson(String v) => SectionType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SectionType.main,
  );

  /// Warm-ups and cool-downs are ticked, not logged: they produce no set_logs
  /// rows and never feed the progression engine.
  bool get isLogged =>
      this == SectionType.main ||
      this == SectionType.finisher ||
      this == SectionType.cardio;

  String toJson() => name;
}

/// How a prescription is loaded. Drives which plate-solver path runs, what the
/// log input widget looks like, and whether bodyweight folds into e1RM.
enum LoadMode {
  barbell,
  ezBar,
  dumbbellPair,
  dumbbellSingle,
  kettlebell,
  cable,
  bodyweight,
  bodyweightLoaded,
  banded,
  timed,
  distance;

  static LoadMode fromJson(String v) => LoadMode.values.firstWhere(
    (e) => e.name == v,
    orElse: () => LoadMode.bodyweight,
  );

  /// Modes the plate solver can produce a lattice for.
  bool get isPlateLoaded =>
      this == LoadMode.barbell ||
      this == LoadMode.ezBar ||
      this == LoadMode.dumbbellPair ||
      this == LoadMode.dumbbellSingle;

  /// Modes that carry a kilogram value at all.
  bool get hasLoad =>
      isPlateLoaded ||
      this == LoadMode.kettlebell ||
      this == LoadMode.bodyweightLoaded;

  String toJson() => name;
}

/// What `repsMin` / `repsMax` mean. v1 smuggled seconds through `repsMin`, so a
/// two-minute bag round rendered as "120 reps" (audit C6).
enum RepUnit {
  reps,
  sec,
  m;

  static RepUnit fromJson(String? v) => v == null
      ? RepUnit.reps
      : RepUnit.values.firstWhere(
          (e) => e.name == v,
          orElse: () => RepUnit.reps,
        );

  String get short => switch (this) {
    RepUnit.reps => '',
    RepUnit.sec => 's',
    RepUnit.m => 'm',
  };

  String toJson() => name;
}

/// Progression rule family.
enum ProgressionType {
  doubleProgression,
  repsOnly,
  timeOnly,
  bandProgression,
  cardioTable,
  none;

  static ProgressionType fromJson(String v) => ProgressionType.values
      .firstWhere((e) => e.name == v, orElse: () => ProgressionType.none);

  /// Only `doubleProgression` ever suggests a kilogram change.
  bool get suggestsKilograms => this == ProgressionType.doubleProgression;

  String toJson() => name;
}

/// Block role. Lets the UI render a test week and a deload week differently,
/// and lets the calendar know when the programme is over (audit C8).
enum BlockKind {
  intro,
  accumulation,
  deload,
  test;

  static BlockKind fromJson(String? v) => v == null
      ? BlockKind.accumulation
      : BlockKind.values.firstWhere(
          (e) => e.name == v,
          orElse: () => BlockKind.accumulation,
        );

  String toJson() => name;
}

/// How to resolve a fractional set count after `setMultiplier`.
///
/// v1 left this undefined, which made `3 * 0.5` a coin flip between 1 and 2
/// depending on who wrote the loader (audit C3).
enum SetRounding {
  up,
  down,
  nearest;

  static SetRounding fromJson(String? v) => v == null
      ? SetRounding.up
      : SetRounding.values.firstWhere(
          (e) => e.name == v,
          orElse: () => SetRounding.up,
        );

  /// Always clamped to at least one set — a deload never removes a movement.
  int apply(int sets, double multiplier) {
    final raw = sets * multiplier;
    final rounded = switch (this) {
      SetRounding.up => raw.ceil(),
      SetRounding.down => raw.floor(),
      SetRounding.nearest => raw.round(),
    };
    return rounded < 1 ? 1 : rounded;
  }

  String toJson() => name;
}

/// What happens at week `totalWeeks + 1`.
enum CompletionAction {
  seedNextCycle,
  repeat,
  stop;

  static CompletionAction fromJson(String v) => CompletionAction.values
      .firstWhere((e) => e.name == v, orElse: () => CompletionAction.stop);

  String toJson() => name;
}
