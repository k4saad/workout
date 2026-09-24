import 'clip.dart';
import 'skeleton.dart';

/// The parts of the figure the painter knows how to colour.
///
/// exercises.json names muscles in a coach's vocabulary ("grip", "legs",
/// "thoracicSpine"); motions.json maps each of those onto these.
enum BodyRegion {
  chest,
  frontDelt,
  sideDelt,
  rearDelt,
  traps,
  upperBack,
  lats,
  lowerBack,
  abs,
  obliques,
  glutes,
  hipFlexors,
  adductors,
  quads,
  hamstrings,
  calves,
  biceps,
  triceps,
  forearms,
  heart;

  /// Whether the painter draws this region in [view]. Side-on, everything
  /// is in the picture; square-on, the back of the body is hidden and so is
  /// the front.
  bool shownFrom(MotionView view) => switch (view) {
    MotionView.side => true,
    MotionView.front => !_backOnly.contains(this),
    MotionView.back => !_frontOnly.contains(this),
  };

  static const _frontOnly = {
    BodyRegion.chest,
    BodyRegion.frontDelt,
    BodyRegion.abs,
    BodyRegion.hipFlexors,
    BodyRegion.adductors,
    BodyRegion.quads,
    BodyRegion.biceps,
    BodyRegion.heart,
  };

  static const _backOnly = {
    BodyRegion.rearDelt,
    BodyRegion.upperBack,
    BodyRegion.lats,
    BodyRegion.lowerBack,
    BodyRegion.glutes,
    BodyRegion.hamstrings,
  };

  static BodyRegion parse(Object? name) => BodyRegion.values.firstWhere(
    (r) => r.name == name,
    orElse: () => throw FormatException('Unknown body region "$name"'),
  );
}

/// Every demo in the app, and which exercise shows which.
class MotionLibrary {
  const MotionLibrary({
    required this.skeleton,
    required this.clips,
    required this.exerciseClips,
    required this.exerciseProvenance,
    required this.muscles,
  });

  final Skeleton skeleton;
  final Map<String, MotionClip> clips;

  /// Exercise id to clip id.
  final Map<String, String> exerciseClips;
  final Map<String, String> exerciseProvenance;

  /// Muscle name (as exercises.json writes it) to the regions drawn for it.
  final Map<String, Set<BodyRegion>> muscles;

  /// The demo for an exercise, or null for one the file does not cover (a
  /// custom exercise added in the editor, say).
  MotionClip? forExercise(String exerciseId) {
    final clipId = exerciseClips[exerciseId];
    return clipId == null ? null : clips[clipId];
  }

  Set<BodyRegion> regionsFor(String muscle) => muscles[muscle] ?? const {};

  Set<BodyRegion> regionsForAll(Iterable<String> muscles) => {
    for (final m in muscles) ...regionsFor(m),
  };

  factory MotionLibrary.fromJson(Map<String, dynamic> j) {
    final skeleton = Skeleton.fromJson(j['skeleton'] as Map<String, dynamic>);

    final clips = <String, MotionClip>{};
    for (final c in (j['clips'] as List? ?? const [])) {
      final clip = MotionClip.fromJson(c as Map<String, dynamic>);
      if (clips.containsKey(clip.id)) {
        throw FormatException('Duplicate clip id ${clip.id}');
      }
      clips[clip.id] = clip;
    }

    final byExercise = <String, String>{};
    final provenance = <String, String>{};
    for (final e in (j['exercises'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final exerciseId = m['exerciseId'] as String;
      final clipId = m['clip'] as String;
      if (!clips.containsKey(clipId)) {
        throw FormatException('$exerciseId points at missing clip $clipId');
      }
      byExercise[exerciseId] = clipId;
      provenance[exerciseId] = m['provenance'] as String? ?? '';
    }

    final muscles = <String, Set<BodyRegion>>{
      for (final e in ((j['muscles'] as Map?) ?? const {}).entries)
        e.key as String: {for (final r in e.value as List) BodyRegion.parse(r)},
    };

    return MotionLibrary(
      skeleton: skeleton,
      clips: clips,
      exerciseClips: byExercise,
      exerciseProvenance: provenance,
      muscles: muscles,
    );
  }
}
