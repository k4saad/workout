import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/run/run.dart';

/// Distance along a route: what draws it in, runs the replay dot, and
/// colours it by pace.
void main() {
  const origin = GeoPoint(51.9555, 7.6075);
  final t0 = DateTime(2026, 10, 4, 18, 30).millisecondsSinceEpoch;

  /// [metres] north of the origin.
  GeoPoint north(double metres) =>
      GeoPoint(origin.lat + metres / 111195.0, origin.lng);

  RunFix at(int s, double metres) => RunFix(
    tMs: t0 + s * 1000,
    lat: north(metres).lat,
    lng: north(metres).lng,
    accuracyM: 5,
  );

  /// 400 m due north at 3 m/s, one fix a second.
  final straight = [
    [for (var s = 0; s <= 133; s++) at(s, s * 3.0)],
  ];

  group('the path', () {
    test('its length is the distance along it', () {
      final path = RoutePath(straight);
      expect(path.lengthM, closeTo(399, 2));
    });

    test(
      'up to half is half the route, ending exactly at the half-way point',
      () {
        final path = RoutePath(straight);
        final half = path.upTo(0.5);
        expect(half, hasLength(1));
        final end = half.single.last;
        expect(haversineM(origin, end), closeTo(path.lengthM / 2, 1));
        expect(path.upTo(1).single, hasLength(134));
        expect(path.upTo(0), isEmpty);
      },
    );

    test('a pause stays a break, and the gap is not distance', () {
      final paused = [
        [for (var s = 0; s <= 10; s++) at(s, s * 3.0)],
        [for (var s = 100; s <= 110; s++) at(s, 200 + (s - 100) * 3.0)],
      ];
      final path = RoutePath(paused);
      expect(path.lengthM, closeTo(60, 1), reason: 'the 170 m jump is not run');
      expect(path.upTo(1), hasLength(2));
      expect(path.upTo(0.25), hasLength(1));
    });
  });

  group('a stretch of the route', () {
    test('between two distances, ending exactly on them', () {
      final part = RoutePath(straight).between(100, 300);
      expect(part, hasLength(1));
      expect(haversineM(origin, part.single.first), closeTo(100, 1));
      expect(haversineM(origin, part.single.last), closeTo(300, 1));
    });

    test('a pause inside it stays a break', () {
      final paused = [
        [for (var s = 0; s <= 50; s++) at(s, s * 3.0)], // 0-150 m
        [for (var s = 100; s <= 150; s++) at(s, 500 + (s - 100) * 3.0)],
      ];
      // 150 m in the first stretch, 150 m in the second.
      final part = RoutePath(paused).between(100, 250);
      expect(part, hasLength(2));
      expect(haversineM(origin, part.first.first), closeTo(100, 1));
      expect(haversineM(origin, part.last.last), closeTo(600, 1));
    });

    test('nothing, when the stretch is empty', () {
      expect(RoutePath(straight).between(300, 100), isEmpty);
      expect(RoutePath(const []).between(0, 100), isEmpty);
    });
  });

  group('a route that does not give away where it starts', () {
    /// 1.2 km due north.
    final long = [
      for (var s = 0; s <= 400; s++) [at(s, s * 3.0)],
    ].expand((x) => x).toList();

    test('the first and last 200 m are cut', () {
      final shown = privateRoute([long]);
      expect(shown, hasLength(1));
      expect(haversineM(origin, shown.single.first), closeTo(200, 1));
      expect(haversineM(north(1200), shown.single.last), closeTo(200, 1));
    });

    test('a run too short to hide both ends shows nothing at all', () {
      // 400 m: cutting 200 m from each end leaves no route, and what is
      // left of a short loop is all near the door anyway.
      expect(privateRoute(straight), isEmpty);
    });

    test('with nothing hidden, the whole route', () {
      final shown = privateRoute([long], hideM: 0);
      expect(haversineM(origin, shown.single.first), closeTo(0, 0.5));
      expect(haversineM(north(1200), shown.single.last), closeTo(0, 0.5));
    });
  });

  group('the replay dot', () {
    test('half way along, half the distance and half the time', () {
      final path = RoutePath(straight);
      final p = path.at(0.5);
      expect(p.distanceM, closeTo(path.lengthM / 2, 0.5));
      expect(p.elapsedMs, closeTo(66500, 600));
      expect(haversineM(origin, p.point), closeTo(p.distanceM, 1));
    });

    test('the time does not count a pause', () {
      final paused = [
        [for (var s = 0; s <= 10; s++) at(s, s * 3.0)],
        [for (var s = 100; s <= 110; s++) at(s, 200 + (s - 100) * 3.0)],
      ];
      expect(RoutePath(paused).at(1).elapsedMs, 20000);
    });
  });

  group('pace colours', () {
    // 200 m at 5:00/km (3.33 m/s), then 200 m at 6:00/km (2.78 m/s).
    final fixes = <RunFix>[];
    var d = 0.0;
    for (var s = 0; s <= 132; s++) {
      fixes.add(at(s, d));
      d += s < 60 ? 1000 / 300 : 1000 / 360;
    }

    test('each stretch has its own pace, and they join end to end', () {
      final stretches = paceStretches([fixes], everyM: 100);
      expect(stretches.length, greaterThanOrEqualTo(4));
      expect(stretches.first.paceSecPerKm, closeTo(300, 8));
      expect(stretches.last.paceSecPerKm, closeTo(360, 8));
      for (var i = 1; i < stretches.length; i++) {
        expect(stretches[i].points.first, stretches[i - 1].points.last);
      }
    });

    test('the quickest stretch is brightest, the slowest darkest', () {
      final stretches = paceStretches([fixes], everyM: 100);
      final shades = paceShades(stretches);
      expect(shades.first, closeTo(1, 0.01));
      expect(shades.last, closeTo(0, 0.01));
      for (final s in shades) {
        expect(s, inInclusiveRange(0, 1));
      }
    });

    test('a steady run is one even colour, not noise', () {
      final steady = [
        [for (var s = 0; s <= 133; s++) at(s, s * 3.0)],
      ];
      final shades = paceShades(paceStretches(steady, everyM: 100));
      for (final s in shades) {
        expect(s, closeTo(0.5, 0.01));
      }
    });
  });
}
