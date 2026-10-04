import 'dart:math' as math;
import 'dart:typed_data';

import '../run/geo.dart';
import 'height_grid.dart';

/// Colours for the model, as 0xAARRGGBB: the domain picks none of its own.
class TerrainStyle {
  const TerrainStyle({
    required this.low,
    required this.high,
    required this.fog,
    required this.wall,
    required this.curtain,
    this.contour = 0x30FFFFFF,
    this.contourMajor = 0x66FFFFFF,
  });

  /// The valley floor and the summits; slopes are lit between them.
  final int low;
  final int high;

  /// What distance fades into: the page behind the model.
  final int fog;

  /// The sides of the block the land stands on.
  final int wall;

  /// The sheet hung under the trail when there is no terrain to lie on.
  final int curtain;

  /// Contour lines, and every fifth one.
  final int contour;
  final int contourMajor;
}

/// Where the eye is: on a sphere round a point, looking at it.
///
/// World axes are metres: x east, y north, z up. An [azimuth] of 0 looks
/// north from the south; it turns clockwise seen from above.
class OrbitCamera {
  const OrbitCamera({
    required this.azimuth,
    required this.elevation,
    required this.distance,
    this.targetZ = 0,
    this.fov = 0.75,
  });

  final double azimuth;
  final double elevation;
  final double distance;
  final double targetZ;

  /// Field of view across the shorter side of the screen, radians.
  final double fov;

  double get eyeX => distance * math.cos(elevation) * math.sin(azimuth);
  double get eyeY => -distance * math.cos(elevation) * math.cos(azimuth);
  double get eyeZ => targetZ + distance * math.sin(elevation);

  OrbitCamera copyWith({
    double? azimuth,
    double? elevation,
    double? distance,
  }) => OrbitCamera(
    azimuth: azimuth ?? this.azimuth,
    elevation: elevation ?? this.elevation,
    distance: distance ?? this.distance,
    targetZ: targetZ,
    fov: fov,
  );
}

/// [camera] on a [width] × [height] screen: world metres to pixels.
class Projector {
  Projector(this.camera, this.width, this.height) {
    ex = camera.eyeX;
    ey = camera.eyeY;
    ez = camera.eyeZ;
    // Forward: from the eye to the target.
    var fx = -ex, fy = -ey, fz = camera.targetZ - ez;
    final fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    fx /= fl;
    fy /= fl;
    fz /= fl;
    // Right: forward × up(0, 0, 1).
    var rx = fy, ry = -fx;
    final rl = math.sqrt(rx * rx + ry * ry);
    rx /= rl;
    ry /= rl;
    // Up: right × forward.
    final ux = ry * fz;
    final uy = -rx * fz;
    final uz = rx * fy - ry * fx;
    _f = (fx, fy, fz);
    _r = (rx, ry);
    _u = (ux, uy, uz);
    focal = math.min(width, height) / 2 / math.tan(camera.fov / 2);
  }

  final OrbitCamera camera;
  final double width;
  final double height;

  late final double ex;
  late final double ey;
  late final double ez;
  late final double focal;
  late final (double, double, double) _f;
  late final (double, double) _r;
  late final (double, double, double) _u;

  /// Nothing nearer than this is drawn: it is behind, or in, the eye.
  static const near = 1.0;

  /// Depth of a world point along the view; at or under [near] it is not
  /// on screen.
  double depthOf(double x, double y, double z) =>
      (x - ex) * _f.$1 + (y - ey) * _f.$2 + (z - ez) * _f.$3;

  /// Screen x of a world point at [depth].
  double screenX(double x, double y, double depth) =>
      width / 2 + focal * ((x - ex) * _r.$1 + (y - ey) * _r.$2) / depth;

  /// Screen y of a world point at [depth].
  double screenY(double x, double y, double z, double depth) =>
      height / 2 -
      focal * ((x - ex) * _u.$1 + (y - ey) * _u.$2 + (z - ez) * _u.$3) / depth;
}

/// A stretch of the trail on screen, all of it seen or all of it behind a
/// hill: x, y pairs.
class TrailRun {
  const TrailRun(this.visible, this.xy);

