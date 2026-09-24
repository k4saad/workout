import 'easing.dart';
import 'pose.dart';
import 'skeleton.dart';
import 'vec.dart';

/// What a limb is reaching for in one keyframe.
///
/// A limb uses ONE kind of target for a whole clip: blending a world point
/// into a joint angle has no meaning, so [MotionClip.fromJson] refuses it.
sealed class LimbTarget {
  const LimbTarget({this.s = 1, double? s2}) : s2 = s2 ?? s;

  factory LimbTarget.fromJson(Object? json) {
    if (json is! Map) throw FormatException('Limb target: $json');
    final sRaw = json['s'] ?? 1;
    final parts = sRaw is List ? sRaw : [sRaw, sRaw];
    if (parts.length != 2 || parts.any((v) => v is! num || v < 0.2 || v > 1)) {
      throw FormatException('Limb projection s must be 0.2..1, got $sRaw');
    }
    final s = (parts[0] as num).toDouble();
    final s2 = (parts[1] as num).toDouble();
    if (json.containsKey('at')) {
      return WorldTarget(V2.fromJson(json['at']), s: s, s2: s2);
    }
    if (json.containsKey('body')) {
      return BodyTarget(V2.fromJson(json['body']), s: s, s2: s2);
    }
    for (final key in const ['fk', 'fkb']) {
      if (!json.containsKey(key)) continue;
      final fk = json[key];
      if (fk is List && fk.length == 2 && fk.every((v) => v is num)) {
        final a = (fk[0] as num).toDouble();
        final b = (fk[1] as num).toDouble();
        return key == 'fk'
            ? AngleTarget(a, b, s: s, s2: s2)
            : BodyAngleTarget(a, b, s: s, s2: s2);
      }
      throw FormatException('$key must be [upper, lower] degrees: $fk');
    }
    throw FormatException('Limb target needs at, body, fk or fkb: $json');
  }

  /// How much of the upper bone's length shows on screen, 0.2..1. A bone
  /// that swings towards or away from the viewer is drawn shorter: a 2-D
  /// picture of a 3-D arm. JSON `"s": 0.8` sets both bones, `[0.5, 0.9]`
  /// each.
  final double s;

  /// The same, for the lower bone.
  final double s2;

  /// `at`, `body`, `fk` or `fkb`, for the one-mode-per-limb rule.
  String get mode;

  /// This target moved [u] of the way to [other] (same mode).
  LimbTarget lerpTo(LimbTarget other, double u);

  /// Moved [dx] along the floor; only world targets move.
  LimbTarget shifted(double dx) => this;

  double mixS(LimbTarget other, double u) => s + (other.s - s) * u;
  double mixS2(LimbTarget other, double u) => s2 + (other.s2 - s2) * u;
}

/// A fixed point in the world: a planted foot, a hand on the floor, a grip
/// on a bar that does not move.
final class WorldTarget extends LimbTarget {
  const WorldTarget(this.at, {super.s, super.s2});

  final V2 at;

  @override
  String get mode => 'at';

  @override
  LimbTarget lerpTo(LimbTarget other, double u) => WorldTarget(
    V2.lerp(at, (other as WorldTarget).at, u),
    s: mixS(other, u),
    s2: mixS2(other, u),
  );

  @override
  LimbTarget shifted(double dx) =>
      WorldTarget(V2(at.x + dx, at.y), s: s, s2: s2);
}

/// A point that rides on the trunk: `u` along the spine from the hip, `v`
/// out of the chest (side view) or towards the figure's left (front/back).
/// A bar on the upper back, a kettlebell held at the chest.
final class BodyTarget extends LimbTarget {
  const BodyTarget(this.local, {super.s, super.s2});

  final V2 local;

  @override
  String get mode => 'body';

  @override
  LimbTarget lerpTo(LimbTarget other, double u) => BodyTarget(
    V2.lerp(local, (other as BodyTarget).local, u),
    s: mixS(other, u),
    s2: mixS2(other, u),
  );
}

/// Joint angles, in world degrees: the upper bone, then the lower. A curl's
/// upper arm stays put while the forearm turns, which no reach target says.
final class AngleTarget extends LimbTarget {
  const AngleTarget(this.upper, this.lower, {super.s, super.s2});

  final double upper;
  final double lower;

  @override
  String get mode => 'fk';

  @override
  LimbTarget lerpTo(LimbTarget other, double u) {
    final o = other as AngleTarget;
    // Plain numbers, not shortest-arc: the author writes -60, 90, 240 for an
    // arm going over the head, and the arm goes over the head.
    return AngleTarget(
      upper + (o.upper - upper) * u,
      lower + (o.lower - lower) * u,
      s: mixS(other, u),
      s2: mixS2(other, u),
    );
  }
}

