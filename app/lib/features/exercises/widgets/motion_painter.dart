import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/motion/motion.dart';

/// Colours of the demo figure.
///
/// The body is grey so the one crimson on screen is the muscle doing the
/// work. The far side of a side view is a darker grey, so depth reads
/// without a second colour.
abstract final class FigureColours {
  static const near = Color(0xFFC7C9D1);
  static const nearTop = Color(0xFFD9DBE2);
  static const far = Color(0xFF5B5E68);
  static const outline = AppTheme.surface;
  static const primary = AppTheme.crimson;
  static const secondary = Color(0xFF8C1D33);
  static const primaryFar = Color(0xFF9E2238);
  static const secondaryFar = Color(0xFF5E1A28);
  static const steel = Color(0xFFA3A7B0);
  static const steelDark = Color(0xFF6D717B);
  static const iron = Color(0xFF26272C);
  static const ironRim = Color(0xFF5A5C65);
  static const pad = Color(0xFF3C3D45);
  static const padTop = Color(0xFF4C4E57);
  static const frame = Color(0xFF55585F);
  static const band = Color(0xFF8B8F9A);
  static const floor = AppTheme.outline;
  static const shadow = Color(0x66000000);
}

/// Draws one [Pose] of a [MotionClip], scaled to fit [bounds].
///
/// Repaints from [progress] (an AnimationController, or a fixed value for a
/// thumbnail) without rebuilding any widget.
class MotionPainter extends CustomPainter {
  /// Every prop type this painter can draw. motions.json may use no other
  /// (checked by tools/validate.py V18 and test/widget/motion_demo_test).
  static const propTypes = {
    'barbell', 'dumbbell', 'kettlebell', 'dowel', 'bench', 'box', //
    'platform', 'mat', 'rack', 'pullupBar', 'rings', 'band', 'cable',
    'bag', 'abWheel', 'wall', 'handles', 'towel', 'bar', 'jumpRope',
  };

  MotionPainter({
    required this.clip,
    required this.skeleton,
    required this.bounds,
    required this.progress,
    this.primary = const {},
    this.secondary = const {},
    this.padding = 6,
  }) : super(repaint: progress);

  final MotionClip clip;
  final Skeleton skeleton;
  final MotionBounds bounds;
  final ValueListenable<double> progress;
  final Set<BodyRegion> primary;
  final Set<BodyRegion> secondary;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pose = clip.sample(skeleton, progress.value);
    final f = _Frame.fit(bounds, size, pose.drift, padding, _margin());
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _Scene(canvas, f, pose, skeleton, primary, secondary).draw();
    canvas.restore();
  }

  /// World-space margin around the bounds: the thickest limb, plus the
  /// biggest prop radius, so plates and heads are never cut off.
  double _margin() {
    var r = 9.0;
    for (final p in clip.props) {
      final pr = p.params['r'];
      if (pr != null && pr > r) r = pr;
    }
    return r + 2;
  }

  @override
  bool shouldRepaint(MotionPainter old) =>
      old.clip != clip ||
      old.progress != progress ||
      old.primary != primary ||
      old.secondary != secondary;
}

/// World (cm, y up) to canvas (px, y down), with the camera following a
/// travelling clip.
class _Frame {
  _Frame(this.scale, this.ox, this.oy, this.drift, this.size);

  final double scale;
  final double ox;
  final double oy;
  final double drift;
  final Size size;

  factory _Frame.fit(
    MotionBounds b,
    Size size,
    double drift,
    double padding,
    double margin,
  ) {
    final bw = b.width + margin * 2;
    final bh = b.height + margin * 2;
    final s = math.min(
      (size.width - padding * 2) / bw,
      (size.height - padding * 2) / bh,
    );
    final cx = (b.minX + b.maxX) / 2;
    final cy = (b.minY + b.maxY) / 2;
    return _Frame(
      s,
      size.width / 2 - cx * s,
      size.height / 2 + cy * s,
      drift,
      size,
    );
  }

  Offset o(V2 v) => Offset(ox + (v.x - drift) * scale, oy - v.y * scale);

  double l(double worldLength) => worldLength * scale;

  /// Canvas x of a world x, without the camera drift (floor ticks).
  double floorY() => oy;
}

/// One muscle drawn inside a body part, clipped to its outline.
class _Belly {
  const _Belly(this.a, this.b, this.r, this.colour);

  final V2 a;
  final V2 b;
  final double r;
  final Color colour;
}

class _Scene {
  _Scene(this.canvas, this.f, this.pose, this.sk, this.primary, this.secondary);

  final Canvas canvas;
  final _Frame f;
  final Pose pose;
  final Skeleton sk;
  final Set<BodyRegion> primary;
  final Set<BodyRegion> secondary;

  bool get side => pose.view == MotionView.side;

  double get outlineWidth => (0.9 + f.scale * 0.9).clamp(1.0, 2.6);

