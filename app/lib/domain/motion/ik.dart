import 'dart:math' as math;

import 'vec.dart';

/// Where a two-bone limb puts its middle joint and its end.
class IkSolution {
  const IkSolution({
    required this.mid,
    required this.end,
    required this.reached,
    required this.miss,
  });

  /// The elbow or knee.
  final V2 mid;

  /// The hand or ankle.
  final V2 end;

  /// False when the target was too far, or too close, for this limb.
  final bool reached;

  /// How far [end] is from the target it was asked for, in world units.
  final double miss;
}

/// Two-bone inverse kinematics: a root (shoulder, hip), two bones of fixed
/// length, and a target for the end (hand, ankle).
///
/// Bone lengths hold exactly whatever the target: a target out of reach
/// straightens the limb towards it rather than stretching the shin, and a
/// target inside the limb's shortest reach folds it as far as it goes.
///
/// [bend] picks which side the middle joint goes: +1 anticlockwise of the
/// root-to-target line, -1 clockwise. For a figure facing +x with a leg
/// pointing down, +1 puts the knee forward.
IkSolution solveTwoBone({
  required V2 root,
  required V2 target,
  required double upper,
  required double lower,
  required int bend,
}) {
  final toTarget = target - root;
  final dist = toTarget.length;
  // A target sitting on the root has no direction; any stable one will do.
  final dir = dist < 1e-12 ? const V2(0, -1) : toTarget * (1 / dist);

  final minReach = (upper - lower).abs();
  final maxReach = upper + lower;
  final d = dist.clamp(minReach, maxReach);
  final reached = dist >= minReach - 1e-9 && dist <= maxReach + 1e-9;

  // Law of cosines for the angle between the upper bone and the reach line.
  final cosA = d < 1e-12
      ? 1.0
      : ((upper * upper + d * d - lower * lower) / (2 * upper * d)).clamp(
          -1.0,
          1.0,
        );
  final a = math.acos(cosA);
  final side = bend >= 0 ? 1 : -1;

  final mid = root + V2.polar(dir.angle + side * a, upper);
  final reachPoint = root + dir * d;
  // Re-derived from the middle joint rather than taken as reachPoint, so the
  // lower bone is exactly [lower] long however the float rounding fell.
  final toEnd = reachPoint - mid;
  final end = mid + (toEnd.length < 1e-12 ? dir : toEnd.unit) * lower;

  return IkSolution(
    mid: mid,
    end: end,
    reached: reached,
    miss: end.distanceTo(target),
  );
}