  final bool visible;
  final Float32List xy;
}

/// One frame of the model: triangles in back-to-front order, with a colour
/// per corner, then the trail over them.
class TerrainFrame {
  const TerrainFrame({
    required this.positions,
    required this.colours,
    required this.vertexCount,
    required this.trail,
    this.start,
    this.head,
  });

  /// x, y pairs; three vertices to a triangle. Only the first
  /// [vertexCount] are this frame's.
  final Float32List positions;
  final Int32List colours;
  final int vertexCount;

  final List<TrailRun> trail;

  /// Where the trail begins, and where its drawing-in has got to; null when
  /// off screen.
  final ({double x, double y})? start;
  final ({double x, double y})? head;
}

/// A trail point placed in the scene.
class _TrailPoint {
  const _TrailPoint(this.x, this.y, this.z, this.along, this.breakBefore);

  final double x;
  final double y;
  final double z;

  /// Metres along the trail, pauses not counted.
  final double along;

  /// The first point after a pause: no line joins it to the one before.
  final bool breakBefore;
}

/// A hike's country, ready to draw from any angle: the land as a lit block,
/// the trail lying on it.
///
/// Without terrain ([hasTerrain] false) the land is a level floor and the
/// trail stands at the phone's own GPS heights, a sheet hung beneath it, so
/// the climb still reads — and nothing pretends to be ground it is not.
class TerrainScene {
  TerrainScene({
    required this.grid,
    required List<List<RunFix>> trail,
    required this.style,
    this.hasTerrain = true,
    double? exaggeration,
    double maxTrailPoints = 700,
  }) {
    final relief = grid.maxH - grid.minH;
    final extent = math.max(grid.widthM, grid.depthM);
    final trailRelief = _trailRelief(trail);
    this.exaggeration =
        exaggeration ??
        autoExaggeration(hasTerrain ? relief : trailRelief, extent);
    _buildLand();
    _buildTrail(trail, maxTrailPoints);
  }

  final HeightGrid grid;
  final TerrainStyle style;
  final bool hasTerrain;

  /// Heights are multiplied by this, so gentle country still reads as
  /// country. Shown on screen whenever it is not 1.
  late final double exaggeration;

  /// The bottom of the block, and the highest thing in the scene.
  late final double baseZ;
  late final double topZ;

  late final Float32List _world;
  late final Int32List _lit;
  late final Float32List _cellX;
  late final Float32List _cellY;

  /// Contour segments, cell by cell: x1 y1 z1 x2 y2 z2 each, the cell's
  /// run of them from [_contourStart].
  Float32List _contours = Float32List(0);
  Uint8List _contourMajor = Uint8List(0);
  Int32List _contourStart = Int32List(0);

  /// Metres between contour lines; null when there are none (no terrain,
  /// or nothing worth contouring).
  double? contourIntervalM;
  late final List<_TrailPoint> _trail;

  /// Metres along the trail, pauses not counted.
  late final double trailLengthM;

  Float32List _positions = Float32List(0);
  Int32List _colours = Int32List(0);

  /// The factor that makes [reliefM] of height stand at least a fifth of
  /// [extentM]: x1 for real mountains, up to x5 for river country.
  static double autoExaggeration(double reliefM, double extentM) {
    if (reliefM < 1 || extentM <= 0) return 1;
    return (0.2 * extentM / reliefM).clamp(1.0, 5.0);
  }

