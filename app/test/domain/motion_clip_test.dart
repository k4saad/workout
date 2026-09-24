import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/motion/motion.dart';

/// One motion clip: parsed, blended between keyframes, and resolved into a
/// posed body.
///
/// Built on a tiny hand-written clip, so each number here can be checked on
/// paper. The shipped clips are tested against the same rules in
/// motion_library_test.dart.
void main() {
  final sk = Skeleton.fromJson(skeletonJson);

  group('parsing', () {
    test('a clip reads its header and keyframes', () {
      final c = MotionClip.fromJson(squatJson());
      expect(c.id, 'test-squat');
      expect(c.view, MotionView.side);
      expect(c.periodMs, 2000);
      expect(c.keyframes, hasLength(2));
      expect(c.provenance, 'original work');
      expect(c.still, 0.5);
    });

    test('the first keyframe must be at t = 0', () {
      final j = squatJson();
      (j['keyframes'] as List)[0]['t'] = 0.1;
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });

    test('keyframe times must rise, and stay below 1', () {
      final j = squatJson();
      (j['keyframes'] as List)[1]['t'] = 0.0;
      expect(() => MotionClip.fromJson(j), throwsFormatException);

      final k = squatJson();
      (k['keyframes'] as List)[1]['t'] = 1.0;
      expect(() => MotionClip.fromJson(k), throwsFormatException);
    });

    test('a limb cannot switch between IK and angles mid-clip', () {
      // Blending a world target into a joint angle has no meaning; the
      // generator must pick one per limb.
      final j = squatJson();
      (j['keyframes'] as List)[1]['armL'] = {
        'at': [10, 90],
      };
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });

    test('every keyframe names all four limbs', () {
      final j = squatJson();
      ((j['keyframes'] as List)[0] as Map).remove('legR');
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });

    test('an unknown view is refused', () {
      final j = squatJson()..['view'] = 'top';
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });

    test('every limb needs a bend direction', () {
      final j = squatJson();
      (j['bend'] as Map).remove('legL');
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });
  });

  group('blending between keyframes', () {
    final c = MotionClip.fromJson(squatJson());

    test('on a keyframe, the keyframe comes back unchanged', () {
      final a = c.specAt(0);
      expect(a.pelvis, const V2(0, 86));
      expect(a.trunk, 90);
      final b = c.specAt(0.5);
      expect(b.pelvis, const V2(-10, 55));
      expect(b.trunk, 60);
    });

    test('between keyframes the blend follows the ease', () {
      // 0.125 is a quarter of the way through the first segment; inOut
      // turns 0.25 into 0.5 - 0.5 cos(pi / 4).
      final u = 0.5 - 0.5 * math.cos(math.pi / 4);
      final s = c.specAt(0.125);
      expect(s.pelvis.x, closeTo(0 + (-10 - 0) * u, 1e-9));
      expect(s.pelvis.y, closeTo(86 + (55 - 86) * u, 1e-9));
      expect(s.trunk, closeTo(90 + (60 - 90) * u, 1e-9));
    });

    test('the last keyframe blends back into the first', () {
      final s = c.specAt(0.75);
      expect(s.pelvis.y, closeTo((55 + 86) / 2, 1e-9));
    });

    test('time wraps: a clip is a loop', () {
      expect(c.specAt(1.25).pelvis, c.specAt(0.25).pelvis);
      expect(c.specAt(-0.25).pelvis, c.specAt(0.75).pelvis);
    });

    test(
      'joint angles blend as numbers, so the author picks the way round',
      () {
        final s = c.specAt(0.25);
        final arm = s.limbs[Limb.armL]! as AngleTarget;
        expect(arm.upper, closeTo(-75, 1e-9));
        expect(arm.lower, closeTo(-45, 1e-9));
      },
    );

    test('a travelling clip walks on into the next loop', () {
      final walk = MotionClip.fromJson(squatJson()..['travel'] = 100);
      // Wrapping from the last keyframe, the first one is 100 further on.
      final s = walk.specAt(0.75);
      expect(s.pelvis.x, closeTo((-10 + 100) / 2, 1e-9));
      expect(walk.sample(sk, 0.3).drift, closeTo(30, 1e-9));
    });

    test('the loop seam is invisible once the camera follows', () {
      final walk = MotionClip.fromJson(squatJson()..['travel'] = 100);
      final end = walk.sample(sk, 0.999999);
      final start = walk.sample(sk, 0);
      expect(
        (end.pelvis.x - end.drift) - (start.pelvis.x - start.drift),
        closeTo(0, 1e-3),
      );
      expect(end.pelvis.y, closeTo(start.pelvis.y, 1e-3));
    });
  });

  group('the posed body', () {
    final c = MotionClip.fromJson(squatJson());

    test('no bone ever changes length', () {
      for (var i = 0; i < 100; i++) {
        final p = c.sample(sk, i / 100);
        for (final l in Limb.values) {
          final limb = p[l];
          expect(
            limb.mid.distanceTo(limb.root),
            closeTo(sk.upper(l), 1e-9),
            reason: '$l upper at t=${i / 100}',
          );
          expect(
            limb.end.distanceTo(limb.mid),
            closeTo(sk.lower(l), 1e-9),
            reason: '$l lower at t=${i / 100}',
          );
        }
        expect(p.spineMid.distanceTo(p.pelvis), closeTo(sk.trunk / 2, 1e-9));
        expect(p.neck.distanceTo(p.spineMid), closeTo(sk.trunk / 2, 1e-9));
      }
    });

    test('a planted foot stays exactly where it was put', () {
      for (var i = 0; i < 100; i++) {
        final p = c.sample(sk, i / 100);
        expect(p[Limb.legL].end.distanceTo(const V2(0, 6.5)), lessThan(1e-9));
        expect(p[Limb.legL].miss, lessThan(1e-9));
      }
    });

    test('the far side sits one depth step behind the near side', () {
      final p = c.sample(sk, 0.3);
      expect(p[Limb.armR].root, p[Limb.armL].root + sk.depth);
      expect(p[Limb.legR].root, p[Limb.legL].root + sk.depth);
      expect(
        p[Limb.legR].end.distanceTo(const V2(0, 6.5) + sk.depth),
        lessThan(1e-9),
      );
      expect(p[Limb.legR].far, isTrue);
      expect(p[Limb.legL].far, isFalse);
    });

    test('joint angles place the hand by forward kinematics', () {
      final p = c.sample(sk, 0);
      final shoulder = p[Limb.armL].root;
      expect(p[Limb.armL].end.x, closeTo(shoulder.x, 1e-9));
      expect(
        p[Limb.armL].end.y,
        closeTo(shoulder.y - sk.upperArm - sk.forearm, 1e-9),
      );
    });

    test('a body target rides on the trunk as it tilts', () {
      final j = squatJson();
      for (final k in j['keyframes'] as List) {
        k['armL'] = {
          'body': [45, -9],
        };
      }
      final rigged = MotionClip.fromJson(j);
      for (final t in const [0.0, 0.2, 0.5, 0.8]) {
        final p = rigged.sample(sk, t);
        final d = V2.polar(deg(p.trunk));
        final expected = p.pelvis + d * 45 + d.perpCw * -9;
        expect(p[Limb.armL].end.distanceTo(expected), lessThan(1e-9));
      }
    });

    test('trunk-relative angles hold a front rack as the torso tilts', () {
      final j = squatJson();
      for (final k in j['keyframes'] as List) {
        k['armL'] = {
          'fkb': [-80, 100],
        };
      }
      final rigged = MotionClip.fromJson(j);
      for (final t in const [0.0, 0.2, 0.5, 0.8]) {
        final p = rigged.sample(sk, t);
        final arm = p[Limb.armL];
        final upper = (arm.mid - arm.root).angle;
        final lower = (arm.end - arm.mid).angle;
        expect(_wrapDeg(upper - deg(p.trunk - 80)), closeTo(0, 1e-9));
        expect(_wrapDeg(lower - deg(p.trunk + 100)), closeTo(0, 1e-9));
      }
    });

    test('a limb can be drawn foreshortened, and keeps that length', () {
      // A wide grip seen side-on: the arm reaches partly out of the picture,
      // so its projection is shorter. Constant for the clip, never per frame.
      final j = squatJson()..['scale'] = {'armL': 0.75, 'armR': 0.75};
      final c = MotionClip.fromJson(j);
      expect(c.scale(Limb.armL), 0.75);
      expect(c.scale(Limb.legL), 1.0);
      for (final t in const [0.0, 0.3, 0.7]) {
        final p = c.sample(sk, t);
        expect(
          p[Limb.armL].mid.distanceTo(p[Limb.armL].root),
          closeTo(sk.upperArm * 0.75, 1e-9),
        );
      }
      final bad = squatJson()..['scale'] = {'armL': 0.3};
      expect(() => MotionClip.fromJson(bad), throwsFormatException);
    });

    test(
      'a limb swinging out of the picture shortens, both bones together',
      () {
        // A pull-apart seen from behind: the arms start pointing away from
        // the viewer (short on screen) and end out to the sides (full length).
        final j = squatJson();
        final kfs = j['keyframes'] as List;
        kfs[0]['armL'] = {
          'fk': [-90, -90],
          's': 1.0,
        };
        kfs[1]['armL'] = {
          'fk': [-60, 0],
          's': 0.5,
        };
        final c = MotionClip.fromJson(j);
        final p = c.sample(sk, 0.25); // halfway through an inOut segment
        expect(p[Limb.armL].scale, closeTo(0.75, 1e-9));
        expect(
          p[Limb.armL].mid.distanceTo(p[Limb.armL].root),
          closeTo(sk.upperArm * 0.75, 1e-9),
        );
        expect(
          p[Limb.armL].end.distanceTo(p[Limb.armL].mid),
          closeTo(sk.forearm * 0.75, 1e-9),
        );

        kfs[1]['armL'] = {
          'fk': [-60, 0],
          's': 0.1,
        };
        expect(() => MotionClip.fromJson(j), throwsFormatException);
      },
    );

    test('each bone can turn out of the picture by its own amount', () {
      // The bottom of a dumbbell bench press, side-on: the upper arm points
      // mostly out to the side (short on screen), the forearm straight up
      // (full length). One factor for both would put the elbow on the chest.
      final j = squatJson();
      final kfs = j['keyframes'] as List;
      kfs[0]['armL'] = {
        'fk': [-90, -90],
        's': [0.4, 0.9],
      };
      kfs[1]['armL'] = {
        'fk': [-60, 0],
        's': [0.4, 0.9],
      };
      final p = MotionClip.fromJson(j).sample(sk, 0.3);
      expect(p[Limb.armL].scale, closeTo(0.4, 1e-9));
      expect(p[Limb.armL].scaleLower, closeTo(0.9, 1e-9));
      expect(
        p[Limb.armL].mid.distanceTo(p[Limb.armL].root),
        closeTo(sk.upperArm * 0.4, 1e-9),
      );
      expect(
        p[Limb.armL].end.distanceTo(p[Limb.armL].mid),
        closeTo(sk.forearm * 0.9, 1e-9),
      );
    });

    test('an upright side-on figure faces +x', () {
      final p = c.sample(sk, 0);
      expect(p.anteriorUpper.x, closeTo(1, 1e-9));
      expect(p.anteriorUpper.y, closeTo(0, 1e-9));
    });

    test('lying with the head to the left is face up', () {
      final j = squatJson();
      (j['keyframes'] as List)[0]['trunk'] = 180;
      final p = MotionClip.fromJson(j).sample(sk, 0);
      expect(p.anteriorUpper.x, closeTo(0, 1e-9));
      expect(p.anteriorUpper.y, closeTo(1, 1e-9));
    });

    test('a rounded spine bows backwards, away from the chest', () {
      final j = squatJson();
      (j['keyframes'] as List)[0]['spine'] = 30;
      final p = MotionClip.fromJson(j).sample(sk, 0);
      expect(p.spineMid.x, lessThan(p.pelvis.x));
      expect(p.spineMid.x, lessThan(p.neck.x));
    });

    test('the head sits on the neck, clear of the shoulders', () {
      final p = c.sample(sk, 0);
      expect(p.head.distanceTo(p.neck), closeTo(sk.neck + sk.headR, 1e-9));
      expect(p.head.y, greaterThan(p.neck.y));
    });

    test('a flat foot puts heel and toe on the floor', () {
      final p = c.sample(sk, 0);
      expect(p.heels[Limb.legL]!.y, closeTo(0, 1e-9));
      expect(p.toes[Limb.legL]!.y, closeTo(0, 1e-9));
      expect(p.toes[Limb.legL]!.x, greaterThan(p.heels[Limb.legL]!.x));
    });

    test('a clip can put limbs behind the body without greying them', () {
      // A pull-apart seen from behind: the hands start in front of the
      // chest, so the arms are drawn behind the trunk -- but they are not
      // the far side of a side view, so they keep the near colour.
      final j = squatJson()
        ..['view'] = 'back'
        ..['behind'] = ['armL', 'armR'];
      final p = MotionClip.fromJson(j).sample(sk, 0);
      expect(p[Limb.armL].behind, isTrue);
      expect(p[Limb.armL].far, isFalse);
      expect(p[Limb.legL].behind, isFalse);

      final side = MotionClip.fromJson(squatJson()).sample(sk, 0);
      expect(side[Limb.armR].behind, isTrue, reason: 'the far side');
      expect(side[Limb.armL].behind, isFalse);
    });

    test('a front view spreads the shoulders, left on the viewer\'s right', () {
      final front = MotionClip.fromJson(squatJson()..['view'] = 'front');
      final p = front.sample(sk, 0);
      expect(
        p[Limb.armL].root.x - p[Limb.armR].root.x,
        closeTo(sk.shoulderHalf * 2, 1e-9),
      );
      expect(
        p[Limb.legL].root.x - p[Limb.legR].root.x,
        closeTo(sk.hipHalf * 2, 1e-9),
      );
      expect(p[Limb.armR].far, isFalse);

      final back = MotionClip.fromJson(squatJson()..['view'] = 'back');
      final q = back.sample(sk, 0);
      expect(q[Limb.armL].root.x, lessThan(q[Limb.armR].root.x));
    });
  });

  group('props', () {
    final c = MotionClip.fromJson(squatJson());

    test('an attached prop follows the hand', () {
      for (final t in const [0.0, 0.3, 0.6]) {
        final p = c.sample(sk, t);
        final db = p.props.firstWhere((x) => x.type == 'dumbbell');
        expect(db.points.single, p[Limb.armL].end);
        expect(db.layer, PropLayer.near);
      }
    });

    test('a fixed prop keeps its world points and parameters', () {
      final p = c.sample(sk, 0.4);
      final bench = p.props.firstWhere((x) => x.type == 'bench');
      expect(bench.points, [const V2(-40, 45), const V2(40, 45)]);
      expect(bench.params['h'], 45);
      expect(bench.layer, PropLayer.back);
    });

    test('a prop can ride on the trunk, whatever the hands do', () {
      // A back-squat bar sits on the upper back; the hands only steady it.
      final j = squatJson();
      (j['props'] as List).add({
        'type': 'barbell',
        'pts': [
          {
            'body': [46, -8],
          },
        ],
      });
      final c = MotionClip.fromJson(j);
      for (final t in const [0.0, 0.3, 0.5]) {
        final p = c.sample(sk, t);
        final bar = p.props.firstWhere((x) => x.type == 'barbell');
        final d = V2.polar(deg(p.trunk));
        final expected = p.pelvis + d * 46 + d.perpCw * -8;
        expect(bar.points.single.distanceTo(expected), lessThan(1e-9));
        expect(bar.layer, PropLayer.near);
      }
    });

    test('an unknown attachment is refused when the clip is read', () {
      final j = squatJson();
      (j['props'] as List).add({
        'type': 'band',
        'pts': ['elbowQ'],
      });
      expect(() => MotionClip.fromJson(j), throwsFormatException);
    });
  });

  group('tight bounds', () {
    test('frame the body and what it holds, not the scenery', () {
      // A thumbnail spends its few pixels on the lifter; the bench can be
      // cropped. Attached props (the dumbbell) still count.
      final c = MotionClip.fromJson(squatJson());
      final loose = c.bounds(sk);
      final tight = c.bounds(sk, scenery: false);
      expect(loose.minX, lessThanOrEqualTo(-40));
      expect(tight.minX, greaterThan(-40));
      expect(tight.minY, lessThanOrEqualTo(0), reason: 'the floor stays');
      expect(tight.maxY, loose.maxY);
    });
  });

  group('bounds', () {
    test('cover the whole loop, head to sole, and every prop', () {
      final c = MotionClip.fromJson(squatJson());
      final b = c.bounds(sk);
      expect(b.minY, lessThanOrEqualTo(0));
      expect(b.maxY, greaterThanOrEqualTo(86 + sk.trunk + sk.neck));
      expect(b.minX, lessThanOrEqualTo(-40));
      expect(b.maxX, greaterThanOrEqualTo(40));
      expect(b.width, greaterThan(0));
      expect(b.height, greaterThan(0));
    });
  });
}

