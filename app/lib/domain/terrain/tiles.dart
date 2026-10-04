import 'dart:math' as math;
import 'dart:typed_data';

import '../run/geo.dart';

/// One elevation tile: Web Mercator XYZ, the scheme every slippy map uses.
class TileId {
  const TileId(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileId && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}

/// A box on the earth: the area a hike covers, usually with a margin.
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// The smallest box holding every point. Throws on none.
  factory GeoBounds.around(Iterable<GeoPoint> points) {
    final it = points.iterator;
    if (!it.moveNext()) throw ArgumentError('no points');
    var s = it.current.lat, n = s, w = it.current.lng, e = w;
    while (it.moveNext()) {
      final p = it.current;
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    return GeoBounds(south: s, west: w, north: n, east: e);
  }

  final double south;
  final double west;
  final double north;
  final double east;

  GeoPoint get centre => GeoPoint((south + north) / 2, (west + east) / 2);

  double get _cosLat => math.cos(centre.lat * math.pi / 180);

  /// East-west extent, metres, at the centre's latitude.
  double get widthM => (east - west) * math.pi / 180 * earthRadiusM * _cosLat;

  /// North-south extent, metres.
  double get heightM => (north - south) * math.pi / 180 * earthRadiusM;

  /// Square, grown by [fraction] of the longer side on every side, and at
  /// least [minSideM] across: a trail drawn edge to edge reads as a line on
  /// a table, not a walk through country.
  GeoBounds squaredAndPadded(double fraction, {double minSideM = 0}) {
    final side = math.max(
      math.max(widthM, heightM) * (1 + 2 * fraction),
      minSideM,
    );
    final halfLat = side / 2 / earthRadiusM * 180 / math.pi;
    final halfLng = halfLat / _cosLat;
    final c = centre;
    return GeoBounds(
      south: c.lat - halfLat,
      west: c.lng - halfLng,
      north: c.lat + halfLat,
      east: c.lng + halfLng,
    );
  }

  @override
  String toString() => 'GeoBounds($south, $west, $north, $east)';
}

/// Fractional tile column of [lng] at zoom [z].
double tileX(double lng, int z) => (lng + 180) / 360 * (1 << z);

/// Fractional tile row of [lat] at zoom [z]: Web Mercator, north at row 0.
double tileY(double lat, int z) {
  final r = lat * math.pi / 180;
  return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * (1 << z);
}

/// The longitude at fractional tile column [x].
double lngOfTileX(double x, int z) => x / (1 << z) * 360 - 180;

/// The latitude at fractional tile row [y].
double latOfTileY(double y, int z) {
  final n = math.pi - 2 * math.pi * y / (1 << z);
  return 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
}

/// Every tile that [b] touches at zoom [z], north row first.
List<TileId> tilesCovering(GeoBounds b, int z) {
  final max = (1 << z) - 1;
  final x0 = tileX(b.west, z).floor().clamp(0, max);
  final x1 = tileX(b.east, z).floor().clamp(0, max);
  final y0 = tileY(b.north, z).floor().clamp(0, max);
  final y1 = tileY(b.south, z).floor().clamp(0, max);
  return [
    for (var y = y0; y <= y1; y++)
      for (var x = x0; x <= x1; x++) TileId(z, x, y),
  ];
}

/// The most detailed zoom at which [b] needs at most [maxTiles] tiles: the
/// sharpest terrain for the fewest downloads.
int zoomFor(
  GeoBounds b, {
  int maxTiles = 9,
  int minZoom = 6,
  int maxZoom = 14,
}) {
  for (var z = maxZoom; z > minZoom; z--) {
    if (tilesCovering(b, z).length <= maxTiles) return z;
  }
  return minZoom;
}

/// Terrarium encoding: metres = (R × 256 + G + B / 256) − 32768.
double terrariumMetres(int r, int g, int b) => r * 256 + g + b / 256 - 32768;

/// A tile's heights, row-major from the north-west corner, decoded from its
/// RGBA pixels.
Float32List decodeTerrarium(Uint8List rgba) {
  final n = rgba.length ~/ 4;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = terrariumMetres(rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2]);
  }
  return out;
}
