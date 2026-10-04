import 'dart:math' as math;
import 'dart:typed_data';

import '../run/geo.dart';
import 'tiles.dart';

/// Something that knows the ground height at a point, or does not.
abstract interface class HeightSource {
  /// Metres above sea level; null where it has no data.
  double? heightAt(GeoPoint p);
}

/// Heights from decoded elevation tiles at one zoom: bilinear between pixel
/// centres, across tile edges.
class TileHeights implements HeightSource {
  TileHeights(this.z, this.tiles, {this.size = 256});

  final int z;
  final Map<TileId, Float32List> tiles;

  /// Pixels along a tile's side.
  final int size;

  double? _pixel(int ix, int iy) {
    if (ix < 0 || iy < 0) return null;
    final tx = ix ~/ size;
    final ty = iy ~/ size;
    final t = tiles[TileId(z, tx, ty)];
    if (t == null) return null;
    return t[(iy - ty * size) * size + (ix - tx * size)];
  }

  @override
  double? heightAt(GeoPoint p) {
    // Pixel i covers [i, i + 1): its centre is at i + 0.5.
    final fx = tileX(p.lng, z) * size - 0.5;
    final fy = tileY(p.lat, z) * size - 0.5;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final dx = fx - x0;
    final dy = fy - y0;
    final h00 = _pixel(x0, y0);
    final h10 = _pixel(x0 + 1, y0);
    final h01 = _pixel(x0, y0 + 1);
    final h11 = _pixel(x0 + 1, y0 + 1);
    if (h00 == null || h10 == null || h01 == null || h11 == null) {
      return _pixel(fx.round(), fy.round());
    }
    final top = h00 + (h10 - h00) * dx;
    final bottom = h01 + (h11 - h01) * dx;
    return top + (bottom - top) * dy;
  }
}

/// Ground heights on a regular grid over [bounds], in local metres from its
/// centre: x east, y north. Row 0 is the northern edge, column 0 the west.
class HeightGrid {
  HeightGrid(this.bounds, this.cols, this.rows, this.heights)
    : assert(cols >= 2 && rows >= 2),
      assert(heights.length == cols * rows) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final h in heights) {
      lo = math.min(lo, h);
      hi = math.max(hi, h);
    }
    minH = lo;
    maxH = hi;
  }

  /// Level ground at [h]: the floor drawn when there is no terrain.
  factory HeightGrid.flat(GeoBounds bounds, double h) =>
      HeightGrid(bounds, 2, 2, Float32List.fromList([h, h, h, h]));

  /// [source] sampled [cols] × [rows] times over [bounds]; null if it has a
  /// hole anywhere, so a half-downloaded mountain is never drawn as a cliff.
  static HeightGrid? sample(
    HeightSource source,
    GeoBounds bounds, {
    int cols = 90,
    int rows = 90,
  }) {
    final out = Float32List(cols * rows);
    for (var r = 0; r < rows; r++) {
      final lat = bounds.north - (bounds.north - bounds.south) * r / (rows - 1);
      for (var c = 0; c < cols; c++) {
        final lng = bounds.west + (bounds.east - bounds.west) * c / (cols - 1);
        final h = source.heightAt(GeoPoint(lat, lng));
        if (h == null || h.isNaN) return null;
        out[r * cols + c] = h;
      }
    }
    return HeightGrid(bounds, cols, rows, out);
  }

  final GeoBounds bounds;
  final int cols;
  final int rows;
  final Float32List heights;

  late final double minH;
  late final double maxH;

  double get widthM => bounds.widthM;
  double get depthM => bounds.heightM;

  /// Local metres of [p] from the grid's centre.
  ({double x, double y}) toLocal(GeoPoint p) {
    final c = bounds.centre;
    const k = math.pi / 180 * earthRadiusM;
    return (
      x: (p.lng - c.lng) * k * math.cos(c.lat * math.pi / 180),
      y: (p.lat - c.lat) * k,
    );
  }

  double xOfCol(int c) => -widthM / 2 + widthM * c / (cols - 1);
  double yOfRow(int r) => depthM / 2 - depthM * r / (rows - 1);
  double at(int c, int r) => heights[r * cols + c];

  /// Ground height under local ([x], [y]), bilinear, held at the edges.
  double heightAtLocal(double x, double y) {
    final fc = ((x + widthM / 2) / widthM * (cols - 1)).clamp(0.0, cols - 1.0);
    final fr = ((depthM / 2 - y) / depthM * (rows - 1)).clamp(0.0, rows - 1.0);
    final c0 = math.min(fc.floor(), cols - 2);
    final r0 = math.min(fr.floor(), rows - 2);
    final dc = fc - c0;
    final dr = fr - r0;
    final top = at(c0, r0) + (at(c0 + 1, r0) - at(c0, r0)) * dc;
    final bottom = at(c0, r0 + 1) + (at(c0 + 1, r0 + 1) - at(c0, r0 + 1)) * dc;
    return top + (bottom - top) * dr;
  }
}
