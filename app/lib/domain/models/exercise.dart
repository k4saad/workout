import 'enums.dart';

/// Demo media for an exercise.
///
/// `still` and `youtubeUrl` ship as null on purpose — Phase 7 fills them.
/// `stillSearchTerm` is a matching hint for free-exercise-db, **not** a
/// verified slug, so expect misses rather than trusting it.
class ExerciseMedia {
  const ExerciseMedia({
    this.still,
    this.stillLicence,
    this.stillSearchTerm,
    this.youtubeUrl,
    this.youtubeStartSec = 0,
  });

  final String? still;
  final String? stillLicence;
  final String? stillSearchTerm;
  final String? youtubeUrl;
  final int youtubeStartSec;

  bool get hasVideo => youtubeUrl != null && youtubeUrl!.isNotEmpty;
  bool get hasStill => still != null && still!.isNotEmpty;

  factory ExerciseMedia.fromJson(Map<String, dynamic> j) => ExerciseMedia(
    still: j['still'] as String?,
    stillLicence: j['stillLicence'] as String?,
    stillSearchTerm: j['stillSearchTerm'] as String?,
    youtubeUrl: j['youtubeUrl'] as String?,
    youtubeStartSec: (j['youtubeStartSec'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'still': still,
    'stillLicence': stillLicence,
    'stillSearchTerm': stillSearchTerm,
    'youtubeUrl': youtubeUrl,
    'youtubeStartSec': youtubeStartSec,
  };
}

/// A library exercise. Separate from the programme so that swapping a movement
/// never loses its cues, and so history survives programme edits.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.pattern = '',
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment = const [],
    this.defaultLoadMode = LoadMode.bodyweight,
    this.cues = const [],
    this.commonErrors = const [],
    this.soloSafety,
    this.media = const ExerciseMedia(),
    this.substitutes = const [],
    this.tags = const [],
    this.equipmentNote,
    this.progressionNote,
  });

  final String id;
  final String name;
  final List<String> aliases;

  /// Movement pattern: squat, hinge, horizontalPush, verticalPull, etc.
  /// Drives the pattern-frequency check.
  final String pattern;

  /// Drives the weekly sets-per-muscle-group chart, so keep it honest.
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  final List<String> equipment;
  final LoadMode defaultLoadMode;
  final List<String> cues;
  final List<String> commonErrors;

  /// What can go wrong when there is nobody else in the room.
  final String? soloSafety;

  final ExerciseMedia media;
  final List<String> substitutes;
  final List<String> tags;
  final String? equipmentNote;
  final String? progressionNote;

  bool get isSoloRisk => tags.contains('soloRisk');
  bool get isMainLift => tags.contains('mainLift');

  /// Case-insensitive match against name and aliases, for library search.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (id.contains(q)) return true;
    return aliases.any((a) => a.toLowerCase().contains(q));
  }

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    aliases: (j['aliases'] as List?)?.cast<String>().toList() ?? const [],
    pattern: j['pattern'] as String? ?? '',
    primaryMuscles:
        (j['primaryMuscles'] as List?)?.cast<String>().toList() ?? const [],
    secondaryMuscles:
        (j['secondaryMuscles'] as List?)?.cast<String>().toList() ?? const [],
    equipment: (j['equipment'] as List?)?.cast<String>().toList() ?? const [],
    defaultLoadMode: LoadMode.fromJson(
      j['defaultLoadMode'] as String? ?? 'bodyweight',
    ),
    cues: (j['cues'] as List?)?.cast<String>().toList() ?? const [],
    commonErrors:
        (j['commonErrors'] as List?)?.cast<String>().toList() ?? const [],
    soloSafety: j['soloSafety'] as String?,
    media: j['media'] == null
        ? const ExerciseMedia()
        : ExerciseMedia.fromJson(j['media'] as Map<String, dynamic>),
    substitutes:
        (j['substitutes'] as List?)?.cast<String>().toList() ?? const [],
    tags: (j['tags'] as List?)?.cast<String>().toList() ?? const [],
    equipmentNote: j['equipmentNote'] as String?,
    progressionNote: j['progressionNote'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'aliases': aliases,
    'pattern': pattern,
    'primaryMuscles': primaryMuscles,
    'secondaryMuscles': secondaryMuscles,
    'equipment': equipment,
    'defaultLoadMode': defaultLoadMode.toJson(),
    'cues': cues,
    'commonErrors': commonErrors,
    'soloSafety': soloSafety,
    'media': media.toJson(),
    'substitutes': substitutes,
    'tags': tags,
    'equipmentNote': equipmentNote,
    'progressionNote': progressionNote,
  };

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exercise($id)';
}

/// The whole exercise library, indexed by id.
class ExerciseLibrary {
  ExerciseLibrary(this.exercises)
    : _byId = {for (final e in exercises) e.id: e};

  final List<Exercise> exercises;
  final Map<String, Exercise> _byId;

  Exercise? operator [](String id) => _byId[id];

  /// Never returns null: an unknown id yields a placeholder so a bad programme
  /// edit degrades to a name rather than crashing mid-session.
  Exercise resolve(String id) =>
      _byId[id] ?? Exercise(id: id, name: id.replaceAll('-', ' '));

  bool contains(String id) => _byId.containsKey(id);

  int get length => exercises.length;

  Iterable<Exercise> search(String query) =>
      exercises.where((e) => e.matches(query));

  Iterable<Exercise> byPattern(String pattern) =>
      exercises.where((e) => e.pattern == pattern);

  Iterable<Exercise> byMuscle(String muscle) => exercises.where(
    (e) =>
        e.primaryMuscles.contains(muscle) ||
        e.secondaryMuscles.contains(muscle),
  );

  Iterable<Exercise> byEquipment(String equipment) =>
      exercises.where((e) => e.equipment.contains(equipment));

  List<String> get allPatterns =>
      exercises
          .map((e) => e.pattern)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get allMuscles =>
      exercises.expand((e) => e.primaryMuscles).toSet().toList()..sort();

  List<String> get allEquipment =>
      exercises.expand((e) => e.equipment).toSet().toList()..sort();

  factory ExerciseLibrary.fromJson(Map<String, dynamic> j) => ExerciseLibrary(
    (j['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}
