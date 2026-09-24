import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/motion/motion.dart';

/// The shipped demos, checked frame by frame against the rules a real body
/// keeps.
///
/// motion_clip_test proves the rig on a clip small enough to check on paper.
/// This runs the same rig over every clip in the REAL motions.json, because
/// the rig being right does not make the keyframes right: a hand-set pose can
/// still ask for an arm longer than the arm, or put a knee through the floor.
void main() {
  final lib = MotionLibrary.fromJson(
    jsonDecode(File('assets/exercises/motions.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final exercises =
      (jsonDecode(File('assets/exercises/exercises.json').readAsStringSync())
              as Map<String, dynamic>)['exercises']
          as List;

  const frames = 120;

  test('every exercise in the library has a demo', () {
    for (final e in exercises) {
      final id = (e as Map)['id'] as String;
      expect(lib.forExercise(id), isNotNull, reason: '$id has no motion');
    }
  });

  test('every clip is used by at least one exercise', () {
    final used = {for (final e in exercises) lib.forExercise(e['id'])?.id};
    for (final c in lib.clips.values) {
      expect(used, contains(c.id), reason: '${c.id} is never shown');
    }
  });

  test('everything is original work', () {
    for (final c in lib.clips.values) {
      expect(c.provenance, 'original work', reason: c.id);
    }
    for (final e in lib.exerciseProvenance.entries) {
      expect(e.value, 'original work', reason: e.key);
    }
  });

  test('every muscle the library names can be drawn', () {
    for (final e in exercises) {
      final m = e as Map;
      for (final muscle in [
        ...m['primaryMuscles'] as List,
        ...m['secondaryMuscles'] as List,
      ]) {
        expect(
          lib.regionsFor(muscle as String),
          isNotEmpty,
          reason: '${m['id']} names $muscle',
        );
      }
    }
  });

  test('every demo shows at least one muscle it trains', () {
    // A lateral raise drawn from the side would hide the side delts it is
    // for; the view has to face the work.
    for (final e in exercises) {
      final m = e as Map;
      final clip = lib.forExercise(m['id'] as String)!;
      final primary = lib.regionsForAll(
        (m['primaryMuscles'] as List).cast<String>(),
      );
      expect(
        primary.any((r) => r.shownFrom(clip.view)),
        isTrue,
        reason:
            '${m['id']} (${clip.view.name} view) shows none of '
            '${primary.map((r) => r.name)}',
      );
    }
  });

  test('a side view shows every region; front and back split them', () {
    for (final r in BodyRegion.values) {
      expect(r.shownFrom(MotionView.side), isTrue, reason: r.name);
      expect(
        r.shownFrom(MotionView.front) || r.shownFrom(MotionView.back),
        isTrue,
        reason: '${r.name} is drawn from neither the front nor the back',
      );
    }
    expect(BodyRegion.chest.shownFrom(MotionView.back), isFalse);
    expect(BodyRegion.lats.shownFrom(MotionView.front), isFalse);
  });

  for (final clip in lib.clips.values) {
    group(clip.id, () {
      final poses = [
        for (var i = 0; i < frames; i++) clip.sample(lib.skeleton, i / frames),
      ];

      test('no bone changes length, nothing is NaN', () {
        for (final p in poses) {
          for (final l in Limb.values) {
            final limb = p[l];
            expect(limb.end.isFinite, isTrue, reason: '$l at ${p.t}');
            // A bone may be drawn shorter as it turns out of the picture,
            // but only as far as the projection says, and never longer
            // than it is: never a stretched shin.
            expect(limb.scale, inInclusiveRange(0.2, 1.0));
            expect(limb.scaleLower, inInclusiveRange(0.2, 1.0));
            expect(
              limb.mid.distanceTo(limb.root),
              closeTo(lib.skeleton.upper(l) * limb.scale, 1e-6),
            );
            expect(
              limb.end.distanceTo(limb.mid),
              closeTo(lib.skeleton.lower(l) * limb.scaleLower, 1e-6),
            );
          }
        }
      });

      test('a limb turns out of the picture smoothly, never in a jump', () {
        for (var i = 1; i < poses.length; i++) {
          for (final l in Limb.values) {
            expect(
              (poses[i][l].scale - poses[i - 1][l].scale).abs(),
              lessThan(0.08),
              reason: '$l at t=${poses[i].t}',
            );
            expect(
              (poses[i][l].scaleLower - poses[i - 1][l].scaleLower).abs(),
              lessThan(0.08),
              reason: '$l forearm/shin at t=${poses[i].t}',
            );
          }
        }
      });

      test('side-on, legs are never foreshortened', () {
        // Every side-on leg movement in the programme is drawn in its own
        // plane; a short shin there would be a bug hiding a bad pose. (Seen
        // from the front, a seated thigh really does point at you.)
        if (clip.view != MotionView.side) return;
        for (final p in poses) {
          for (final l in const [Limb.legL, Limb.legR]) {
            expect(p[l].scale, 1.0, reason: '$l at t=${p.t}');
            expect(p[l].scaleLower, 1.0, reason: '$l at t=${p.t}');
          }
        }
      });

      test('every hand and foot reaches what it is holding', () {
        // Half a centimetre: an arm that falls short of the bar by more
        // than that is visibly not holding it.
        for (final p in poses) {
          for (final l in Limb.values) {
            expect(
              p[l].miss,
              lessThan(0.5),
              reason:
                  '$l misses its target by ${p[l].miss.toStringAsFixed(2)} '
                  'at t=${p.t.toStringAsFixed(3)}',
            );
          }
        }
      });

      test('nothing goes through the floor', () {
        for (final p in poses) {
          for (final j in p.joints) {
            expect(
              j.y,
              greaterThan(-0.5),
              reason: 'a joint at y=${j.y} at t=${p.t}',
            );
          }
          for (final l in const [Limb.legL, Limb.legR]) {
            expect(p.heels[l]!.y, greaterThan(-0.5), reason: 'heel $l');
            expect(p.toes[l]!.y, greaterThan(-0.5), reason: 'toe $l');
          }
        }
      });

      test('props resolve to real points', () {
        for (final p in poses) {
          for (final prop in p.props) {
            for (final pt in prop.points) {
              expect(pt.isFinite, isTrue, reason: prop.type);
            }
          }
        }
      });

      test('has a sensible tempo and still frame', () {
        expect(clip.periodMs, inInclusiveRange(600, 12000));
        expect(clip.still, inInclusiveRange(0, 1));
        final b = clip.bounds(lib.skeleton);
        expect(b.width, greaterThan(20));
        expect(b.height, greaterThan(20));
      });
    });
  }
}