  void draw() {
    _floor();
    _props(PropLayer.back);
    if (side) {
      _leg(Limb.legR);
      _arm(Limb.armR);
      _props(PropLayer.far);
      _trunk();
      _leg(Limb.legL);
      _arm(Limb.armL);
    } else {
      _props(PropLayer.far);
      for (final l in Limb.values.where((l) => pose[l].behind)) {
        l.isArm ? _arm(l) : _leg(l);
      }
      for (final l in const [Limb.legL, Limb.legR]) {
        if (!pose[l].behind) _leg(l);
      }
      _trunk();
      for (final l in const [Limb.armL, Limb.armR]) {
        if (!pose[l].behind) _arm(l);
      }
    }
    _props(PropLayer.near);
  }

  // ------------------------------------------------------------- floor --

  void _floor() {
    final y = f.floorY();
    final paint = Paint()
      ..color = FigureColours.floor
      ..strokeWidth = math.max(1, f.l(0.8));
    canvas.drawLine(Offset(0, y), Offset(f.size.width, y), paint);

    // A travelling clip moves over ticks, so the walk reads as a walk and
    // not as marching on the spot.
    if (pose.drift != 0) {
      const spacing = 40.0;
      final tick = Paint()
        ..color = FigureColours.floor
        ..strokeWidth = math.max(1, f.l(0.8));
      final first = ((pose.drift - 400) / spacing).floor();
      for (var k = first; k < first + 40; k++) {
        final x = f.o(V2(k * spacing, 0)).dx;
        if (x < 0 || x > f.size.width) continue;
        canvas.drawLine(Offset(x, y), Offset(x - f.l(4), y + f.l(4)), tick);
      }
    }

    // A soft shadow under whatever is on the floor.
    final xs = <double>[];
    for (final l in const [Limb.legL, Limb.legR]) {
      if (pose.heels[l]!.y < 12) xs.add(pose.heels[l]!.x);
      if (pose.toes[l]!.y < 12) xs.add(pose.toes[l]!.x);
    }
    if (pose.pelvis.y < 30) xs.add(pose.pelvis.x);
    if (pose.neck.y < 30) xs.add(pose.neck.x);
    if (xs.isNotEmpty) {
      final lo = xs.reduce(math.min) - 10;
      final hi = xs.reduce(math.max) + 10;
      final c = f.o(V2((lo + hi) / 2, 0));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: f.l(hi - lo), height: f.l(5)),
        Paint()
          ..color = FigureColours.shadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.l(2.5)),
      );
    }
  }

  // ------------------------------------------------------------- shapes --

  /// A tapered capsule, wound clockwise so overlapping pieces of one body
  /// part fill as one shape (and the outline stroke only shows outside).
  void _capsule(Path p, V2 a, V2 b, double ra, double rb) {
    final pa = f.o(a);
    final pb = f.o(b);
    final ra0 = f.l(ra);
    final rb0 = f.l(rb);
    p.addOval(Rect.fromCircle(center: pa, radius: ra0));
    p.addOval(Rect.fromCircle(center: pb, radius: rb0));
    final d = pb - pa;
    final len = d.distance;
    if (len < 0.01) return;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    final sinT = ((ra0 - rb0) / len).clamp(-0.95, 0.95);
    final cosT = math.sqrt(1 - sinT * sinT);
    final v1 = n * cosT - u * sinT;
    final v2 = -n * cosT - u * sinT;
    final pts = [pa + v1 * ra0, pb + v1 * rb0, pb + v2 * rb0, pa + v2 * ra0];
    // Shoelace sum > 0 is clockwise on a y-down canvas, like addOval.
    var area = 0.0;
    for (var i = 0; i < 4; i++) {
      final p0 = pts[i];
      final p1 = pts[(i + 1) % 4];
      area += p0.dx * p1.dy - p1.dx * p0.dy;
    }
    p.addPolygon(area >= 0 ? pts : pts.reversed.toList(), true);
  }

  /// A segment whose girth varies along it: one capsule per step.
  void _segment(Path p, V2 a, V2 b, String girth, List<double> fallback) {
    final g = sk.girth[girth] ?? fallback;
    if (g.length == 1) {
      _capsule(p, a, b, g.first, g.first);
      return;
    }
    for (var i = 0; i < g.length - 1; i++) {
      final a0 = V2.lerp(a, b, i / (g.length - 1));
      final b0 = V2.lerp(a, b, (i + 1) / (g.length - 1));
      _capsule(p, a0, b0, g[i], g[i + 1]);
    }
  }

  double _g(String girth, double u, double fallback) =>
      sk.girthAt(girth, u, fallback: fallback);

  void _part(Path path, Color fill, List<_Belly> bellies, {bool far = false}) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth * 2
        ..strokeJoin = StrokeJoin.round
        ..color = FigureColours.outline,
    );
    canvas.drawPath(path, Paint()..color = fill);
    if (bellies.isEmpty) return;
    canvas.save();
    canvas.clipPath(path);
    for (final b in bellies) {
      final p = Path();
      _capsule(p, b.a, b.b, b.r, b.r);
      canvas.drawPath(p, Paint()..color = b.colour);
    }
    canvas.restore();
  }

  Color? _muscle(BodyRegion r, {bool far = false}) {
    if (primary.contains(r)) {
      return far ? FigureColours.primaryFar : FigureColours.primary;
    }
    if (secondary.contains(r)) {
      return far ? FigureColours.secondaryFar : FigureColours.secondary;
    }
    return null;
  }

  /// Adds a belly for [region] if it is working, from [u0] to [u1] along
  /// a-b, pushed [off] along [n].
  void _belly(
    List<_Belly> out,
    BodyRegion region,
    V2 a,
    V2 b,
    double u0,
    double u1,
    V2 n,
    double off,
    double r, {
    bool far = false,
  }) {
    final c = _muscle(region, far: far);
    if (c == null) return;
    out.add(
      _Belly(V2.lerp(a, b, u0) + n * off, V2.lerp(a, b, u1) + n * off, r, c),
    );
  }

  // --------------------------------------------------------------- body --

  void _leg(Limb l) {
    final lp = pose[l];
    final far = lp.far;
    final hip = lp.root;
    final knee = lp.mid;
    final ankle = lp.end;
    final heel = pose.heels[l]!;
    final toe = pose.toes[l]!;

    final path = Path();
    _segment(path, hip, knee, 'thigh', const [7.5, 5.2]);
    _segment(path, knee, ankle, 'shin', const [4.8, 5.0, 3.0]);
    final foot = sk.girth['foot'] ?? const [3.0, 2.2];
    final ankleR = _g('shin', 1, 3.0);
    _capsule(path, ankle, V2.lerp(heel, toe, 0.15), ankleR, foot.first);
    _capsule(path, V2.lerp(heel, toe, 0.15), toe, foot.first, foot.last);

    final n = lp.bendNormal;
    final tg = _g('thigh', 0.5, 6.4);
    final sg = _g('shin', 0.35, 5.0);
    final bellies = <_Belly>[];
    final view = pose.view;
    if (view == MotionView.side) {
      _belly(
        bellies,
        BodyRegion.quads,
        hip,
        knee,
        0.15,
        0.82,
        n,
        tg * 0.5,
        tg * 0.62,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.hamstrings,
        hip,
        knee,
        0.2,
        0.85,
        -n,
        tg * 0.5,
        tg * 0.62,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.adductors,
        hip,
        knee,
        0.1,
        0.45,
        V2.zero,
        0,
        tg * 0.35,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.hipFlexors,
        hip,
        knee,
        -0.05,
        0.18,
        n,
        tg * 0.45,
        tg * 0.5,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.calves,
        knee,
        ankle,
        0.12,
        0.5,
        -n,
        sg * 0.45,
        sg * 0.7,
        far: far,
      );
      final back = -pose.anteriorLower;
      _belly(
        bellies,
        BodyRegion.glutes,
        hip,
        knee,
        -0.08,
        0.1,
        back,
        tg * 0.55,
        tg * 0.7,
        far: far,
      );
    } else {
      final front = view == MotionView.front;
      final outward = (lp.root - pose.pelvis).unit;
      if (front) {
        _belly(
          bellies,
          BodyRegion.quads,
          hip,
          knee,
          0.15,
          0.8,
          V2.zero,
          0,
          tg * 0.62,
        );
        _belly(
          bellies,
          BodyRegion.adductors,
          hip,
          knee,
          0.08,
          0.45,
          -outward,
          tg * 0.55,
          tg * 0.4,
        );
        _belly(
          bellies,
          BodyRegion.hipFlexors,
          hip,
          knee,
          -0.02,
          0.15,
          V2.zero,
          0,
          tg * 0.45,
        );
        // The inner calf shows either side of the shin from the front.
        _belly(
          bellies,
          BodyRegion.calves,
          knee,
          ankle,
          0.1,
          0.45,
          -outward,
          sg * 0.55,
          sg * 0.45,
        );
      } else {
        _belly(
          bellies,
          BodyRegion.hamstrings,
          hip,
          knee,
          0.2,
          0.85,
          V2.zero,
          0,
          tg * 0.6,
        );
        _belly(
          bellies,
          BodyRegion.calves,
          knee,
          ankle,
          0.1,
          0.5,
          V2.zero,
          0,
          sg * 0.75,
        );
        _belly(
          bellies,
          BodyRegion.glutes,
          hip,
          knee,
          -0.1,
          0.08,
          outward,
          tg * 0.2,
          tg * 0.8,
        );
      }
    }
    _part(
      path,
      far ? FigureColours.far : FigureColours.near,
      bellies,
      far: far,
    );
  }

  void _arm(Limb l) {
    final lp = pose[l];
    final far = lp.far;
    final shoulder = lp.root;
    final elbow = lp.mid;
    final hand = lp.end;

    final path = Path();
    _segment(path, shoulder, elbow, 'upperArm', const [5.0, 3.5]);
    _segment(path, elbow, hand, 'forearm', const [3.5, 2.5]);
    final handR = (sk.girth['hand'] ?? const [3.0]).first;
    path.addOval(Rect.fromCircle(center: f.o(hand), radius: f.l(handR)));

    final n = lp.bendNormal;
    final ug = _g('upperArm', 0.4, 4.0);
    final fg = _g('forearm', 0.3, 3.0);
    final dg = _g('upperArm', 0, 5.0);
    final bellies = <_Belly>[];
    final view = pose.view;

    // Deltoids sit on the shoulder cap. "Front" and "rear" are the chest's
    // front and back, not the arm's.
    final V2 fwd;
    final V2 out;
    if (view == MotionView.side) {
      fwd = pose.anteriorUpper;
      out = V2.zero;
    } else {
      fwd = V2.zero;
      out = (shoulder - pose.neck).unit;
    }
    final cap = V2.lerp(shoulder, elbow, 0.08);
    final capEnd = V2.lerp(shoulder, elbow, 0.3);
    if (view == MotionView.side) {
      _belly(
        bellies,
        BodyRegion.frontDelt,
        cap,
        capEnd,
        0,
        1,
        fwd,
        dg * 0.55,
        dg * 0.6,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.rearDelt,
        cap,
        capEnd,
        0,
        1,
        -fwd,
        dg * 0.55,
        dg * 0.6,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.sideDelt,
        cap,
        capEnd,
        0,
        0.8,
        V2.zero,
        0,
        dg * 0.55,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.triceps,
        shoulder,
        elbow,
        0.22,
        0.85,
        n,
        ug * 0.5,
        ug * 0.6,
        far: far,
      );
      _belly(
        bellies,
        BodyRegion.biceps,
        shoulder,
        elbow,
        0.25,
        0.85,
        -n,
        ug * 0.5,
        ug * 0.6,
        far: far,
      );
    } else {
      final front = view == MotionView.front;
      _belly(
        bellies,
        BodyRegion.sideDelt,
        cap,
        capEnd,
        0,
        1,
        out,
        dg * 0.45,
        dg * 0.6,
      );
      if (front) {
        _belly(
          bellies,
          BodyRegion.frontDelt,
          cap,
          capEnd,
          0,
          1,
          -out,
          dg * 0.25,
          dg * 0.55,
        );
        _belly(
          bellies,
          BodyRegion.biceps,
          shoulder,
          elbow,
          0.25,
          0.85,
          V2.zero,
          0,
          ug * 0.6,
        );
        // The outer head of the triceps edges the arm from the front.
        _belly(
          bellies,
          BodyRegion.triceps,
          shoulder,
          elbow,
          0.25,
          0.85,
          out,
          ug * 0.55,
          ug * 0.4,
        );
      } else {
        _belly(
          bellies,
          BodyRegion.rearDelt,
          cap,
          capEnd,
          0,
          1,
          -out,
          dg * 0.25,
          dg * 0.55,
        );
        _belly(
          bellies,
          BodyRegion.triceps,
          shoulder,
          elbow,
          0.22,
          0.85,
          V2.zero,
          0,
          ug * 0.6,
        );
      }
    }
    _belly(
      bellies,
      BodyRegion.forearms,
      elbow,
      hand,
      0.05,
      0.55,
      V2.zero,
      0,
      fg * 0.75,
      far: far,
    );

    _part(
      path,
      far ? FigureColours.far : FigureColours.near,
      bellies,
      far: far,
    );
  }

  void _trunk() {
    final pelvis = pose.pelvis;
    final mid = pose.spineMid;
    final neck = pose.neck;
    final lowerDir = (mid - pelvis).unit;
    final upperDir = (neck - mid).unit;

    final path = Path();
    final bellies = <_Belly>[];

    if (side) {
      final aL = pose.anteriorLower;
      final aU = pose.anteriorUpper;
      final g = sk.girth['trunkSide'] ?? const [10.0, 8.6, 8.4, 10.2, 8.5];
      // Pelvis, lower back, waist, chest, shoulder line: the spine runs
      // nearer the back than the front, so the chest sits forward of it.
      final pts = [
        pelvis + aL * 0.5,
        V2.lerp(pelvis, mid, 0.5) + aL * 0.8,
        mid + aL * 1.4,
        V2.lerp(mid, neck, 0.5) + aU * 1.6,
        neck - upperDir * 2.5 + aU * 0.6,
      ];
      for (var i = 0; i < pts.length - 1; i++) {
        final ri = g[i.clamp(0, g.length - 1)];
        final rj = g[(i + 1).clamp(0, g.length - 1)];
        _capsule(path, pts[i], pts[i + 1], ri, rj);
      }
      // The seat: glutes sit behind and below the hip joint.
      _capsule(
        path,
        pelvis - aL * 3.2 - lowerDir * 1.5,
        pelvis - aL * 1 + lowerDir * 3,
        8.2,
        8.0,
      );

      final cg = g.length > 3 ? g[3] : 10.0;
      final wg = g.length > 2 ? g[2] : 8.5;
      _belly(
        bellies,
        BodyRegion.chest,
        mid,
        neck,
        0.45,
        0.85,
        aU,
        cg * 0.75,
        cg * 0.5,
      );
      _belly(
        bellies,
        BodyRegion.abs,
        pelvis,
        mid,
        0.15,
        1.2,
        aL,
        wg * 0.8,
        wg * 0.42,
      );
      _belly(
        bellies,
        BodyRegion.obliques,
        pelvis,
        mid,
        0.3,
        1.0,
        aL,
        wg * 0.1,
        wg * 0.45,
      );
      _belly(
        bellies,
        BodyRegion.lats,
        mid,
        neck,
        0.0,
        0.6,
        -aU,
        cg * 0.45,
        cg * 0.5,
      );
      _belly(
        bellies,
        BodyRegion.upperBack,
        mid,
        neck,
        0.45,
        0.95,
        -aU,
        cg * 0.55,
        cg * 0.5,
      );
      _belly(
        bellies,
        BodyRegion.traps,
        mid,
        neck,
        0.85,
        1.05,
        -aU,
        cg * 0.3,
        cg * 0.45,
      );
      _belly(
        bellies,
        BodyRegion.lowerBack,
        pelvis,
        mid,
        0.15,
        1.1,
        -aL,
        wg * 0.75,
        wg * 0.4,
      );
      _belly(
        bellies,
        BodyRegion.glutes,
        pelvis,
        mid,
        -0.12,
        0.05,
        -aL,
        wg * 0.85,
        7.2,
      );
      _belly(
        bellies,
        BodyRegion.hipFlexors,
        pelvis,
        mid,
        -0.05,
        0.12,
        aL,
        wg * 0.85,
        3.5,
      );
      if (primary.contains(BodyRegion.heart) ||
          secondary.contains(BodyRegion.heart)) {
        final beat = 1 + 0.18 * math.pow(math.sin(pose.t * math.pi * 8), 8);
        final c = _muscle(BodyRegion.heart)!;
        final at = V2.lerp(mid, neck, 0.62) + aU * (cg * 0.45);
        bellies.add(_Belly(at, at, 3.0 * beat, c));
      }
    } else {
      final lU = pose.leftUpper;
      final lL = pose.leftLower;
      final g = sk.girth['trunkFront'] ?? const [14.0, 12.0, 15.5, 17.0];
      final hipW = g[0];
      final waistW = g.length > 1 ? g[1] : 12.0;
      final chestW = g.length > 2 ? g[2] : 15.5;
      final shoulderW = g.length > 3 ? g[3] : 17.0;
      final top = neck - upperDir * 1.5;
      final chest = V2.lerp(mid, neck, 0.55);
      final poly = [
        top + lU * shoulderW,
        chest + lU * chestW,
        mid + lL * waistW,
        pelvis + lL * hipW - lowerDir * 2,
        pelvis - lowerDir * 7,
        pelvis - lL * hipW - lowerDir * 2,
        mid - lL * waistW,
        chest - lU * chestW,
        top - lU * shoulderW,
      ];
      final pts = [for (final p in poly) f.o(p)];
      var area = 0.0;
      for (var i = 0; i < pts.length; i++) {
        final p0 = pts[i];
        final p1 = pts[(i + 1) % pts.length];
        area += p0.dx * p1.dy - p1.dx * p0.dy;
      }
      path.addPolygon(area >= 0 ? pts : pts.reversed.toList(), true);
      // Rounded shoulders and hips.
      for (final s in const [1.0, -1.0]) {
        _capsule(
          path,
          top + lU * (shoulderW - 5) * s,
          chest + lU * (chestW - 5) * s,
          5.5,
          5.5,
        );
        _capsule(
          path,
          pelvis + lL * (hipW - 6) * s - lowerDir * 2,
          mid + lL * (waistW - 6) * s,
          6,
          6,
        );
      }

      final front = pose.view == MotionView.front;
      for (final s in const [1.0, -1.0]) {
        if (front) {
          _belly(
            bellies,
            BodyRegion.chest,
            mid,
            neck,
            0.5,
            0.82,
            lU,
            s * 6.5,
            5.8,
          );
          _belly(
            bellies,
            BodyRegion.obliques,
            pelvis,
            mid,
            0.2,
            0.9,
            lL,
            s * (waistW - 2.5),
            3.2,
          );
          _belly(
            bellies,
            BodyRegion.traps,
            mid,
            neck,
            1.0,
            1.05,
            lU,
            s * 7,
            3.0,
          );
          _belly(
            bellies,
            BodyRegion.hipFlexors,
            pelvis,
            mid,
            -0.05,
            0.1,
            lL,
            s * (hipW - 7),
            3.2,
          );
        } else {
          _belly(
            bellies,
            BodyRegion.lats,
            mid,
            neck,
            0.0,
            0.65,
            lU,
            s * (chestW - 4.5),
            4.2,
          );
          _belly(
            bellies,
            BodyRegion.lowerBack,
            pelvis,
            mid,
            0.1,
            1.05,
            lL,
            s * 3.2,
            2.8,
          );
          _belly(
            bellies,
            BodyRegion.glutes,
            pelvis,
            mid,
            -0.2,
            0.0,
            lL,
            s * 6,
            6.2,
          );
          _belly(
            bellies,
            BodyRegion.traps,
            mid,
            neck,
            0.8,
            1.05,
            lU,
            s * 5,
            3.6,
          );
          _belly(
            bellies,
            BodyRegion.obliques,
            pelvis,
            mid,
            0.2,
            0.9,
            lL,
            s * (waistW - 2.5),
            3.2,
          );
        }
      }
      if (front) {
        _belly(
          bellies,
          BodyRegion.abs,
          pelvis,
          mid,
          0.05,
          1.3,
          V2.zero,
          0,
          4.8,
        );
      } else {
        _belly(
          bellies,
          BodyRegion.upperBack,
          mid,
          neck,
          0.35,
          0.9,
          V2.zero,
          0,
          7.0,
        );
      }
      if (front &&
          (primary.contains(BodyRegion.heart) ||
              secondary.contains(BodyRegion.heart))) {
        final beat = 1 + 0.18 * math.pow(math.sin(pose.t * math.pi * 8), 8);
        final at = V2.lerp(mid, neck, 0.66) + lU * 4;
        bellies.add(_Belly(at, at, 3.0 * beat, _muscle(BodyRegion.heart)!));
      }
    }

    // Neck and head belong to the same silhouette.
    final neckR = (sk.girth['neck'] ?? const [4.6]).first;
    final headDir = (pose.head - neck).unit;
    _capsule(
      path,
      neck - upperDir * 1.5,
      pose.head - headDir * sk.headR * 0.5,
      neckR,
      neckR,
    );
    path.addOval(
      Rect.fromCircle(center: f.o(pose.head), radius: f.l(sk.headR)),
    );

    _part(path, FigureColours.near, bellies);
    _face();
  }

  /// A hint of which way the head faces: side-on, a short brow line on the
  /// face side. Enough to read "looking up" from "looking down".
  void _face() {
    if (!side) return;
    final c = pose.head;
    final fwd = V2.polar(pose.headAngle).perpCw;
    final up = V2.polar(pose.headAngle);
    final from = c + fwd * (sk.headR * 0.55) + up * (sk.headR * 0.12);
    final to = c + fwd * (sk.headR * 0.98) + up * (sk.headR * 0.12);
    canvas.drawLine(
      f.o(from),
      f.o(to),
      Paint()
        ..color = FigureColours.far
        ..strokeWidth = math.max(1, f.l(1.6))
        ..strokeCap = StrokeCap.round,
    );
  }

  // -------------------------------------------------------------- props --

  void _props(PropLayer layer) {
    for (final p in pose.props) {
      if (p.type == 'jumpRope') {
        _jumpRope(p, layer);
        continue;
      }
      if (p.layer != layer) continue;
      switch (p.type) {
        case 'barbell':
          _barbell(p);
        case 'dumbbell':
          _dumbbell(p);
        case 'kettlebell':
          _kettlebell(p);
        case 'dowel':
          _dowel(p);
        case 'bench':
          _bench(p);
        case 'box':
          _box(p, FigureColours.pad, FigureColours.padTop);
        case 'platform':
          _box(p, FigureColours.iron, FigureColours.ironRim);
        case 'mat':
          _mat(p);
        case 'rack':
          _rack(p);
        case 'pullupBar':
          _pullupBar(p);
        case 'rings':
          _rings(p);
        case 'band':
          _band(p);
        case 'cable':
          _cable(p);
        case 'bag':
          _bag(p);
        case 'abWheel':
          _abWheel(p);
        case 'wall':
          _wall(p);
        case 'handles':
          _handles(p);
        case 'towel':
          _towel(p);
        case 'bar':
          _floorBar(p);
      }
    }
  }

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double worldWidth) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = math.max(1, f.l(worldWidth));

  void _plate(Offset c, double r) {
    canvas.drawCircle(c, r + outlineWidth, _fill(FigureColours.outline));
    canvas.drawCircle(c, r, _fill(FigureColours.iron));
    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.1)
        ..color = FigureColours.ironRim,
    );
    canvas.drawCircle(c, r * 0.62, _stroke(FigureColours.ironRim, 0.35));
    canvas.drawCircle(c, math.max(1.5, r * 0.16), _fill(FigureColours.steel));
  }

  void _barbell(PropPose p) {
    final r = f.l(p.params['r'] ?? 20);
    if (side || p.points.length < 2) {
      _plate(f.o(p.points.first), r);
      return;
    }
    // Front or back view: the bar runs through both hands, plates outside.
    final a = f.o(p.points[0]);
    final b = f.o(p.points[1]);
    final dir = (b - a) / (b - a).distance;
    final over = f.l(p.params['len'] ?? 26);
    final ea = a - dir * over;
    final eb = b + dir * over;
    canvas.drawLine(ea, eb, _stroke(FigureColours.steel, 2.6));
    for (final (end, s) in [(ea, 1.0), (eb, -1.0)]) {
      final plateC = end + dir * (f.l(6) * s);
      final rect = Rect.fromCenter(
        center: plateC,
        width: f.l(4.5),
        height: r * 2,
      );
      canvas.save();
      canvas.translate(plateC.dx, plateC.dy);
      canvas.rotate(math.atan2(dir.dy, dir.dx));
      canvas.translate(-plateC.dx, -plateC.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(outlineWidth),
          Radius.circular(f.l(1.5)),
        ),
        _fill(FigureColours.outline),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(f.l(1.5))),
        _fill(FigureColours.iron),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(f.l(1.5))),
        _stroke(FigureColours.ironRim, 0.5),
      );
      canvas.restore();
    }
  }

  void _dumbbell(PropPose p) {
    final r = f.l(p.params['r'] ?? 7.5);
    final c = f.o(p.points.first);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      _stroke(FigureColours.outline, 0)..strokeWidth = outlineWidth * 2,
    );
    canvas.drawPath(
      path,
      _fill(
        p.layer == PropLayer.far ? FigureColours.iron : const Color(0xFF34353B),
      ),
    );
    canvas.drawPath(path, _stroke(FigureColours.ironRim, 0.5));
    canvas.drawCircle(c, math.max(1.2, r * 0.28), _fill(FigureColours.steel));
  }

  void _kettlebell(PropPose p) {
    final c = f.o(p.points.first);
    final r = f.l(p.params['r'] ?? 8);
    final body = c + Offset(0, r * 0.95);
    canvas.drawCircle(body, r + outlineWidth, _fill(FigureColours.outline));
    canvas.drawCircle(body, r, _fill(const Color(0xFF34353B)));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.6),
      math.pi,
      math.pi,
      false,
      _stroke(FigureColours.steelDark, 1.4),
    );
  }

  void _dowel(PropPose p) {
    if (side || p.points.length < 2) {
      canvas.drawCircle(
        f.o(p.points.first),
        f.l(1.8),
        _fill(const Color(0xFFB08A5A)),
      );
      return;
    }
    final a = f.o(p.points[0]);
    final b = f.o(p.points[1]);
    final dir = (b - a) / (b - a).distance;
    canvas.drawLine(
      a - dir * f.l(14),
      b + dir * f.l(14),
      _stroke(const Color(0xFFB08A5A), 2.2),
    );
  }

  void _bench(PropPose p) {
    final pts = p.points;
    final thick = p.params['pad'] ?? 7;
    // Legs first, then the pad on top of them.
    final legs = _stroke(FigureColours.frame, 3);
    final first = pts.first;
    final last = pts.last;
    final seatEnd = pts.length > 2 ? pts[1] : last;
    for (final x in [first.x + 6, seatEnd.x - 6]) {
      final y = pts.length > 2 && x > seatEnd.x - 7 ? seatEnd.y : first.y;
      canvas.drawLine(f.o(V2(x, y - thick)), f.o(V2(x, 0)), legs);
    }
    if (pts.length > 2) {
      final strut = V2.lerp(seatEnd, last, 0.5);
      canvas.drawLine(
        f.o(strut),
        f.o(V2(seatEnd.x + (last.x - seatEnd.x) * 0.2, 0)),
        legs,
      );
    }
    canvas.drawLine(
      f.o(V2(first.x - 2, 0)),
      f.o(V2(seatEnd.x + 2, 0)),
      _stroke(FigureColours.frame, 2.5),
    );
    final pad = Path();
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      // The points are the TOP of the pad: it hangs below them, whichever
      // way the author ran the line.
      var n = (b - a).unit.perpCw;
      if (n.y > 0) n = -n;
      final a0 = a + n * (thick / 2);
      final b0 = b + n * (thick / 2);
      _capsule(pad, a0, b0, thick / 2, thick / 2);
    }
    canvas.drawPath(pad, _fill(FigureColours.pad));
  }

  void _box(PropPose p, Color body, Color top) {
    final a = p.points[0];
    final b = p.points[1];
    final rect = Rect.fromPoints(f.o(V2(a.x, a.y)), f.o(V2(b.x, 0)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(f.l(1.5))),
      _fill(body),
    );
    canvas.drawLine(
      f.o(V2(a.x + 1, a.y - 0.6)),
      f.o(V2(b.x - 1, a.y - 0.6)),
      _stroke(top, 1.2),
    );
  }

  void _mat(PropPose p) {
    final a = p.points[0];
    final b = p.points[1];
    final rect = Rect.fromPoints(f.o(V2(a.x, 1.6)), f.o(V2(b.x, 0)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(f.l(0.8))),
      _fill(const Color(0xFF2E3037)),
    );
  }

  void _rack(PropPose p) {
    final base = p.points[0];
    final top = p.points[1];
    final paint = _stroke(const Color(0xFF3A3C44), 4);
    canvas.drawLine(f.o(base), f.o(top), paint);
    canvas.drawLine(f.o(V2(base.x - 22, 0)), f.o(V2(base.x + 22, 0)), paint);
    final safety = p.params['safety'];
    if (safety != null) {
      // Spotter arms run front to back, centred on the bar path.
      canvas.drawLine(
        f.o(V2(base.x - 28, safety)),
        f.o(V2(base.x + 28, safety)),
        _stroke(const Color(0xFF4A4C55), 2.6),
      );
    }
    final hook = p.params['hook'];
    if (hook != null) {
      canvas.drawLine(
        f.o(V2(base.x, hook)),
        f.o(V2(base.x + 6, hook + 3)),
        _stroke(const Color(0xFF4A4C55), 2.2),
      );
    }
  }

  void _pullupBar(PropPose p) {
    final bar = p.points[0];
    if (!side && p.points.length > 1) {
      // Square-on: the bar runs across the picture, hung from two brackets.
      final end = p.points[1];
      final bracket = _stroke(const Color(0xFF3A3C44), 3);
      for (final e in [bar, end]) {
        canvas.drawLine(f.o(e), f.o(V2(e.x, e.y + 14)), bracket);
      }
      canvas.drawLine(f.o(bar), f.o(end), _stroke(FigureColours.steel, 2.6));
      return;
    }
    if (p.points.length > 1) {
      canvas.drawLine(
        f.o(bar),
        f.o(p.points[1]),
        _stroke(const Color(0xFF3A3C44), 3.5),
      );
    }
    canvas.drawCircle(f.o(bar), f.l(2.4), _fill(FigureColours.steel));
  }

  void _rings(PropPose p) {
    final anchor = p.points[0];
    final strap = _stroke(const Color(0xFF6B6F7A), 1.6);
    for (final hand in p.points.skip(1)) {
      final up = (anchor - hand).unit;
      final ringC = hand + up * 5.5;
      canvas.drawLine(f.o(anchor), f.o(hand + up * 11), strap);
      canvas.drawCircle(
        f.o(ringC),
        f.l(7),
        _stroke(const Color(0xFFB08A5A), 1.8),
      );
    }
  }

  void _band(PropPose p) {
    final paint = _stroke(FigureColours.band, p.params['w'] ?? 1.6);
    for (var i = 0; i < p.points.length - 1; i++) {
      canvas.drawLine(f.o(p.points[i]), f.o(p.points[i + 1]), paint);
    }
  }

  void _cable(PropPose p) {
    final pulley = p.points[0];
    final handle = p.points[1];
    // The column the pulley rides on.
    canvas.drawLine(
      f.o(V2(pulley.x + 5, 0)),
      f.o(V2(pulley.x + 5, math.max(pulley.y + 25, 150))),
      _stroke(const Color(0xFF3A3C44), 6),
    );
    canvas.drawLine(
      f.o(pulley),
      f.o(handle),
      _stroke(FigureColours.steel, 0.9),
    );
    canvas.drawCircle(f.o(pulley), f.l(4.5), _fill(FigureColours.steelDark));
    canvas.drawCircle(f.o(pulley), f.l(1.5), _fill(FigureColours.iron));
  }

  void _bag(PropPose p) {
    final anchor = p.points[0];
    final bottom = p.points[1];
    final w = p.params['w'] ?? 32;
    final top = V2(bottom.x, bottom.y + (p.params['len'] ?? 90));
    canvas.drawLine(f.o(anchor), f.o(top), _stroke(FigureColours.steelDark, 1));
    final rect = Rect.fromPoints(
      f.o(V2(top.x - w / 2, top.y)),
      f.o(V2(bottom.x + w / 2, bottom.y)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(f.l(6))),
      _fill(const Color(0xFF34353B)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(f.l(6))),
      _stroke(FigureColours.ironRim, 0.6),
    );
  }

  void _abWheel(PropPose p) {
    final c = f.o(p.points.first);
    final r = f.l(p.params['r'] ?? 9);
    canvas.drawCircle(c, r + outlineWidth, _fill(FigureColours.outline));
    canvas.drawCircle(c, r, _fill(FigureColours.iron));
    canvas.drawCircle(c, r * 0.72, _stroke(FigureColours.ironRim, 0.5));
    canvas.drawCircle(c, math.max(1.5, r * 0.2), _fill(FigureColours.steel));
  }

  void _wall(PropPose p) {
    final a = p.points[0];
    final b = p.points[1];
    canvas.drawLine(f.o(a), f.o(b), _stroke(const Color(0xFF34363E), 4));
  }

  void _handles(PropPose p) {
    for (final c in p.points) {
      final grip = f.o(c);
      final l = f.o(V2(c.x - 5, 0));
      final r = f.o(V2(c.x + 5, 0));
      final path = Path()
        ..moveTo(l.dx, l.dy)
        ..lineTo(grip.dx, grip.dy)
        ..lineTo(r.dx, r.dy);
      canvas.drawPath(path, _stroke(FigureColours.steelDark, 1.6));
      canvas.drawCircle(grip, f.l(1.8), _fill(FigureColours.steel));
    }
  }

  void _towel(PropPose p) {
    final c = p.points.first;
    final rect = Rect.fromPoints(f.o(V2(c.x - 8, 1.2)), f.o(V2(c.x + 8, 0)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(f.l(0.6))),
      _fill(const Color(0xFF6B6F7A)),
    );
  }

  /// A barbell lying on the floor, end-on (the Nordic anchor).
  void _floorBar(PropPose p) {
    _plate(f.o(p.points.first), f.l(p.params['r'] ?? 20));
  }

  /// The rope turns once a loop: overhead, in front, under the feet,
  /// behind. It is drawn with the back props when it is behind the body.
  void _jumpRope(PropPose p, PropLayer layer) {
    final phase = (p.t * (p.params['turns'] ?? 1)) % 1.0;
    final angle = phase * 2 * math.pi;
    final behind = math.sin(angle) < 0;
    if (layer != (behind ? PropLayer.back : PropLayer.near)) return;
    final a = p.points[0];
    final b = p.points[1];
    final mid = V2.lerp(a, b, 0.5);
    // Radius of the loop: from the hands to just clear the feet / head.
    final reach = p.params['reach'] ?? 95;
    final ctrl = V2(mid.x, mid.y + math.cos(angle) * reach * 2 - reach * 0.15);
    final path = Path()
      ..moveTo(f.o(a).dx, f.o(a).dy)
      ..quadraticBezierTo(f.o(ctrl).dx, f.o(ctrl).dy, f.o(b).dx, f.o(b).dy);
    canvas.drawPath(
      path,
      _stroke(behind ? FigureColours.steelDark : FigureColours.steel, 0.8),
    );
  }
}
