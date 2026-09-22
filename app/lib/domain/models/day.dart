import 'package:collection/collection.dart';

import 'enums.dart';
import 'prescription.dart';

/// A warm-up or cool-down item.
///
/// Unlike v1's `freeItems` strings, each drill carries a real `exerciseId`, so
/// every drill is tappable through to its cues and demo. That is what closed
/// audit C16 — ten library exercises were previously unreachable.
///
/// Drills are **ticked, not logged**: they produce no set_logs rows and never
/// feed the progression engine.
class Drill {
  const Drill({
    required this.exerciseId,
    required this.order,
    required this.text,
    this.note,
  });

  final String exerciseId;
  final int order;

  /// The prescription as written, e.g. "6 x 30 s on / 30 s off".
  final String text;
  final String? note;

  factory Drill.fromJson(Map<String, dynamic> j) => Drill(
    exerciseId: j['exerciseId'] as String,
    order: (j['order'] as num).toInt(),
    text: j['text'] as String,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'order': order,
    'text': text,
    'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is Drill &&
      other.exerciseId == exerciseId &&
      other.order == order &&
      other.text == text &&
      other.note == note;

  @override
  int get hashCode => Object.hash(exerciseId, order, text, note);
}

/// A named group of work within a day.
class Section {
  const Section({
    required this.type,
    required this.title,
    this.estMinutes = 0,
    this.drills = const [],
    this.prescriptions = const [],
  });

  final SectionType type;
  final String title;
  final int estMinutes;
  final List<Drill> drills;
  final List<Prescription> prescriptions;

  /// Prescriptions in display order, with superset members kept adjacent.
  List<Prescription> get ordered =>
      [...prescriptions]..sort((a, b) => a.order.compareTo(b.order));

  /// Prescriptions grouped for display: each entry is either a single
  /// movement or the members of one superset, in order.
  ///
  /// The runner renders each group as ONE card — that is what makes the
  /// alternating structure legible mid-session.
  List<List<Prescription>> get groups {
    final result = <List<Prescription>>[];
    final seen = <String>{};
    for (final p in ordered) {
      final g = p.groupId;
      if (g == null) {
        result.add([p]);
      } else if (seen.add(g)) {
        result.add(ordered.where((q) => q.groupId == g).toList());
      }
    }
    return result;
  }

  factory Section.fromJson(Map<String, dynamic> j) => Section(
    type: SectionType.fromJson(j['type'] as String),
    title: j['title'] as String,
    estMinutes: (j['estMinutes'] as num?)?.toInt() ?? 0,
    drills: (j['drills'] as List? ?? const [])
        .map((e) => Drill.fromJson(e as Map<String, dynamic>))
        .toList(),
    prescriptions: (j['prescriptions'] as List? ?? const [])
        .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    'title': title,
    'estMinutes': estMinutes,
    'drills': drills.map((e) => e.toJson()).toList(),
    'prescriptions': prescriptions.map((e) => e.toJson()).toList(),
  };

  Section copyWith({
    SectionType? type,
    String? title,
    int? estMinutes,
    List<Drill>? drills,
    List<Prescription>? prescriptions,
  }) => Section(
    type: type ?? this.type,
    title: title ?? this.title,
    estMinutes: estMinutes ?? this.estMinutes,
    drills: drills ?? this.drills,
    prescriptions: prescriptions ?? this.prescriptions,
  );

  @override
  bool operator ==(Object other) =>
      other is Section &&
      other.type == type &&
      other.title == title &&
      other.estMinutes == estMinutes &&
      const ListEquality<Drill>().equals(other.drills, drills) &&
      const ListEquality<Prescription>().equals(
        other.prescriptions,
        prescriptions,
      );

  @override
  int get hashCode => Object.hash(
    type,
    title,
    estMinutes,
    const ListEquality<Drill>().hash(drills),
    const ListEquality<Prescription>().hash(prescriptions),
  );
}

/// A safety note rendered as a banner at the top of the session runner,
/// before the first set. The deadlift bar-height note lives here — it matters
/// before your first rep, not buried in a cue list.
class DayWarning {
  const DayWarning({required this.title, required this.body});

  final String title;
  final String body;