/// Joint angles relative to the spine: world angle = trunk + these. A front
/// rack, or hands behind the head, stays put on the torso as it tilts.
final class BodyAngleTarget extends LimbTarget {
  const BodyAngleTarget(this.upper, this.lower, {super.s, super.s2});

  final double upper;
  final double lower;

  @override
  String get mode => 'fkb';

  @override
  LimbTarget lerpTo(LimbTarget other, double u) {
    final o = other as BodyAngleTarget;
    return BodyAngleTarget(
      upper + (o.upper - upper) * u,
      lower + (o.lower - lower) * u,
      s: mixS(other, u),
      s2: mixS2(other, u),
    );
  }
}

/// One pose in a clip.
class Keyframe {
  const Keyframe({
    required this.t,
    required this.pelvis,
    required this.trunk,
    required this.limbs,
    this.ease = Ease.inOut,
    this.spine = 0,
    this.head = 0,
    this.feet = const {},
  });

  /// Position in the loop, 0 <= t < 1.
  final double t;

  /// How the clip moves from THIS keyframe to the next one.
  final Ease ease;

  /// The midpoint between the hip joints.
  final V2 pelvis;

  /// Direction of the spine, hip to shoulders, in degrees (90 = upright).
  final double trunk;

  /// Spinal flexion in degrees: positive rounds the back, negative arches it.
  final double spine;

  /// Head tilt from the line of the upper spine, degrees anticlockwise.
  final double head;

  final Map<Limb, LimbTarget> limbs;

  /// Foot angle in degrees; 0 is flat on the floor, pointing +x.
  final Map<Limb, double> feet;

  factory Keyframe.fromJson(Map<String, dynamic> j) {
    double num0(String k, [double fallback = 0]) {
      final v = j[k];
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      throw FormatException('keyframe.$k must be a number, got $v');
    }

    final limbs = <Limb, LimbTarget>{};
    final feet = <Limb, double>{};
    for (final l in Limb.values) {
      final raw = j[l.name];
      if (raw == null) {
        throw FormatException('keyframe at t=${j['t']} is missing ${l.name}');
      }
      limbs[l] = LimbTarget.fromJson(raw);
      if (l.isLeg && raw is Map && raw['foot'] is num) {
        feet[l] = (raw['foot'] as num).toDouble();
      }
    }
    final t = j['t'];
    if (t is! num) throw FormatException('keyframe.t missing: $j');

    return Keyframe(
      t: t.toDouble(),
      ease: j['ease'] == null ? Ease.inOut : Ease.parse(j['ease'] as String),
      pelvis: V2.fromJson(j['pelvis']),
      trunk: num0('trunk', 90),
      spine: num0('spine'),
      head: num0('head'),
      limbs: limbs,
      feet: feet,
    );
  }

  /// The same pose [dx] further along the floor.
  Keyframe shifted(double dx) => dx == 0
      ? this
      : Keyframe(
          t: t,
          ease: ease,
          pelvis: V2(pelvis.x + dx, pelvis.y),
          trunk: trunk,
          spine: spine,
          head: head,
          limbs: {for (final e in limbs.entries) e.key: e.value.shifted(dx)},
          feet: feet,
        );

  /// [a] moved [u] of the way to [b], stamped with time [t].
  static Keyframe blend(Keyframe a, Keyframe b, double u, double t) {
    double mix(double x, double y) => x + (y - x) * u;
    return Keyframe(
      t: t,
      ease: a.ease,
      pelvis: V2.lerp(a.pelvis, b.pelvis, u),
      trunk: mix(a.trunk, b.trunk),
      spine: mix(a.spine, b.spine),
      head: mix(a.head, b.head),
      limbs: {
        for (final l in Limb.values) l: a.limbs[l]!.lerpTo(b.limbs[l]!, u),
      },
      feet: {
        for (final l in const [Limb.legL, Limb.legR])
          l: mix(a.feet[l] ?? 0, b.feet[l] ?? 0),
      },
    );
  }
}

/// Where a prop is drawn relative to the body.
enum PropLayer {
  /// Behind everything: bench, rack, wall, heavy bag.
  back,

  /// With the far-side limbs, behind the trunk.
  far,

  /// In front of everything: the near plate, the near dumbbell.
  near;