const skeletonJson = <String, dynamic>{
  'trunk': 50,
  'neck': 8,
  'headR': 10.5,
  'upperArm': 30,
  'forearm': 31,
  'thigh': 39,
  'shin': 41,
  'shoulderHalf': 15,
  'hipHalf': 9,
  'depth': [-2.5, 1.2],
  'foot': {
    'heel': [-6, -6.5],
    'toe': [19, -6.5],
  },
  'footFront': {
    'heel': [-3, -6.5],
    'toe': [4, -6.5],
  },
  'girth': <String, dynamic>{},
};

/// A two-keyframe squat: stand, sit back, stand. Feet planted, arms by
/// angle, a dumbbell in the near hand and a bench behind.
Map<String, dynamic> squatJson() => {
  'id': 'test-squat',
  'name': 'Test squat',
  'view': 'side',
  'periodMs': 2000,
  'travel': 0,
  'still': 0.5,
  'provenance': 'original work',
  'bend': {'armL': -1, 'armR': -1, 'legL': 1, 'legR': 1},
  'props': [
    {
      'type': 'dumbbell',
      'pts': ['handL'],
      'layer': 'near',
    },
    {
      'type': 'bench',
      'pts': [
        [-40, 45],
        [40, 45],
      ],
      'h': 45,
    },
  ],
  'keyframes': [
    {
      't': 0.0,
      'pelvis': [0, 86],
      'trunk': 90,
      'armL': {
        'fk': [-90, -90],
      },
      'armR': {
        'fk': [-90, -90],
      },
      'legL': {
        'at': [0, 6.5],
      },
      'legR': {
        'at': [0, 6.5],
      },
    },
    {
      't': 0.5,
      'pelvis': [-10, 55],
      'trunk': 60,
      'armL': {
        'fk': [-60, 0],
      },
      'armR': {
        'fk': [-60, 0],
      },
      'legL': {
        'at': [0, 6.5],
      },
      'legR': {
        'at': [0, 6.5],
      },
    },
  ],
};

/// An angle difference folded into (-pi, pi].
double _wrapDeg(double r) {
  var x = r;
  while (x > math.pi) {
    x -= 2 * math.pi;
  }
  while (x <= -math.pi) {
    x += 2 * math.pi;
  }
  return x;
}