  factory DayWarning.fromJson(Map<String, dynamic> j) =>
      DayWarning(title: j['title'] as String, body: j['body'] as String);

  Map<String, dynamic> toJson() => {'title': title, 'body': body};

  @override
  bool operator ==(Object other) =>
      other is DayWarning && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// One day of the programme, keyed by weekday rather than by date.
class Day {
  const Day({
    required this.id,
    required this.weekday,
    required this.title,
    required this.kind,
    this.optional = false,
    this.estMinutes = 0,
    this.note,
    this.warnings = const [],
    this.sections = const [],
  });

  final String id;
  final Weekday weekday;
  final String title;
  final DayKind kind;

  /// Skipping an optional day does not break the adherence streak, and the
  /// calendar draws it with a dashed rail.
  final bool optional;

  /// Computed by `tools/gen.py` from the prescriptions, ramp sets and
  /// implement changes. Never typed by hand. Gate V11 fails the build if a
  /// lift day exceeds 60 minutes.
  final int estMinutes;

  final String? note;
  final List<DayWarning> warnings;
  final List<Section> sections;

  bool get isTrainingDay => kind != DayKind.rest;

  /// Every prescription in the day, in section then order sequence.
  Iterable<Prescription> get allPrescriptions =>
      sections.expand((s) => s.ordered);

  /// Only the prescriptions that get logged (main / finisher / cardio).
  Iterable<Prescription> get loggedPrescriptions =>
      sections.where((s) => s.type.isLogged).expand((s) => s.ordered);

  int get totalWorkingSets => loggedPrescriptions
      .where((p) => !p.optional)
      .fold(0, (a, p) => a + p.sets);

  factory Day.fromJson(Map<String, dynamic> j) => Day(
    id: j['id'] as String,
    weekday: Weekday.fromJson(j['weekday'] as String),
    title: j['title'] as String,
    kind: DayKind.fromJson(j['kind'] as String),
    optional: j['optional'] as bool? ?? false,
    estMinutes: (j['estMinutes'] as num?)?.toInt() ?? 0,
    note: j['note'] as String?,
    warnings: (j['warnings'] as List? ?? const [])
        .map((e) => DayWarning.fromJson(e as Map<String, dynamic>))
        .toList(),
    sections: (j['sections'] as List? ?? const [])
        .map((e) => Section.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekday': weekday.toJson(),
    'title': title,
    'kind': kind.toJson(),
    'optional': optional,
    'estMinutes': estMinutes,
    'note': note,
    'warnings': warnings.map((e) => e.toJson()).toList(),
    'sections': sections.map((e) => e.toJson()).toList(),
  };

  Day copyWith({
    String? id,
    Weekday? weekday,
    String? title,
    DayKind? kind,
    bool? optional,
    int? estMinutes,
    String? note,
    bool clearNote = false,
    List<DayWarning>? warnings,
    List<Section>? sections,
  }) => Day(
    id: id ?? this.id,
    weekday: weekday ?? this.weekday,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    optional: optional ?? this.optional,
    estMinutes: estMinutes ?? this.estMinutes,
    note: clearNote ? null : (note ?? this.note),
    warnings: warnings ?? this.warnings,
    sections: sections ?? this.sections,
  );

  /// Rebuilds the day by mapping every prescription. Used by the block
  /// resolver, which must never mutate the source programme.
  Day mapPrescriptions(Prescription Function(Prescription) f) => copyWith(
    sections: sections
        .map((s) => s.copyWith(prescriptions: s.prescriptions.map(f).toList()))
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      other is Day &&
      other.id == id &&
      other.weekday == weekday &&
      other.title == title &&
      other.kind == kind &&
      other.optional == optional &&
      other.estMinutes == estMinutes &&
      other.note == note &&
      const ListEquality<DayWarning>().equals(other.warnings, warnings) &&
      const ListEquality<Section>().equals(other.sections, sections);

  @override
  int get hashCode => Object.hash(
    id,
    weekday,
    title,
    kind,
    optional,
    estMinutes,
    note,
    const ListEquality<DayWarning>().hash(warnings),
    const ListEquality<Section>().hash(sections),
  );

  @override
  String toString() => 'Day($id, ${weekday.name}, $title)';
}
