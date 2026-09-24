import 'clip.dart';
import 'ik.dart';
import 'skeleton.dart';
import 'vec.dart';

/// One limb, posed.
class LimbPose {
  const LimbPose({
    required this.limb,
    required this.root,
    required this.mid,
    required this.end,
    required this.bend,
    required this.far,
    this.behind = false,
    this.target,
    this.miss = 0,
    this.scale = 1,
    this.scaleLower = 1,
  });

  final Limb limb;

  /// The share of the upper bone's true length drawn: the clip's
  /// foreshortening times the keyframe's.
  final double scale;

  /// The same for the lower bone.
  final double scaleLower;

  /// Shoulder or hip.
  final V2 root;

  /// Elbow or knee.
  final V2 mid;

  /// Grip or ankle.
  final V2 end;
  final int bend;

  /// The far side of a side view: drawn behind the trunk, in a darker grey.
  final bool far;

  /// Drawn behind the trunk: the far side, or a limb the clip puts there.
  final bool behind;

  /// What the limb was reaching for, when it was reaching for something.
  final V2? target;

  /// How far [end] fell short of [target].
  final double miss;

  /// Unit vector on the side the elbow or knee points to, square to the
  /// root-to-end line. The painter puts extensors on this side of a limb
  /// (quads, triceps) and flexors on the other (hamstrings, biceps).
  V2 get bendNormal {
    var axis = end - root;
    if (axis.length < 1e-9) axis = mid - root;
    final n = axis.unit.perpCcw;
    return bend >= 0 ? n : -n;
  }
}

/// A prop, placed.
class PropPose {
  const PropPose({
    required this.type,
    required this.points,
    required this.layer,
    required this.params,
    required this.t,
  });

  final String type;
  final List<V2> points;
  final PropLayer layer;
  final Map<String, double> params;

  /// Where the clip is in its loop, for props that move on their own (a
  /// turning rope).
  final double t;
}

/// The whole body at one instant, in world coordinates.
class Pose {
  const Pose({
    required this.view,
    required this.t,
    required this.drift,
    required this.trunk,
    required this.pelvis,
    required this.spineMid,
    required this.neck,
    required this.head,
    required this.headAngle,
    required this.anteriorLower,
    required this.anteriorUpper,
    required this.leftLower,
    required this.leftUpper,
    required this.limbs,
    required this.heels,
    required this.toes,
    required this.props,
  });

  final MotionView view;
  final double t;

  /// How far the camera has followed a travelling clip; subtract it from x
  /// to draw.
  final double drift;

  /// Spine chord direction, degrees.
  final double trunk;

  final V2 pelvis;
  final V2 spineMid;

  /// Top of the spine: the shoulder line.
  final V2 neck;

  /// Centre of the head.
  final V2 head;

  /// Direction from the neck to the head, radians.
  final double headAngle;

  /// Out of the chest, for the lower and upper spine. Side view only; zero
  /// in front and back views, where the chest faces the viewer or away.
  final V2 anteriorLower;
  final V2 anteriorUpper;

  /// Towards the figure's left. Front and back views only; zero side-on.
  final V2 leftLower;
  final V2 leftUpper;

  final Map<Limb, LimbPose> limbs;
  final Map<Limb, V2> heels;
  final Map<Limb, V2> toes;
  final List<PropPose> props;

  LimbPose operator [](Limb l) => limbs[l]!;

  /// Every joint centre, for bounds and floor checks.
  Iterable<V2> get joints sync* {
    yield pelvis;
    yield spineMid;
    yield neck;
    yield head;
    for (final l in limbs.values) {
      yield l.root;
      yield l.mid;
      yield l.end;
    }
  }
}