  static PropLayer parse(Object? name) => PropLayer.values.firstWhere(
    (l) => l.name == name,
    orElse: () => throw FormatException('Unknown prop layer "$name"'),
  );
}

/// The body points a prop can hang off.
const propAttachments = {
  'handL', 'handR', 'hands', //
  'elbowL', 'elbowR', 'shoulderL', 'shoulderR',
  'hipL', 'hipR', 'kneeL', 'kneeR', 'ankleL', 'ankleR',
  'heelL', 'heelR', 'toeL', 'toeR',
  'pelvis', 'spineMid', 'neck', 'head',
};

/// A point a prop is drawn through: fixed in the world, a named joint, or a
/// point riding on the trunk (`{"body": [u, v]}`, as for [BodyTarget]).
class PropRef {
  const PropRef.world(V2 this.world) : attachment = null, trunk = null;
  const PropRef.body(String this.attachment) : world = null, trunk = null;
  const PropRef.trunk(V2 this.trunk) : world = null, attachment = null;

  final V2? world;
  final String? attachment;
  final V2? trunk;

  factory PropRef.fromJson(Object? json) {
    if (json is String) {
      if (!propAttachments.contains(json)) {
        throw FormatException('Unknown prop attachment "$json"');
      }
      return PropRef.body(json);
    }
    if (json is Map && json.containsKey('body')) {
      return PropRef.trunk(V2.fromJson(json['body']));
    }
    return PropRef.world(V2.fromJson(json));
  }
}

/// A piece of kit in the demo. The painter decides what [type] looks like;
/// the clip only says where it is.
class PropSpec {
  const PropSpec({
    required this.type,
    required this.points,
    required this.layer,
    this.params = const {},
  });

  final String type;
  final List<PropRef> points;
  final PropLayer layer;

  /// Sizes and the like (`r`, `h`, `len`), in centimetres or degrees.
  final Map<String, double> params;

  factory PropSpec.fromJson(Map<String, dynamic> j) {
    final type = j['type'];
    if (type is! String || type.isEmpty) {
      throw FormatException('Prop without a type: $j');
    }
    final pts = [
      for (final p in (j['pts'] as List? ?? const [])) PropRef.fromJson(p),
    ];
    final params = <String, double>{
      for (final e in j.entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    };
    final layer = j['layer'] != null
        ? PropLayer.parse(j['layer'])
        : (pts.every((p) => p.world != null) ? PropLayer.back : PropLayer.near);
    return PropSpec(type: type, points: pts, layer: layer, params: params);
  }
}

/// The box a clip moves inside over its whole loop, in camera space.
class MotionBounds {
  const MotionBounds(this.minX, this.minY, this.maxX, this.maxY);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  MotionBounds including(V2 p, [double r = 0]) => MotionBounds(
    p.x - r < minX ? p.x - r : minX,
    p.y - r < minY ? p.y - r : minY,
    p.x + r > maxX ? p.x + r : maxX,
    p.y + r > maxY ? p.y + r : maxY,
  );
}

/// One looping demo: keyframes, how they blend, and the kit in the scene.
class MotionClip {
  const MotionClip({
    required this.id,
    required this.name,
    required this.view,
    required this.periodMs,
    required this.bend,
    required this.keyframes,
    this.props = const [],
    this.travel = 0,
    this.still = 0,
    this.provenance = '',
    this.scales = const {},
    this.behind = const {},
  });

  final String id;
  final String name;
  final MotionView view;

  /// One loop, in milliseconds. Usually one rep at a teaching tempo.
  final int periodMs;

  /// +1 or -1 per limb: which side the elbow or knee goes (see
  /// [solveTwoBone]).
  final Map<Limb, int> bend;
  final List<Keyframe> keyframes;
  final List<PropSpec> props;

  /// How far the body moves along the floor in one loop. Walking and
  /// running clips travel; the camera follows, so the loop has no seam.
  final double travel;

  /// The moment shown when nothing animates: thumbnails, reduced motion.
  final double still;
  final String provenance;

  /// Per-limb projection factor, 0.6..1. A wide grip seen side-on reaches
  /// partly out of the picture, so the arm LOOKS shorter; drawing it full
  /// length would put the hands in the wrong place. Constant for the clip.
  final Map<Limb, double> scales;

  double scale(Limb l) => scales[l] ?? 1.0;

  /// Limbs drawn behind the trunk in a front or back view (a side view's
  /// far limbs always are).
  final Set<Limb> behind;

  factory MotionClip.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) throw FormatException('Clip without id');

