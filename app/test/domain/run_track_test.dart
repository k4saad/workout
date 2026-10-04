import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/run/run.dart';

/// The arithmetic of a GPS run: distance, moving time, pace, splits.
///
/// Written before the tracker. A phone in a pocket reports a position every
/// second, some of them wrong: standing at a crossing drifts a few metres, a
/// bad fix jumps a street. The numbers Saad sees after a run are only worth
/// logging if those are handled here, where they can be tested.
void main() {
  // Münster, Schlossplatz: somewhere real to run.
  const origin = GeoPoint(51.9634, 7.6130);

  /// A point [north] and [east] metres from [p].
  GeoPoint offset(GeoPoint p, double north, double east) {
    const m = 111195.0;
    return GeoPoint(
      p.lat + north / m,
      p.lng + east / (m * math.cos(p.lat * math.pi / 180)),
    );
  }

  RunFix fix(int tMs, GeoPoint p, {double accuracy = 5, double? altitude}) =>
      RunFix(
        tMs: tMs,
        lat: p.lat,
        lng: p.lng,
        accuracyM: accuracy,
        altitudeM: altitude,
      );

  /// A steady run due north at [speed] m/s, one fix a second.
  List<RunFix> run({
    required int seconds,
    required double speed,
    GeoPoint from = origin,
    int startMs = 0,
  }) => [
    for (var s = 0; s <= seconds; s++)
      fix(startMs + s * 1000, offset(from, speed * s, 0)),
  ];

  group('haversine', () {
    test('a thousandth of a degree north is about 111 m', () {
      final d = haversineM(origin, GeoPoint(origin.lat + 0.001, origin.lng));
      expect(d, closeTo(111.19, 0.05));
    });

    test('is symmetric, and zero for the same point', () {
      final a = offset(origin, 300, -120);
      expect(haversineM(origin, a), closeTo(haversineM(a, origin), 1e-9));
      expect(haversineM(a, a), 0);
    });

    test('agrees with the offsets the tests build points with', () {
      expect(haversineM(origin, offset(origin, 0, 250)), closeTo(250, 0.5));
      expect(haversineM(origin, offset(origin, 300, 400)), closeTo(500, 0.5));
    });
  });

  group('the fix filter', () {
    test('takes a good fix', () {
      final f = FixFilter();
      expect(f.judge(fix(0, origin)), FixVerdict.accept);
    });

    test('refuses a fix it cannot trust', () {
      final f = FixFilter();
      expect(f.judge(fix(0, origin, accuracy: 60)), FixVerdict.inaccurate);
      expect(
        f.judge(const RunFix(tMs: 0, lat: 51.9, lng: 7.6, accuracyM: null)),
        FixVerdict.inaccurate,
      );
    });

    test('takes a vague but usable fix: ±35 m adds trail, not metres', () {
      // Distance is counted in steps of at least half the accuracy, so a
      // vaguer fix cannot invent distance; dropping it would leave a gap.
      final f = FixFilter();
      expect(f.judge(fix(0, origin, accuracy: 35)), FixVerdict.accept);
    });

    test('refuses a fix older than the last one', () {
      final f = FixFilter();
      expect(f.judge(fix(5000, origin)), FixVerdict.accept);
      expect(f.judge(fix(4000, offset(origin, 3, 0))), FixVerdict.stale);
      expect(f.judge(fix(5000, offset(origin, 3, 0))), FixVerdict.stale);
    });

    test('refuses a jump no runner can make', () {
      // 150 m in a second is a bad fix, not a sprint.
      final f = FixFilter();
      expect(f.judge(fix(0, origin)), FixVerdict.accept);
      expect(f.judge(fix(1000, offset(origin, 150, 0))), FixVerdict.teleport);
      // ...and the jump does not become the new reference point.
      expect(f.judge(fix(2000, offset(origin, 4, 0))), FixVerdict.accept);
    });

    test('after a pause the first fix is judged afresh', () {
      final f = FixFilter();
      f.judge(fix(0, origin));
      f.reset();
      // Walked 400 m to a new start while paused: fine.
      expect(f.judge(fix(60000, offset(origin, 400, 0))), FixVerdict.accept);
    });
  });

  group('distance and moving time', () {
    test('a steady run adds up', () {
      final t = RunTrack();
      for (final f in run(seconds: 100, speed: 3)) {
        t.add(f);
      }
      expect(t.distanceM, closeTo(300, 3));
      expect(t.movingMs, closeTo(100000, 3000));
      expect(t.avgPaceSecPerKm, closeTo(333.3, 6));
    });

    test('standing still with GPS drift adds almost nothing', () {
      final rng = math.Random(3);
      final t = RunTrack();
      for (var s = 0; s <= 60; s++) {
        t.add(
          fix(
            s * 1000,
            offset(origin, rng.nextDouble() * 4 - 2, rng.nextDouble() * 4 - 2),
          ),
        );
      }
      expect(t.distanceM, lessThan(8));
      expect(t.movingMs, lessThan(8000));
      expect(t.autoPaused, isTrue);
    });

    test('a stop at a crossing is not moving time', () {
      final t = RunTrack();
      final first = run(seconds: 60, speed: 3);
      for (final f in first) {
        t.add(f);
      }
      final stop = offset(origin, 180, 0);
      for (var s = 1; s <= 30; s++) {
        t.add(fix(60000 + s * 1000, stop));
      }
      for (final f in run(
        seconds: 60,
        speed: 3,
        from: stop,
        startMs: 90000,
      ).skip(1)) {
        t.add(f);
      }
      expect(t.distanceM, closeTo(360, 6));
      expect(t.movingMs, closeTo(120000, 8000));
      expect(t.elapsedMs, 150000);
    });

    test('nothing is counted across a pause', () {
      final t = RunTrack();
      for (final f in run(seconds: 30, speed: 3)) {
        t.add(f);
      }
      // Paused, walked 500 m, resumed: a new segment.
      final resume = offset(origin, 590, 0);
      var first = true;
      for (final f in run(
        seconds: 30,
        speed: 3,
        from: resume,
        startMs: 300000,
      )) {
        t.add(f, segmentStart: first);
        first = false;
      }
      expect(t.distanceM, closeTo(180, 4));
      expect(t.segments, hasLength(2));
      expect(t.movingMs, closeTo(60000, 4000));
    });
  });

  group('pace', () {
    test('the current pace follows the last few seconds', () {
      final t = RunTrack();
      for (final f in run(seconds: 40, speed: 1000 / 300)) {
        t.add(f);
      }
      expect(t.currentPaceSecPerKm, closeTo(300, 12));
    });

    test('stopped, there is no current pace to show', () {
      final t = RunTrack();
      for (final f in run(seconds: 30, speed: 3)) {
        t.add(f);
      }
      final stop = offset(origin, 90, 0);
      for (var s = 1; s <= 20; s++) {
        t.add(fix(30000 + s * 1000, stop));
      }
      expect(t.currentPaceSecPerKm, isNull);
    });

    test('max speed ignores a single bad step', () {
      final t = RunTrack();
      final fixes = run(seconds: 60, speed: 3);
      for (final f in fixes) {
        t.add(f);
      }
      expect(t.maxSpeedMps, closeTo(3, 0.3));
    });
  });

  group('splits', () {
    test('one per full kilometre, then the part-kilometre', () {
      final t = RunTrack();
      for (final f in run(seconds: 625, speed: 4)) {
        t.add(f);
      }
      final s = t.splits;
      expect(s, hasLength(3));
      expect(s[0].km, 1);
      expect(s[0].movingMs, closeTo(250000, 3000));
      expect(s[1].movingMs, closeTo(250000, 3000));
      expect(s[2].partial, isTrue);
      expect(s[2].distanceM, closeTo(500, 10));
      expect(s[0].paceSecPerKm, closeTo(250, 3));
    });

    test('a run under a kilometre is one partial split', () {
      final t = RunTrack();
      for (final f in run(seconds: 100, speed: 3)) {
        t.add(f);
      }
      expect(t.splits, hasLength(1));
      expect(t.splits.single.partial, isTrue);
    });
  });

  group('the pace profile', () {
    test('a steady run draws a flat line', () {
      final t = RunTrack();
      for (final f in run(seconds: 250, speed: 4)) {
        t.add(f);
      }
      final p = t.profile(bucketM: 100);
      expect(p, hasLength(10));
      for (final b in p) {
        expect(b.paceSecPerKm, closeTo(250, 12));
      }
      expect(p.last.distanceM, closeTo(1000, 1));
    });

    test('a faster second half shows as a faster second half', () {
      final t = RunTrack();
      for (final f in run(seconds: 150, speed: 1000 / 300)) {
        t.add(f);
      }
      final mid = offset(origin, 500, 0);
      for (final f in run(
        seconds: 100,
        speed: 5,
        from: mid,
        startMs: 150000,
      ).skip(1)) {
        t.add(f);
      }
      final p = t.profile(bucketM: 100);
      expect(p.first.paceSecPerKm, closeTo(300, 15));
      expect(p.last.paceSecPerKm, closeTo(200, 15));
    });

    test('no distance, no profile', () {
      expect(RunTrack().profile(), isEmpty);
    });
  });

  group('elevation', () {
    test('climbing counts, noise does not', () {
      final rng = math.Random(9);
      final t = RunTrack();
      for (var s = 0; s <= 100; s++) {
        t.add(
          fix(
            s * 1000,
            offset(origin, 3.0 * s, 0),
            altitude: s * 0.2 + rng.nextDouble() * 2 - 1,
          ),
        );
      }
      expect(t.elevGainM, closeTo(20, 3));
    });

    test('a flat run with a noisy altimeter gains nothing', () {
      final rng = math.Random(4);
      final t = RunTrack();
      for (var s = 0; s <= 100; s++) {
        t.add(
          fix(
            s * 1000,
            offset(origin, 3.0 * s, 0),
            altitude: 60 + rng.nextDouble() * 3 - 1.5,
          ),
        );
      }
      expect(t.elevGainM, lessThan(1.5));
    });

    /// Up 60 m over the first 200 s, then down 40 m over the next 200 s,
    /// walking north at 1.2 m/s.
    RunTrack hill() {
      final t = RunTrack.hike();
      for (var s = 0; s <= 400; s++) {
        final alt = s <= 200 ? 100 + s * 0.3 : 160 - (s - 200) * 0.2;
        t.add(fix(s * 1000, offset(origin, 1.2 * s, 0), altitude: alt));
      }
      return t;
    }

    test('the descent is counted like the climb', () {
      final t = hill();
      expect(t.elevGainM, closeTo(60, 4));
      expect(t.elevLossM, closeTo(40, 4));
    });

    test('the highest and lowest points are kept', () {
      final t = hill();
      expect(t.maxAltM, closeTo(160, 3));
      expect(t.minAltM, closeTo(100, 1));
      expect(RunTrack().maxAltM, isNull, reason: 'no altimeter, no height');
    });

    test('the profile follows the hill, one point a bucket', () {
      final t = hill();
      final p = t.elevationProfile(bucketM: 50);
      // 480 m walked: ten buckets.
      expect(p.length, inInclusiveRange(9, 11));
      for (var i = 1; i < p.length; i++) {
        expect(p[i].distanceM, greaterThan(p[i - 1].distanceM));
      }
      final top = p.reduce((a, b) => a.altitudeM > b.altitudeM ? a : b);
      expect(top.distanceM, closeTo(240, 60), reason: 'the summit at 200 s');
      expect(p.first.altitudeM, lessThan(115));
      expect(RunTrack().elevationProfile(), isEmpty);
    });

    test('a slow, steep climb is moving time, not an auto-pause', () {
      // 0.5 m/s: a hard hill on foot. A run's tracker calls that stopped.
      List<RunFix> slow() => [
        for (var s = 0; s <= 120; s++)
          fix(s * 1000, offset(origin, 0.5 * s, 0)),
      ];
      final hike = RunTrack.hike();
      final run = RunTrack();
      for (final f in slow()) {
        hike.add(f);
        run.add(f);
      }
      expect(hike.movingMs, greaterThan(100000));
      expect(run.movingMs, lessThan(hike.movingMs));
    });
  });

  group('the pace guide', () {
    test('needs a couple of easy runs before it has an opinion', () {
      expect(PaceBand.fromHistory(const []), isNull);
      expect(PaceBand.fromHistory(const [370]), isNull);
    });

    test('centres on his own easy pace', () {
      final band = PaceBand.fromHistory(const [360, 380, 370])!;
      expect(band.fastSecPerKm, closeTo(370 * 0.94, 0.01));
      expect(band.slowSecPerKm, closeTo(370 * 1.06, 0.01));
      expect(band.judge(330), PaceZone.easeOff);
      expect(band.judge(372), PaceZone.onPace);
      expect(band.judge(420), PaceZone.pickUp);
      expect(band.judge(null), PaceZone.none);
    });
  });

  group('the programme target', () {
    test('a timed run counts down its minutes', () {
      const target = RunTarget.duration(1200);
      expect(target.progress(movingMs: 600000, distanceM: 1800), 0.5);
      expect(
        target.remainingLabel(movingMs: 600000, distanceM: 1800),
        '10:00 to go',
      );
      expect(target.done(movingMs: 1200000, distanceM: 0), isTrue);
    });

    test('a distance run counts down its metres', () {
      const target = RunTarget.distance(5000);
      expect(target.progress(movingMs: 0, distanceM: 2500), 0.5);
      expect(
        target.remainingLabel(movingMs: 0, distanceM: 2500),
        '2.50 km to go',
      );
      expect(target.progress(movingMs: 0, distanceM: 6000), 1.0);
    });
  });

  group('formatting', () {
    test('pace, clock and kilometres read the way a runner reads them', () {
      expect(formatPace(332.4), '5:32');
      expect(formatPace(599.6), '10:00');
      expect(formatPace(null), '–:––');
      expect(formatClock(65000), '1:05');
      expect(formatClock(3725000), '1:02:05');
      expect(formatKm(3420), '3.42');
      expect(formatKm(0), '0.00');
    });
  });
}
