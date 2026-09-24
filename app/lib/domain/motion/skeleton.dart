import 'vec.dart';

/// Which way the demo looks at the body.
enum MotionView {
  /// Side-on, facing +x. The figure's left side is the near side.
  side,

  /// Facing the viewer. The figure's left is on the viewer's right.
  front,

  /// From behind. The figure's left is on the viewer's left.
  back;

  static MotionView parse(Object? name) => switch (name) {
    'side' => MotionView.side,
    'front' => MotionView.front,
    'back' => MotionView.back,
    _ => throw FormatException('Unknown view "$name"'),
  };
}

/// The four two-bone limbs.
///
/// In a side view the L limbs are the NEAR side and the R limbs are drawn
/// behind the body.
enum Limb {
  armL,
  armR,
  legL,
  legR;

  bool get isArm => this == Limb.armL || this == Limb.armR;
  bool get isLeg => !isArm;
  bool get isLeft => this == Limb.armL || this == Limb.legL;

  static Limb parse(Object? name) => Limb.values.firstWhere(
    (l) => l.name == name,
    orElse: () => throw FormatException('Unknown limb "$name"'),
  );
}

/// The sole of one foot, relative to the ankle, with the foot flat.
class FootShape {
  const FootShape({required this.heel, required this.toe});

  final V2 heel;
  final V2 toe;

  factory FootShape.fromJson(Map<String, dynamic> j) =>
      FootShape(heel: V2.fromJson(j['heel']), toe: V2.fromJson(j['toe']));
}

/// Body proportions, in centimetres.
///
/// Data, not code: they come from motions.json, where the generator derives
/// them from Saad's height. The painter reads [girth] for how thick each
/// segment is drawn; the rig only needs the lengths.
class Skeleton {
  const Skeleton({
    required this.trunk,
    required this.neck,
    required this.headR,
    required this.upperArm,
    required this.forearm,
    required this.thigh,
    required this.shin,
    required this.shoulderHalf,
    required this.hipHalf,
    required this.depth,
    required this.foot,
    required this.footFront,
    this.girth = const {},
  });

  /// Hip joint to shoulder joint, as two equal spine segments.
  final double trunk;

  /// Shoulder line to the bottom of the head.
  final double neck;
  final double headR;

  final double upperArm;

  /// Elbow to the middle of the grip.
  final double forearm;
  final double thigh;

  /// Knee to ankle joint.
  final double shin;

  /// Half the distance between the shoulder joints, for front and back views.
  final double shoulderHalf;
  final double hipHalf;

  /// Where the far side sits relative to the near side in a side view. A
  /// small offset back and up reads as depth rather than as a second person.
  final V2 depth;

  final FootShape foot;
  final FootShape footFront;

  /// Half-widths per segment, `[at the root, at the end]`, for the painter.
  final Map<String, List<double>> girth;

  double upper(Limb l) => l.isArm ? upperArm : thigh;
  double lower(Limb l) => l.isArm ? forearm : shin;

  factory Skeleton.fromJson(Map<String, dynamic> j) {
    double n(String k) {
      final v = j[k];
      if (v is num && v > 0) return v.toDouble();
      throw FormatException('skeleton.$k must be a positive number, got $v');
    }

    final girth = <String, List<double>>{};
    for (final MapEntry(:key, :value)
        in ((j['girth'] as Map?) ?? const {}).entries) {
      girth[key as String] = switch (value) {
        final num v => [v.toDouble()],
        final List<dynamic> v => [for (final x in v) (x as num).toDouble()],
        _ => throw FormatException('skeleton.girth.$key: $value'),
      };
    }

    return Skeleton(
      trunk: n('trunk'),
      neck: n('neck'),
      headR: n('headR'),
      upperArm: n('upperArm'),
      forearm: n('forearm'),
      thigh: n('thigh'),
      shin: n('shin'),
      shoulderHalf: n('shoulderHalf'),
      hipHalf: n('hipHalf'),
      depth: V2.fromJson(j['depth']),
      foot: FootShape.fromJson(j['foot'] as Map<String, dynamic>),
      footFront: FootShape.fromJson(j['footFront'] as Map<String, dynamic>),
      girth: girth,
    );
  }

  /// A segment's half-width at [u] along it (0 = root, 1 = end).
  double girthAt(String segment, double u, {double fallback = 3}) {
    final g = girth[segment];
    if (g == null || g.isEmpty) return fallback;
    if (g.length == 1) return g.first;
    final pos = u.clamp(0.0, 1.0) * (g.length - 1);
    final i = pos.floor().clamp(0, g.length - 2);
    final f = pos - i;
    return g[i] + (g[i + 1] - g[i]) * f;
  }
}
