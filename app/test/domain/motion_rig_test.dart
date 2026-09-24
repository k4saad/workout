import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/motion/motion.dart';

/// The arithmetic under the exercise demos: vectors, two-bone IK, easing.
///
/// Written before the rig. A demo whose shin changes length mid-squat, or
/// whose planted foot skates, teaches the wrong movement as surely as a
/// wrong video would.
void main() {
  group('V2', () {
    test('polar angles are measured anticlockwise from +x, y up', () {
      final up = V2.polar(deg(90));
      expect(up.x, closeTo(0, 1e-12));
      expect(up.y, closeTo(1, 1e-12));
      final left = V2.polar(deg(180), 2);
      expect(left.x, closeTo(-2, 1e-12));
      expect(left.y, closeTo(0, 1e-12));
    });

    test('the clockwise perpendicular of "up" is "right"', () {
      expect(const V2(0, 1).perpCw, const V2(1, 0));
      expect(const V2(0, 1).perpCcw, const V2(-1, 0));
    });

    test('lerp, length and distance', () {
      expect(
        V2.lerp(const V2(0, 0), const V2(10, -4), 0.25),
        const V2(2.5, -1),
      );
      expect(const V2(3, 4).length, 5);
      expect(const V2(1, 1).distanceTo(const V2(4, 5)), 5);
    });

    test('the unit of a zero vector is zero, not NaN', () {
      final u = V2.zero.unit;
      expect(u.isFinite, isTrue);
      expect(u, V2.zero);
    });
  });

  group('two-bone IK', () {
    const upper = 30.0;
    const lower = 28.0;
    const root = V2(1, 2);
    final rng = math.Random(7);

    V2 randomTarget() =>
        V2(rng.nextDouble() * 160 - 80, rng.nextDouble() * 160 - 80);

    test('bone lengths hold for any target, either bend', () {
      for (var i = 0; i < 500; i++) {
        for (final bend in const [1, -1]) {
          final s = solveTwoBone(
            root: root,
            target: randomTarget(),
            upper: upper,
            lower: lower,
            bend: bend,
          );
          expect((s.mid - root).length, closeTo(upper, 1e-9));
          expect((s.end - s.mid).length, closeTo(lower, 1e-9));
        }
      }
    });

    test('a target in reach is reached exactly', () {
      var checked = 0;
      while (checked < 300) {
        final target = randomTarget();
        final d = (target - root).length;
        if (d < (upper - lower).abs() + 0.1 || d > upper + lower - 0.1) {
          continue;
        }
        final s = solveTwoBone(
          root: root,
          target: target,
          upper: upper,
          lower: lower,
          bend: 1,
        );
        expect(s.reached, isTrue);
        expect(s.end.distanceTo(target), lessThan(1e-9));
        checked++;
      }
    });

    test('an out-of-reach target straightens the limb towards it', () {
      const target = V2(1, -98);
      final s = solveTwoBone(
        root: root,
        target: target,
        upper: upper,
        lower: lower,
        bend: 1,
      );
      expect(s.reached, isFalse);
      expect(s.end.x, closeTo(1, 1e-9));
      expect(s.end.y, closeTo(2 - upper - lower, 1e-9));
      expect(s.mid.x, closeTo(1, 1e-9));
      expect(s.miss, closeTo(100 - upper - lower, 1e-9));
    });

    test('a target inside the minimum reach folds as far as it goes', () {
      // |upper - lower| is 2: a target 0.5 away cannot be touched.
      final s = solveTwoBone(
        root: root,
        target: root + const V2(0.5, 0),
        upper: upper,
        lower: lower,
        bend: 1,
      );
      expect(s.reached, isFalse);
      expect(s.end.distanceTo(root), closeTo(upper - lower, 1e-9));
      expect(s.end.y, closeTo(root.y, 1e-9));
    });

    test('a target sitting on the root does not produce NaN', () {
      final s = solveTwoBone(
        root: root,
        target: root,
        upper: upper,
        lower: lower,
        bend: -1,
      );
      expect(s.mid.isFinite, isTrue);
      expect(s.end.isFinite, isTrue);
      expect((s.mid - root).length, closeTo(upper, 1e-9));
      expect((s.end - s.mid).length, closeTo(lower, 1e-9));
    });

    test('bend picks the side the middle joint goes to', () {
      // A leg pointing straight down from the hip. Facing +x, the knee goes
      // forward with bend +1 and backward with bend -1.
      for (final (bend, forward) in const [(1, true), (-1, false)]) {
        final s = solveTwoBone(
          root: V2.zero,
          target: const V2(0, -50),
          upper: upper,
          lower: lower,
          bend: bend,
        );
        expect(s.mid.x > 0, forward, reason: 'bend $bend');
      }
    });

    test('the middle joint lands where the law of cosines puts it', () {
      // 25-25 limb, target 40 straight down: a 3-4-5 triangle.
      final s = solveTwoBone(
        root: V2.zero,
        target: const V2(0, -40),
        upper: 25,
        lower: 25,
        bend: 1,
      );
      expect(s.mid.x, closeTo(15, 1e-9));
      expect(s.mid.y, closeTo(-20, 1e-9));
      expect(s.end.x, closeTo(0, 1e-9));
      expect(s.end.y, closeTo(-40, 1e-9));
    });
  });

  group('easing', () {
    test('every curve starts at 0, ends at 1 and never runs backwards', () {
      for (final e in Ease.values) {
        expect(e.apply(0), closeTo(0, 1e-12), reason: e.name);
        expect(e.apply(1), closeTo(1, 1e-12), reason: e.name);
        var last = -1.0;
        for (var i = 0; i <= 100; i++) {
          final v = e.apply(i / 100);
          expect(v, greaterThanOrEqualTo(last - 1e-12), reason: e.name);
          last = v;
        }
      }
    });

    test('inOut is symmetric and slow at both ends', () {
      expect(Ease.inOut.apply(0.5), closeTo(0.5, 1e-12));
      for (final u in const [0.1, 0.2, 0.3, 0.4]) {
        expect(
          Ease.inOut.apply(u) + Ease.inOut.apply(1 - u),
          closeTo(1, 1e-12),
        );
      }
      expect(Ease.inOut.apply(0.1), lessThan(0.1));
    });

    test('easeIn starts slow, easeOut finishes slow, linear is neither', () {
      expect(Ease.easeIn.apply(0.25), lessThan(0.25));
      expect(Ease.easeOut.apply(0.25), greaterThan(0.25));
      expect(Ease.linear.apply(0.25), 0.25);
    });

    test('out-of-range input is clamped', () {
      expect(Ease.inOut.apply(-0.5), 0);
      expect(Ease.inOut.apply(1.5), 1);
    });

    test('parses from the names motions.json uses', () {
      expect(Ease.parse('inOut'), Ease.inOut);
      expect(Ease.parse('in'), Ease.easeIn);
      expect(Ease.parse('out'), Ease.easeOut);
      expect(Ease.parse('linear'), Ease.linear);
      expect(() => Ease.parse('bounce'), throwsFormatException);
    });
  });
}