  static double _trailRelief(List<List<RunFix>> trail) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final s in trail) {
      for (final f in s) {
        final a = f.altitudeM;
        if (a == null) continue;
        lo = math.min(lo, a);
        hi = math.max(hi, a);
      }
    }
    return hi > lo ? hi - lo : 0;
  }

  double _z(double metres) => (metres - grid.minH) * exaggeration;

  /// Ground height under local ([x], [y]), in scene units.
  double groundZ(double x, double y) => _z(grid.heightAtLocal(x, y));

  void _buildLand() {
    final cols = grid.cols, rows = grid.rows;
    _world = Float32List(cols * rows * 3);
    _lit = Int32List(cols * rows);
    final relief = grid.maxH - grid.minH;
    final dx = grid.widthM / (cols - 1);
    final dy = grid.depthM / (rows - 1);
    // Light from the north-west, 35 degrees up: the hillshade every relief
    // map uses, because it reads as up rather than down; low, so a slope
    // turned away from it goes properly dark.
    const lx = -0.5792, ly = 0.5792, lz = 0.5736;
    var top = 0.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final h = grid.at(c, r);
        final z = _z(h);
        top = math.max(top, z);
        _world[i * 3] = grid.xOfCol(c);
        _world[i * 3 + 1] = grid.yOfRow(r);
        _world[i * 3 + 2] = z;

        final hw = grid.at(math.max(0, c - 1), r);
        final he = grid.at(math.min(cols - 1, c + 1), r);
        final hn = grid.at(c, math.max(0, r - 1));
        final hs = grid.at(c, math.min(rows - 1, r + 1));
        final spanX = dx * ((c > 0 ? 1 : 0) + (c < cols - 1 ? 1 : 0));
        final spanY = dy * ((r > 0 ? 1 : 0) + (r < rows - 1 ? 1 : 0));
        final gx = spanX == 0 ? 0.0 : (he - hw) * exaggeration / spanX;
        final gy = spanY == 0 ? 0.0 : (hn - hs) * exaggeration / spanY;
        final nl = math.sqrt(gx * gx + gy * gy + 1);
        final lambert = math.max(0.0, (-gx * lx - gy * ly + lz) / nl);
        final t = relief < 1 ? 0.0 : (h - grid.minH) / relief;
        final base = _mix(style.low, style.high, math.pow(t, 0.8).toDouble());
        _lit[i] = _scale(base, 0.2 + 0.8 * lambert);
      }
    }
    topZ = top;
    final extent = math.max(grid.widthM, grid.depthM);
    baseZ = -math.max(extent * 0.03, top * 0.18);

    final cells = (cols - 1) * (rows - 1);
    _cellX = Float32List(cells);
    _cellY = Float32List(cells);
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        _cellX[r * (cols - 1) + c] = (grid.xOfCol(c) + grid.xOfCol(c + 1)) / 2;
        _cellY[r * (cols - 1) + c] = (grid.yOfRow(r) + grid.yOfRow(r + 1)) / 2;
      }
    }
    if (hasTerrain && relief >= 10) _buildContours(niceInterval(relief / 12));
  }

  /// The first of a few round numbers at least [rawM]: 2, 5, 10, 20, 25,
  /// 50, 100, 200, 250, 500 metres.
  static double niceInterval(double rawM) {
    const steps = [2.0, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 250.0];
    for (final s in steps) {
      if (s >= rawM) return s;
    }
    return 500;
  }

  /// Marching squares: where each contour level crosses each cell.
  void _buildContours(double interval) {
    contourIntervalM = interval;
    final cols = grid.cols, rows = grid.rows;
    final cells = (cols - 1) * (rows - 1);
    final segs = <double>[];
    final major = <int>[];
    _contourStart = Int32List(cells + 1);
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final k = r * (cols - 1) + c;
        _contourStart[k] = major.length;
        // Corners round the cell: NW, NE, SE, SW.
        final xs = [
          grid.xOfCol(c),
          grid.xOfCol(c + 1),
          grid.xOfCol(c + 1),
          grid.xOfCol(c),
        ];
        final ys = [
          grid.yOfRow(r),
          grid.yOfRow(r),
          grid.yOfRow(r + 1),
          grid.yOfRow(r + 1),
        ];
        final hs = [
          grid.at(c, r),
          grid.at(c + 1, r),
          grid.at(c + 1, r + 1),
          grid.at(c, r + 1),
        ];
        final lo = hs.reduce(math.min), hi = hs.reduce(math.max);
        for (
          var level = (lo / interval).ceil() * interval;
          level <= hi;
          level += interval
        ) {
          final cross = <double>[];
          for (var e = 0; e < 4; e++) {
            final a = hs[e], b = hs[(e + 1) % 4];
            // A corner exactly on the level counts as above it, so a line
            // along a row of such corners is drawn once, not never.
            if ((a >= level) == (b >= level)) continue;
            final t = (level - a) / (b - a);
            cross
              ..add(xs[e] + (xs[(e + 1) % 4] - xs[e]) * t)
              ..add(ys[e] + (ys[(e + 1) % 4] - ys[e]) * t);
          }
          final z = _z(level);
          for (var j = 0; j + 3 < cross.length; j += 4) {
            segs.addAll([
              cross[j],
              cross[j + 1],
              z,
              cross[j + 2],
              cross[j + 3],
              z,
            ]);
            major.add((level / interval).round() % 5 == 0 ? 1 : 0);
          }
        }
      }
    }
    _contourStart[cells] = major.length;
    _contours = Float32List.fromList(segs);
    _contourMajor = Uint8List.fromList(major);
  }

  void _buildTrail(List<List<RunFix>> trail, double maxPoints) {
    var total = 0.0;
    for (final s in trail) {
      for (var i = 1; i < s.length; i++) {
        total += haversineM(s[i - 1].point, s[i].point);
      }
    }
    trailLengthM = total;
    // Even spacing, so a long hike costs no more per frame than a short one
    // and a GPS stutter does not bunch the line.
    final spacing = math.max(5.0, total / maxPoints);
    final extent = math.max(grid.widthM, grid.depthM);
    final lift = extent * 0.004;
    final out = <_TrailPoint>[];
    var along = 0.0;

    void place(RunFix f, double at, bool breakBefore) {
      final p = grid.toLocal(f.point);
      final z = hasTerrain
          ? groundZ(p.x, p.y) + lift
          : (f.altitudeM == null ? 0.0 : _z(f.altitudeM!)) + lift;
      out.add(_TrailPoint(p.x, p.y, math.max(z, 0), at, breakBefore));
    }

    for (final s in trail) {
      if (s.isEmpty) continue;
      place(s.first, along, out.isNotEmpty);
      var sinceLast = 0.0;
      for (var i = 1; i < s.length; i++) {
        final d = haversineM(s[i - 1].point, s[i].point);
        along += d;
        sinceLast += d;
        if (sinceLast >= spacing || i == s.length - 1) {
          place(s[i], along, false);
          sinceLast = 0;
        }
      }
    }
    _trail = out;
  }

  /// A camera that fits the whole block on screen.
  OrbitCamera fit({
    double azimuth = 0.6,
    double elevation = 0.62,
    double zoom = 1,
  }) {
    final hw = grid.widthM / 2, hd = grid.depthM / 2;
    final hz = (topZ - baseZ) / 2;
    final radius = math.sqrt(hw * hw + hd * hd + hz * hz);
    const fov = 0.75;
    return OrbitCamera(
      azimuth: azimuth,
      elevation: elevation,
      distance: radius / math.sin(fov / 2) / zoom,
      targetZ: (topZ + baseZ) / 2,
      fov: fov,
    );
  }

  /// Whether the land hides the world point from the eye.
  bool _hidden(_TrailPoint p, Projector pr) {
    if (!hasTerrain) return false;
    final dx = pr.ex - p.x, dy = pr.ey - p.y, dz = pr.ez - p.z;
    // Past topZ nothing can be in the way.
    final tMax = dz <= 0 ? 1.0 : math.min(1.0, (topZ - p.z) / dz);
    if (tMax <= 0) return false;
    final horiz = math.sqrt(dx * dx + dy * dy) * tMax;
    final cell = math.min(
      grid.widthM / (grid.cols - 1),
      grid.depthM / (grid.rows - 1),
    );
    final steps = math.min(48, math.max(2, (horiz / cell).ceil()));
    final hw = grid.widthM / 2, hd = grid.depthM / 2;
    for (var k = 1; k <= steps; k++) {
      final t = tMax * k / steps;
      final qx = p.x + dx * t, qy = p.y + dy * t;
      if (qx.abs() > hw || qy.abs() > hd) return false;
      final qz = p.z + dz * t;
      if (groundZ(qx, qy) > qz + 0.5) return true;
    }
    return false;
  }

  /// The model seen through [projector], the trail drawn in up to [reveal]
  /// of its length.
  TerrainFrame frame(Projector projector, {double reveal = 1}) {
    final cols = grid.cols, rows = grid.rows;
    final n = cols * rows;
    final sx = Float32List(n), sy = Float32List(n), depth = Float32List(n);
    var dMin = double.infinity, dMax = 0.0;
    for (var i = 0; i < n; i++) {
      final x = _world[i * 3], y = _world[i * 3 + 1], z = _world[i * 3 + 2];
      final d = projector.depthOf(x, y, z);
      depth[i] = d;
      if (d > Projector.near) {
        sx[i] = projector.screenX(x, y, d);
        sy[i] = projector.screenY(x, y, z, d);
        dMin = math.min(dMin, d);
        dMax = math.max(dMax, d);
      }
    }
    int fogged(int colour, double d) {
      if (dMax <= dMin) return colour;
      final t = ((d - dMin) / (dMax - dMin)).clamp(0.0, 1.0);
      return _mix(colour, style.fog, t * t * 0.55);
    }

    // Back to front by ground distance from the eye: for land seen from
    // above, that is the order the painter needs.
    final cells = (cols - 1) * (rows - 1);
    final keys = Float64List(cells);
    for (var k = 0; k < cells; k++) {
      final ddx = _cellX[k] - projector.ex, ddy = _cellY[k] - projector.ey;
      keys[k] = ddx * ddx + ddy * ddy;
    }
    final order = List<int>.generate(cells, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));

    final wallQuads = 2 * (cols - 1) + 2 * (rows - 1);
    final curtainQuads = hasTerrain ? 0 : _trail.length;
    final capacity =
        (cells + wallQuads + curtainQuads + _contourMajor.length) * 6;
    if (_colours.length < capacity) {
      _positions = Float32List(capacity * 2);
      _colours = Int32List(capacity);
    }
    final pos = _positions, col = _colours;
    var v = 0;
    void put(double x, double y, int c) {
      pos[v * 2] = x;
      pos[v * 2 + 1] = y;
      col[v] = c;
      v++;
    }

    for (final k in order) {
      final r = k ~/ (cols - 1), c = k % (cols - 1);
      final a = r * cols + c, b = a + 1, d = a + cols, e = d + 1;
      if (depth[a] <= Projector.near ||
          depth[b] <= Projector.near ||
          depth[d] <= Projector.near ||
          depth[e] <= Projector.near) {
        continue;
      }
      final ca = fogged(_lit[a], depth[a]), cb = fogged(_lit[b], depth[b]);
      final cd = fogged(_lit[d], depth[d]), ce = fogged(_lit[e], depth[e]);
      put(sx[a], sy[a], ca);
      put(sx[b], sy[b], cb);
      put(sx[d], sy[d], cd);
      put(sx[b], sy[b], cb);
      put(sx[e], sy[e], ce);
      put(sx[d], sy[d], cd);

      // The cell's contour lines, straight after it: drawn in the same
      // order as the land, a hill hides the lines behind it.
      if (_contourStart.isEmpty) continue;
      for (var j = _contourStart[k]; j < _contourStart[k + 1]; j++) {
        final o = j * 6;
        final x1 = _contours[o], y1 = _contours[o + 1], z1 = _contours[o + 2];
        final x2 = _contours[o + 3], y2 = _contours[o + 4];
        final d1 = projector.depthOf(x1, y1, z1);
        final d2 = projector.depthOf(x2, y2, z1);
        if (d1 <= Projector.near || d2 <= Projector.near) continue;
        final p1x = projector.screenX(x1, y1, d1);
        final p1y = projector.screenY(x1, y1, z1, d1);
        final p2x = projector.screenX(x2, y2, d2);
        final p2y = projector.screenY(x2, y2, z1, d2);
        final ddx = p2x - p1x, ddy = p2y - p1y;
        final len = math.sqrt(ddx * ddx + ddy * ddy);
        if (len < 0.01) continue;
        final isMajor = _contourMajor[j] == 1;
        final half = isMajor ? 0.75 : 0.5;
        final nx = -ddy / len * half, ny = ddx / len * half;
        final colour = isMajor ? style.contourMajor : style.contour;
        final cl = _fogKeepingAlpha(colour, d1, dMin, dMax);
        put(p1x + nx, p1y + ny, cl);
        put(p2x + nx, p2y + ny, cl);
        put(p1x - nx, p1y - ny, cl);
        put(p2x + nx, p2y + ny, cl);
        put(p2x - nx, p2y - ny, cl);
        put(p1x - nx, p1y - ny, cl);
      }
    }

    // The sides facing the eye, over everything behind them.
    void wall(List<int> edge, double nx, double ny) {
      final mid = edge[edge.length ~/ 2];
      final toEye =
          (projector.ex - _world[mid * 3]) * nx +
          (projector.ey - _world[mid * 3 + 1]) * ny;
      if (toEye <= 0) return;
      final light = 0.55 + 0.45 * math.max(0.0, -0.5 * nx + 0.5 * ny);
      final topC = _scale(style.wall, light);
      final botC = _scale(style.wall, light * 0.55);
      for (var i = 0; i + 1 < edge.length; i++) {
        final p = edge[i], q = edge[i + 1];
        final px = _world[p * 3], py = _world[p * 3 + 1];
        final qx = _world[q * 3], qy = _world[q * 3 + 1];
        final dp = projector.depthOf(px, py, baseZ);
        final dq = projector.depthOf(qx, qy, baseZ);
        if (depth[p] <= Projector.near ||
            depth[q] <= Projector.near ||
            dp <= Projector.near ||
            dq <= Projector.near) {
          continue;
        }
        final bpx = projector.screenX(px, py, dp);
        final bpy = projector.screenY(px, py, baseZ, dp);
        final bqx = projector.screenX(qx, qy, dq);
        final bqy = projector.screenY(qx, qy, baseZ, dq);
        final tp = fogged(topC, depth[p]), tq = fogged(topC, depth[q]);
        final bp = fogged(botC, dp), bq = fogged(botC, dq);
        put(sx[p], sy[p], tp);
        put(sx[q], sy[q], tq);
        put(bpx, bpy, bp);
        put(sx[q], sy[q], tq);
        put(bqx, bqy, bq);
        put(bpx, bpy, bp);
      }
    }

    wall([for (var c = 0; c < cols; c++) c], 0, 1); // north
    wall([for (var c = 0; c < cols; c++) (rows - 1) * cols + c], 0, -1);
    wall([for (var r = 0; r < rows; r++) r * cols], -1, 0); // west
    wall([for (var r = 0; r < rows; r++) r * cols + cols - 1], 1, 0);

    // The trail, cut where the drawing-in has reached.
    final upTo = reveal.clamp(0.0, 1.0) * trailLengthM;
    final pts = <_TrailPoint>[];
    for (var i = 0; upTo > 0 && i < _trail.length; i++) {
      final p = _trail[i];
      if (p.along <= upTo) {
        pts.add(p);
        continue;
      }
      if (i > 0 && !p.breakBefore) {
        final a = _trail[i - 1];
        final span = p.along - a.along;
        final t = span <= 0 ? 0.0 : (upTo - a.along) / span;
        pts.add(
          _TrailPoint(
            a.x + (p.x - a.x) * t,
            a.y + (p.y - a.y) * t,
            a.z + (p.z - a.z) * t,
            upTo,
            false,
          ),
        );
      }
      break;
    }

    if (!hasTerrain) {
      // The sheet under the line: the climb, honestly, without the ground.
      final topC = style.curtain;
      final botC = _withAlpha(style.curtain, 0.08);
      final floor = 0.0;
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        if (b.breakBefore) continue;
        final da = projector.depthOf(a.x, a.y, a.z);
        final db = projector.depthOf(b.x, b.y, b.z);
        final fa = projector.depthOf(a.x, a.y, floor);
        final fb = projector.depthOf(b.x, b.y, floor);
        if ([da, db, fa, fb].any((d) => d <= Projector.near)) continue;
        final ax = projector.screenX(a.x, a.y, da);
        final ay = projector.screenY(a.x, a.y, a.z, da);
        final bx = projector.screenX(b.x, b.y, db);
        final by = projector.screenY(b.x, b.y, b.z, db);
        final afx = projector.screenX(a.x, a.y, fa);
        final afy = projector.screenY(a.x, a.y, floor, fa);
        final bfx = projector.screenX(b.x, b.y, fb);
        final bfy = projector.screenY(b.x, b.y, floor, fb);
        put(ax, ay, topC);
        put(bx, by, topC);
        put(afx, afy, botC);
        put(bx, by, topC);
        put(bfx, bfy, botC);
        put(afx, afy, botC);
      }
    }

    final runs = <TrailRun>[];
    var current = <double>[];
    bool? currentVisible;
    ({double x, double y})? start, head;
    double? lastX, lastY;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final d = projector.depthOf(p.x, p.y, p.z);
      if (d <= Projector.near) {
        if (current.length >= 4) {
          runs.add(TrailRun(currentVisible!, Float32List.fromList(current)));
        }
        current = [];
        currentVisible = null;
        continue;
      }
      final x = projector.screenX(p.x, p.y, d);
      final y = projector.screenY(p.x, p.y, p.z, d);
      final visible = !_hidden(p, projector);
      if (i == 0) start = (x: x, y: y);
      head = (x: x, y: y);
      if (p.breakBefore || currentVisible != visible) {
        if (current.length >= 4) {
          runs.add(TrailRun(currentVisible!, Float32List.fromList(current)));
        }
        // A change of visibility shares its boundary point, so the line has
        // no gap; a pause starts clean.
        current = [
          if (!p.breakBefore && lastX != null) ...[lastX, lastY!],
        ];
        currentVisible = visible;
      }
      current
        ..add(x)
        ..add(y);
      lastX = x;
      lastY = y;
    }
    if (current.length >= 4 && currentVisible != null) {
      runs.add(TrailRun(currentVisible, Float32List.fromList(current)));
    }

    return TerrainFrame(
      positions: pos,
      colours: col,
      vertexCount: v,
      trail: runs,
      start: start,
      head: head,
    );
  }

  /// The highest ground the trail crosses, metres: from the terrain when
  /// there is terrain, null otherwise.
  double? get highestOnTrailM {
    if (!hasTerrain || _trail.isEmpty) return null;
    var best = double.negativeInfinity;
    for (final p in _trail) {
      best = math.max(best, grid.heightAtLocal(p.x, p.y));
    }
    return best;
  }
}

