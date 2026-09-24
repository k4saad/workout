import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/exercise_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/motion/motion.dart';
import 'motion_painter.dart';

/// The demo for one exercise: an original figure doing the movement, with
/// the muscles it trains in crimson.
///
/// Loads its clip from motions.json; an exercise with no clip (a custom one
/// added in the editor) shows a quiet placeholder rather than nothing.
class ExerciseDemo extends ConsumerWidget {
  const ExerciseDemo({
    super.key,
    required this.exerciseId,
    this.animate = true,
    this.paused = false,
    this.padding = 6,
    this.tight = false,
  });

  final String exerciseId;

  /// Frame the body, not the room: for small boxes.
  final bool tight;

  /// False for thumbnails: the clip's still frame, no ticker.
  final bool animate;

  /// Holds the frame it is on, to study a position.
  final bool paused;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motions = ref.watch(motionLibraryProvider).asData?.value;
    final library = ref.watch(libraryProvider).asData?.value;
    if (motions == null) return const SizedBox.expand();

    final clip = motions.forExercise(exerciseId);
    if (clip == null) {
      return const Center(
        child: Icon(Icons.fitness_center, color: AppTheme.textFaint),
      );
    }

    final ex = library?.resolve(exerciseId);
    final primary = motions.regionsForAll(ex?.primaryMuscles ?? const []);
    final secondary = motions
        .regionsForAll(ex?.secondaryMuscles ?? const [])
        .difference(primary);

    return Semantics(
      image: true,
      label: 'Demonstration of ${ex?.name ?? clip.name}',
      child: MotionFigure(
        clip: clip,
        skeleton: motions.skeleton,
        primary: primary,
        secondary: secondary,
        animate: animate && !AppMotion.reduced(context),
        paused: paused,
        padding: padding,
        tight: tight,
      ),
    );
  }
}

/// A [MotionClip] on a loop, or held on its still frame.
class MotionFigure extends StatefulWidget {
  const MotionFigure({
    super.key,
    required this.clip,
    required this.skeleton,
    this.primary = const {},
    this.secondary = const {},
    this.animate = true,
    this.paused = false,
    this.padding = 6,
    this.tight = false,
    this.at,
  });

  final MotionClip clip;
  final Skeleton skeleton;
  final Set<BodyRegion> primary;
  final Set<BodyRegion> secondary;
  final bool animate;

  /// Stops where it is, rather than jumping to the still frame.
  final bool paused;
  final double padding;

  /// Frame the body and what it holds, leaving the scenery to crop.
  final bool tight;

  /// Pins the figure to one moment of the loop (the screenshot sheet).
  final double? at;

  @override
  State<MotionFigure> createState() => _MotionFigureState();
}

class _MotionFigureState extends State<MotionFigure>
    with SingleTickerProviderStateMixin {
  /// A clip's bounds sample its whole loop; a library list would redo that
  /// for every row on every build. Keyed on the clip object, which the
  /// repository keeps for the life of the app.
  static final _boundsCache = Expando<MotionBounds>('motion bounds');
  static final _tightCache = Expando<MotionBounds>('tight motion bounds');

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.clip.periodMs),
  );
  late MotionBounds _bounds = _boundsFor(widget.clip);

  MotionBounds _boundsFor(MotionClip clip) => widget.tight
      ? _tightCache[clip] ??= clip.bounds(widget.skeleton, scenery: false)
      : _boundsCache[clip] ??= clip.bounds(widget.skeleton);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(MotionFigure old) {
    super.didUpdateWidget(old);
    if (old.clip != widget.clip ||
        old.skeleton != widget.skeleton ||
        old.tight != widget.tight) {
      _bounds = _boundsFor(widget.clip);
      _loop.duration = Duration(milliseconds: widget.clip.periodMs);
    }
    _sync();
  }

  void _sync() {
    if (widget.animate && widget.at == null && widget.paused) {
      _loop.stop();
    } else if (widget.animate && widget.at == null) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value = widget.at ?? widget.clip.still;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: MotionPainter(
          clip: widget.clip,
          skeleton: widget.skeleton,
          bounds: _bounds,
          progress: _loop,
          primary: widget.primary,
          secondary: widget.secondary,
          padding: widget.padding,
        ),
      ),
    );
  }
}