/// Turns blended keyframe parameters into a posed body.
Pose resolvePose(
  Skeleton sk,
  MotionClip clip,
  Keyframe spec, {
  required double t,
  required double drift,
}) {
  final view = clip.view;
  final side = view == MotionView.side;

  final chord = V2.polar(deg(spec.trunk));
  final lowerDir = V2.polar(deg(spec.trunk + spec.spine / 2));
  final upperDeg = spec.trunk - spec.spine / 2;
  final upperDir = V2.polar(deg(upperDeg));

  final pelvis = spec.pelvis;
  final spineMid = pelvis + lowerDir * (sk.trunk / 2);
  final neck = spineMid + upperDir * (sk.trunk / 2);
  final headAngle = deg(upperDeg + spec.head);
  final head = neck + V2.polar(headAngle, sk.neck + sk.headR);

  // Side-on, the clockwise perpendicular of the spine is out of the chest.
  // Facing the viewer it is the figure's left; from behind, the right.
  V2 left(V2 d) => switch (view) {
    MotionView.side => V2.zero,
    MotionView.front => d.perpCw,
    MotionView.back => d.perpCcw,
  };
  final anteriorLower = side ? lowerDir.perpCw : V2.zero;
  final anteriorUpper = side ? upperDir.perpCw : V2.zero;
  final bodyNormal = side ? chord.perpCw : left(chord);

  V2 rootOf(Limb l) {
    if (side) {
      final base = l.isArm ? neck : pelvis;
      return l.isLeft ? base : base + sk.depth;
    }
    final sign = l.isLeft ? 1.0 : -1.0;
    return l.isArm
        ? neck + left(upperDir) * (sk.shoulderHalf * sign)
        : pelvis + left(lowerDir) * (sk.hipHalf * sign);
  }

  final limbs = <Limb, LimbPose>{};
  for (final l in Limb.values) {
    final far = side && !l.isLeft;
    final behind = far || clip.behind.contains(l);
    final root = rootOf(l);
    final bend = clip.bend[l]!;
    final depth = far ? sk.depth : V2.zero;
    final target = spec.limbs[l]!;

    final scale = clip.scale(l) * target.s;
    final scaleLower = clip.scale(l) * target.s2;
    final upperLen = sk.upper(l) * scale;
    final lowerLen = sk.lower(l) * scaleLower;

    LimbPose angles(double upper, double lower) {
      final mid = root + V2.polar(deg(upper), upperLen);
      final end = mid + V2.polar(deg(lower), lowerLen);
      return LimbPose(
        limb: l,
        root: root,
        mid: mid,
        end: end,
        bend: bend,
        far: far,
        behind: behind,
        scale: scale,
        scaleLower: scaleLower,
      );
    }

    LimbPose reach(V2 at) {
      final s = solveTwoBone(
        root: root,
        target: at,
        upper: upperLen,
        lower: lowerLen,
        bend: bend,
      );
      return LimbPose(
        limb: l,
        root: root,
        mid: s.mid,
        end: s.end,
        bend: bend,
        far: far,
        behind: behind,
        target: at,
        miss: s.miss,
        scale: scale,
        scaleLower: scaleLower,
      );
    }

    limbs[l] = switch (target) {
      AngleTarget(:final upper, :final lower) => angles(upper, lower),
      BodyAngleTarget(:final upper, :final lower) => angles(
        spec.trunk + upper,
        spec.trunk + lower,
      ),
      WorldTarget(:final at) => reach(at + depth),
      BodyTarget(:final local) => reach(
        pelvis + chord * local.x + bodyNormal * local.y + depth,
      ),
    };
  }

  final heels = <Limb, V2>{};
  final toes = <Limb, V2>{};
  for (final l in const [Limb.legL, Limb.legR]) {
    final ankle = limbs[l]!.end;
    final shape = side ? sk.foot : sk.footFront;
    // Front and back views: the foot turns out, so it mirrors between the
    // two sides, and between the two views.
    final mirror = switch (view) {
      MotionView.side => false,
      MotionView.front => !l.isLeft,
      MotionView.back => l.isLeft,
    };
    final a = deg(spec.feet[l] ?? 0);
    V2 place(V2 local) {
      final p = mirror ? V2(-local.x, local.y) : local;
      final r = V2.polar(a);
      return ankle + V2(p.x * r.x - p.y * r.y, p.x * r.y + p.y * r.x);
    }

    heels[l] = place(shape.heel);
    toes[l] = place(shape.toe);
  }

  V2 attach(String name) => switch (name) {
    'handL' => limbs[Limb.armL]!.end,
    'handR' => limbs[Limb.armR]!.end,
    'hands' => V2.lerp(limbs[Limb.armL]!.end, limbs[Limb.armR]!.end, 0.5),
    'elbowL' => limbs[Limb.armL]!.mid,
    'elbowR' => limbs[Limb.armR]!.mid,
    'shoulderL' => limbs[Limb.armL]!.root,
    'shoulderR' => limbs[Limb.armR]!.root,
    'hipL' => limbs[Limb.legL]!.root,
    'hipR' => limbs[Limb.legR]!.root,
    'kneeL' => limbs[Limb.legL]!.mid,
    'kneeR' => limbs[Limb.legR]!.mid,
    'ankleL' => limbs[Limb.legL]!.end,
    'ankleR' => limbs[Limb.legR]!.end,
    'heelL' => heels[Limb.legL]!,
    'heelR' => heels[Limb.legR]!,
    'toeL' => toes[Limb.legL]!,
    'toeR' => toes[Limb.legR]!,
    'pelvis' => pelvis,
    'spineMid' => spineMid,
    'neck' => neck,
    'head' => head,
    _ => throw StateError('Unknown attachment $name'),
  };

  final props = [
    for (final p in clip.props)
      PropPose(
        type: p.type,
        points: [
          for (final r in p.points)
            r.world ??
                (r.trunk != null
                    ? pelvis + chord * r.trunk!.x + bodyNormal * r.trunk!.y
                    : attach(r.attachment!)),
        ],
        layer: p.layer,
        params: p.params,
        t: t,
      ),
  ];

  return Pose(
    view: view,
    t: t,
    drift: drift,
    trunk: spec.trunk,
    pelvis: pelvis,
    spineMid: spineMid,
    neck: neck,
    head: head,
    headAngle: headAngle,
    anteriorLower: anteriorLower,
    anteriorUpper: anteriorUpper,
    leftLower: left(lowerDir),
    leftUpper: left(upperDir),
    limbs: limbs,
    heels: heels,
    toes: toes,
    props: props,
  );
}
