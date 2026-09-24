import 'dart:math' as math;

/// A position on the earth, in degrees. Pure Dart: the map's own LatLng
/// lives in a package the domain does not import.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() =>
      'GeoPoint(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}

/// Mean earth radius, metres (IUGG).
const earthRadiusM = 6371008.8;

/// Great-circle distance between two points, in metres.
///
/// Haversine rather than the flat-earth shortcut: it costs nothing and holds
/// at any latitude, including Münster's.
double haversineM(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

/// One reading from the location sensor.
class RunFix {
  const RunFix({
    required this.tMs,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.altitudeM,
    this.speedMps,
  });

  /// Epoch milliseconds.
  final int tMs;
  final double lat;
  final double lng;

  /// Horizontal accuracy radius; null when the sensor did not say.
  final double? accuracyM;
  final double? altitudeM;

  /// The sensor's own speed estimate, when it gives one.
  final double? speedMps;

  GeoPoint get point => GeoPoint(lat, lng);
}
