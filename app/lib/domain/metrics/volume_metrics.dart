import '../models/exercise.dart';

/// One muscle group's week.
class MuscleVolume {
  const MuscleVolume({
    required this.muscle,
    required this.directSets,
    required this.indirectSets,
  });

  final String muscle;

  /// Sets where this muscle is a `primaryMuscle`. These are the ones that
  /// count.
  final int directSets;

  /// Sets where it is secondary. Counted separately and shown, but never
  /// added in — half-counting secondaries is how people talk themselves into
  /// believing a programme has more back volume than it does.
  final int indirectSets;

  bool get isLow => directSets < VolumeMetrics.lowSets;
  bool get isHigh => directSets > VolumeMetrics.highSets;
  bool get isInRange => !isLow && !isHigh;

  /// A glyph, so the state never depends on colour alone.
  String get glyph => isLow
      ? '↓'
      : isHigh
      ? '↑'
      : '✓';

  String get verdict => isLow
      ? 'below $directSets — under the ${VolumeMetrics.lowSets}-set floor'
      : isHigh
      ? 'above the ${VolumeMetrics.highSets}-set ceiling'
      : 'in range';
}

/// Weekly sets per muscle group — the number that actually drives growth.
///
/// Counted from `exercise.primaryMuscles`, never from the exercise name, so
/// an exercise swapped in the editor is counted correctly the same evening.
class VolumeMetrics {
  const VolumeMetrics(this.library);

  final ExerciseLibrary library;

  /// Below this, a muscle is being maintained rather than grown.
  static const int lowSets = 8;

  /// Above this, the extra sets mostly buy fatigue. For a beginner training
  /// alone on a 60-minute clock, going past it costs the next session.
  static const int highSets = 20;

  /// [setsByExercise] is exercise id -> working sets performed that week.
  ///
  /// Warm-up sets must already be excluded by the caller: a ramp is not
  /// stimulus and counting it inflates every number here.
  List<MuscleVolume> weekly(Map<String, int> setsByExercise) {
    final direct = <String, int>{};
    final indirect = <String, int>{};

    setsByExercise.forEach((exerciseId, sets) {
      if (sets <= 0) return;
      final exercise = library[exerciseId];
      if (exercise == null) return;
      for (final m in exercise.primaryMuscles) {
        direct[m] = (direct[m] ?? 0) + sets;
      }
      for (final m in exercise.secondaryMuscles) {
        indirect[m] = (indirect[m] ?? 0) + sets;
      }
    });

    final muscles = {...direct.keys, ...indirect.keys}.toList()..sort();
    return [
      for (final m in muscles)
        MuscleVolume(
          muscle: m,
          directSets: direct[m] ?? 0,
          indirectSets: indirect[m] ?? 0,
        ),
    ];
  }

  /// Only the ones worth saying out loud.
  List<MuscleVolume> flags(Map<String, int> setsByExercise) =>
      weekly(setsByExercise).where((v) => !v.isInRange).toList();
}
