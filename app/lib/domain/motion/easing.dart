import 'dart:math' as math;

/// How a clip moves from one keyframe to the next.
///
/// Bodies do not move linearly: a rep slows into the bottom and out of the
/// top. inOut is the default for that reason; linear is for things that
/// really are steady, like a skipping rope turning.
enum Ease {
  linear,
  inOut,
  easeIn,
  easeOut;

  /// Maps progress [u] in 0..1 to eased progress in 0..1.
  double apply(double u) {
    final v = u.clamp(0.0, 1.0);
    return switch (this) {
      Ease.linear => v,
      Ease.inOut => 0.5 - 0.5 * math.cos(math.pi * v),
      Ease.easeIn => 1 - math.cos(math.pi * v / 2),
      Ease.easeOut => math.sin(math.pi * v / 2),
    };
  }

  /// The names motions.json uses.
  static Ease parse(String name) => switch (name) {
    'linear' => Ease.linear,
    'inOut' => Ease.inOut,
    'in' => Ease.easeIn,
    'out' => Ease.easeOut,
    _ => throw FormatException('Unknown ease "$name"'),
  };
}