int _channel(int c, int shift) => (c >> shift) & 0xff;

int _argb(int a, int r, int g, int b) =>
    (a.clamp(0, 255) << 24) |
    (r.clamp(0, 255) << 16) |
    (g.clamp(0, 255) << 8) |
    b.clamp(0, 255);

/// [a] to [b] by [t], every channel.
int _mix(int a, int b, double t) {
  int ch(int s) =>
      (_channel(a, s) + (_channel(b, s) - _channel(a, s)) * t).round();
  return _argb(ch(24), ch(16), ch(8), ch(0));
}

/// [c] darker or lighter by [k]; alpha kept.
int _scale(int c, double k) => _argb(
  _channel(c, 24),
  (_channel(c, 16) * k).round(),
  (_channel(c, 8) * k).round(),
  (_channel(c, 0) * k).round(),
);

/// [c]'s colour faded into the fog by depth, its own alpha kept.
int _fogKeepingAlpha(int c, double depth, double dMin, double dMax) {
  if (dMax <= dMin) return c;
  final t = ((depth - dMin) / (dMax - dMin)).clamp(0.0, 1.0);
  return (c & 0xff000000) |
      (_mix(c | 0xff000000, 0xff000000, t * t * 0.7) & 0x00ffffff);
}

int _withAlpha(int c, double alpha) =>
    (c & 0x00ffffff) | ((alpha * 255).round().clamp(0, 255) << 24);
