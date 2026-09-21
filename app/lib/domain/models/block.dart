import 'package:collection/collection.dart';

import 'day.dart';
import 'enums.dart';

/// A training block: a contiguous set of programme weeks sharing a structure.
///
/// A block has EITHER its own `days` OR `inheritsDaysFrom`, never both and
/// never neither (gate V5). Inheritance is what lets Deload and Push reuse
/// Build's days without duplicating fifty prescriptions.
class Block {
  const Block({
    required this.id,
    required this.name,
    required this.weeks,
    this.blockKind = BlockKind.accumulation,
    this.defaultRir,
    this.loadMultiplier = 1.0,
    this.setMultiplier = 1.0,
    this.setRounding = SetRounding.up,
    this.includeSupersets = true,
    this.includeFinishers = true,
    this.summary,
    this.inheritsDaysFrom,
    this.dayOverrides = const {},
    this.days = const [],
  });

  final String id;
  final String name;
  final List<int> weeks;
  final BlockKind blockKind;

  /// Inherited by any prescription whose `targetRir` is null. v1 declared this
  /// on every block and never consumed it, so its deload softened nothing
  /// (audit C2). Gate V13 now fails the build if no prescription leaves
  /// `targetRir` null, which would make the field dead again.
  final int? defaultRir;

  final double loadMultiplier;
  final double setMultiplier;
  final SetRounding setRounding;

  /// False unwinds every `groupId` into straight sets. The deload uses this so
  /// nothing is rushed.
  final bool includeSupersets;
  final bool includeFinishers;

  final String? summary;
  final String? inheritsDaysFrom;

  /// `{ dayId: { prescriptionOverrides: {...}, weekSpecific: { "12": {...} } } }`
  final Map<String, dynamic> dayOverrides;

  final List<Day> days;

  bool get inherits => inheritsDaysFrom != null;
  bool get isDeload => blockKind == BlockKind.deload;
  bool get isTest => blockKind == BlockKind.test;

  bool coversWeek(int week) => weeks.contains(week);

  int get firstWeek => weeks.reduce((a, b) => a < b ? a : b);
  int get lastWeek => weeks.reduce((a, b) => a > b ? a : b);

  factory Block.fromJson(Map<String, dynamic> j) => Block(
    id: j['id'] as String,
    name: j['name'] as String,
    weeks: (j['weeks'] as List).map((e) => (e as num).toInt()).toList(),
    blockKind: BlockKind.fromJson(j['blockKind'] as String?),
    defaultRir: (j['defaultRir'] as num?)?.toInt(),
    loadMultiplier: (j['loadMultiplier'] as num?)?.toDouble() ?? 1.0,
    setMultiplier: (j['setMultiplier'] as num?)?.toDouble() ?? 1.0,
    setRounding: SetRounding.fromJson(j['setRounding'] as String?),
    includeSupersets: j['includeSupersets'] as bool? ?? true,
    includeFinishers: j['includeFinishers'] as bool? ?? true,
    summary: j['summary'] as String?,
    inheritsDaysFrom: j['inheritsDaysFrom'] as String?,
    dayOverrides:
        (j['dayOverrides'] as Map?)?.cast<String, dynamic>() ?? const {},
    days: (j['days'] as List? ?? const [])
        .map((e) => Day.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weeks': weeks,
    'blockKind': blockKind.toJson(),
    'defaultRir': defaultRir,
    'loadMultiplier': loadMultiplier,
    'setMultiplier': setMultiplier,
    'setRounding': setRounding.toJson(),
    'includeSupersets': includeSupersets,
    'includeFinishers': includeFinishers,
    'summary': summary,
    'inheritsDaysFrom': inheritsDaysFrom,
    'dayOverrides': dayOverrides,
    'days': days.map((e) => e.toJson()).toList(),
  };

  Block copyWith({
    String? id,
    String? name,
    List<int>? weeks,
    BlockKind? blockKind,
    int? defaultRir,
    double? loadMultiplier,
    double? setMultiplier,
    SetRounding? setRounding,
    bool? includeSupersets,
    bool? includeFinishers,
    String? summary,
    String? inheritsDaysFrom,
    bool clearInherits = false,
    Map<String, dynamic>? dayOverrides,
    List<Day>? days,
  }) => Block(
    id: id ?? this.id,
    name: name ?? this.name,
    weeks: weeks ?? this.weeks,
    blockKind: blockKind ?? this.blockKind,
    defaultRir: defaultRir ?? this.defaultRir,
    loadMultiplier: loadMultiplier ?? this.loadMultiplier,
    setMultiplier: setMultiplier ?? this.setMultiplier,
    setRounding: setRounding ?? this.setRounding,
    includeSupersets: includeSupersets ?? this.includeSupersets,
    includeFinishers: includeFinishers ?? this.includeFinishers,
    summary: summary ?? this.summary,
    inheritsDaysFrom: clearInherits
        ? null
        : (inheritsDaysFrom ?? this.inheritsDaysFrom),
    dayOverrides: dayOverrides ?? this.dayOverrides,
    days: days ?? this.days,
  );

  @override
  bool operator ==(Object other) =>
      other is Block &&
      other.id == id &&
      other.name == name &&
      const ListEquality<int>().equals(other.weeks, weeks) &&
      other.blockKind == blockKind &&
      other.defaultRir == defaultRir &&
      other.loadMultiplier == loadMultiplier &&
      other.setMultiplier == setMultiplier &&
      other.setRounding == setRounding &&
      other.includeSupersets == includeSupersets &&
      other.includeFinishers == includeFinishers &&
      other.inheritsDaysFrom == inheritsDaysFrom &&
      const ListEquality<Day>().equals(other.days, days);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    const ListEquality<int>().hash(weeks),
    blockKind,
    defaultRir,
    loadMultiplier,
    setMultiplier,
    setRounding,
    includeSupersets,
    includeFinishers,
    inheritsDaysFrom,
    const ListEquality<Day>().hash(days),
  );

  @override
  String toString() => 'Block($id, weeks $weeks, ${blockKind.name})';
}
