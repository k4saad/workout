import 'dart:math' as math;

/// Degrees to radians. motions.json is authored in degrees because a person
/// can read "trunk 45" and picture it.
double deg(double degrees) => degrees * math.pi / 180;

/// A 2-D point or direction in the demo's world: centimetres, y up, the floor
/// at y = 0.
///
/// Pure Dart on purpose: `Offset` lives in dart:ui, and the rig is tested
/// without Flutter.
class V2 {
  const V2(this.x, this.y);

  final double x;
  final double y;

  static const zero = V2(0, 0);

  /// The point [r] away from the origin at [radians], anticlockwise from +x.
  factory V2.polar(double radians, [double r = 1]) =>
      V2(math.cos(radians) * r, math.sin(radians) * r);

  /// `[x, y]` as motions.json writes it.
  factory V2.fromJson(Object? json) {
    if (json is List && json.length == 2 && json[0] is num && json[1] is num) {
      return V2((json[0] as num).toDouble(), (json[1] as num).toDouble());
    }
    throw FormatException('Expected [x, y], got $json');
  }

  static V2 lerp(V2 a, V2 b, double t) =>
      V2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  V2 operator +(V2 o) => V2(x + o.x, y + o.y);
  V2 operator -(V2 o) => V2(x - o.x, y - o.y);
  V2 operator *(double k) => V2(x * k, y * k);
  V2 operator -() => V2(-x, -y);

  double get length => math.sqrt(x * x + y * y);

  /// Unit vector in this direction; zero stays zero rather than becoming NaN.
  V2 get unit {
    final l = length;
    return l == 0 ? zero : V2(x / l, y / l);
  }

  /// This vector turned a quarter clockwise. For a figure facing +x, the
  /// clockwise perpendicular of the spine points out of the chest.
  V2 get perpCw => V2(y, -x);

  /// This vector turned a quarter anticlockwise.
  V2 get perpCcw => V2(-y, x);

  /// Angle from +x in radians, anticlockwise.
  double get angle => math.atan2(y, x);

  double dot(V2 o) => x * o.x + y * o.y;

  /// The z of the 3-D cross product: positive when [o] is anticlockwise of
  /// this.
  double cross(V2 o) => x * o.y - y * o.x;

  double distanceTo(V2 o) => (this - o).length;

  bool get isFinite => x.isFinite && y.isFinite;

  @override
  bool operator ==(Object other) => other is V2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'V2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