    final bendJson = j['bend'];
    if (bendJson is! Map) throw FormatException('$id: no bend map');
    final bend = <Limb, int>{};
    for (final l in Limb.values) {
      final b = bendJson[l.name];
      if (b != 1 && b != -1) {
        throw FormatException('$id: bend.${l.name} must be 1 or -1, got $b');
      }
      bend[l] = b as int;
    }

    final frames = [
      for (final k in (j['keyframes'] as List? ?? const []))
        Keyframe.fromJson(k as Map<String, dynamic>),
    ];
    if (frames.isEmpty) throw FormatException('$id: no keyframes');
    if (frames.first.t != 0) {
      throw FormatException('$id: the first keyframe must be at t = 0');
    }
    for (var i = 1; i < frames.length; i++) {
      if (frames[i].t <= frames[i - 1].t || frames[i].t >= 1) {
        throw FormatException(
          '$id: keyframe times must rise and stay below 1 '
          '(${frames[i - 1].t} then ${frames[i].t})',
        );
      }
    }
    for (final l in Limb.values) {
      final modes = {for (final f in frames) f.limbs[l]!.mode};
      if (modes.length > 1) {
        throw FormatException('$id: ${l.name} mixes target kinds $modes');
      }
    }

    final scales = <Limb, double>{};
    for (final e in ((j['scale'] as Map?) ?? const {}).entries) {
      final v = e.value;
      if (v is! num || v < 0.6 || v > 1.0) {
        throw FormatException('$id: scale.${e.key} must be 0.6..1, got $v');
      }
      scales[Limb.parse(e.key)] = v.toDouble();
    }

    final period = j['periodMs'];
    if (period is! int || period <= 0) {
      throw FormatException('$id: periodMs must be a positive integer');
    }

    return MotionClip(
      id: id,
      name: j['name'] as String? ?? id,
      view: MotionView.parse(j['view']),
      periodMs: period,
      bend: bend,
      keyframes: frames,
      props: [
        for (final p in (j['props'] as List? ?? const []))
          PropSpec.fromJson(p as Map<String, dynamic>),
      ],
      travel: (j['travel'] as num? ?? 0).toDouble(),
      still: (j['still'] as num? ?? 0).toDouble(),
      provenance: j['provenance'] as String? ?? '',
      scales: scales,
      behind: {
        for (final l in (j['behind'] as List? ?? const [])) Limb.parse(l),
      },
    );
  }

  static double _wrap(double t) => t - t.floorToDouble();

  /// The blended pose parameters at [t] (any real; the clip loops).
  Keyframe specAt(double t) {
    final w = _wrap(t);
    var i = keyframes.length - 1;
    while (i > 0 && keyframes[i].t > w) {
      i--;
    }
    final a = keyframes[i];
    final last = i == keyframes.length - 1;
    final b = last ? keyframes.first.shifted(travel) : keyframes[i + 1];
    final bt = last ? 1.0 : b.t;
    final span = bt - a.t;
    final u = span <= 0 ? 0.0 : (w - a.t) / span;
    return Keyframe.blend(a, b, a.ease.apply(u), w);
  }

  /// The body, fully posed, at [t].
  Pose sample(Skeleton sk, double t) {
    final w = _wrap(t);
    return resolvePose(sk, this, specAt(w), t: w, drift: travel * w);
  }

  /// Everything the loop ever touches, head to sole and every prop, with
  /// the camera following a travelling clip.
  ///
  /// With [scenery] false, fixed kit behind the body (bench, rack, wall) is
  /// left out, so a small thumbnail spends its pixels on the lifter; the
  /// kit is still drawn, and may be cropped.
  MotionBounds bounds(Skeleton sk, {int samples = 60, bool scenery = true}) {
    final first = sample(sk, 0).pelvis;
    var b = MotionBounds(first.x, first.y, first.x, first.y);
    for (var i = 0; i < samples; i++) {
      final p = sample(sk, i / samples);
      V2 cam(V2 v) => V2(v.x - p.drift, v.y);
      for (final j in p.joints) {
        b = b.including(cam(j));
      }
      // The floor is always in the picture: a figure hanging from rings
      // with no ground under it reads as standing.
      b = b.including(V2(cam(p.pelvis).x, 0));
      b = b.including(cam(p.head), sk.headR);
      for (final f in [...p.heels.values, ...p.toes.values]) {
        b = b.including(cam(f));
      }
      for (final prop in p.props) {
        if (!scenery && prop.layer == PropLayer.back) continue;
        for (final pt in prop.points) {
          b = b.including(cam(pt));
        }
      }
    }
    return b;
  }
}
