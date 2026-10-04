import 'dart:math' as math;
import 'dart:typed_data';

import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/run_repository.dart';
import 'package:keller_twelve/data/run_terrain.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/domain/terrain/terrain.dart';

/// The Baumberge, west of Münster: where the made-up hill stands.
const hillTop = GeoPoint(51.9700, 7.3700);

/// Local metres from [hillTop]: x east, y north.
({double x, double y}) _local(double lat, double lng) => (
  x:
      (lng - hillTop.lng) *
      math.pi /
      180 *
      earthRadiusM *
      math.cos(hillTop.lat * math.pi / 180),
  y: (lat - hillTop.lat) * math.pi / 180 * earthRadiusM,
);

GeoPoint _at(double x, double y) => GeoPoint(
  hillTop.lat + y / earthRadiusM * 180 / math.pi,
  hillTop.lng +
      x /
          (earthRadiusM * math.cos(hillTop.lat * math.pi / 180)) *
          180 /
          math.pi,
);

/// Ground height on the made-up country: a 260 m hill with a spur to the
/// east and a valley to its south, on an 80 m plain.
double hillHeightM(double lat, double lng) {
  final p = _local(lat, lng);
  double bump(double cx, double cy, double r, double h) =>
      h * math.exp(-(math.pow(p.x - cx, 2) + math.pow(p.y - cy, 2)) / (r * r));
  return 80 +
      bump(0, 0, 900, 260) +
      bump(1100, 300, 600, 120) -
      bump(200, -1200, 700, 35) +
      6 * math.sin(p.x / 140) * math.cos(p.y / 170);
}

/// Elevation tiles without a network: the made-up country, or nothing when
/// [online] is false.
class FakeTerrain implements TerrainTileSource {
  FakeTerrain({this.online = true});

  bool online;
  int requests = 0;

  @override
  Future<Float32List?> heights(TileId t) async {
    requests++;
    if (!online) return null;
    final out = Float32List(256 * 256);
    final lats = [
      for (var py = 0; py < 256; py++) latOfTileY(t.y + (py + 0.5) / 256, t.z),
    ];
    final lngs = [
      for (var px = 0; px < 256; px++) lngOfTileX(t.x + (px + 0.5) / 256, t.z),
    ];
    for (var py = 0; py < 256; py++) {
      for (var px = 0; px < 256; px++) {
        out[py * 256 + px] = hillHeightM(lats[py], lngs[px]);
      }
    }
    return out;
  }
}

/// A Sunday hike over the hill: up its west side to the top, along the
/// spur, round the valley and back. One fix every [everySec] seconds, the
/// phone's heights a few metres off the ground's, as phones' are.
List<RunFix> believableHike({int everySec = 3, int? startMs}) {
  const waypoints = [
    (-1500.0, -1000.0),
    (-1000.0, -650.0),
    (-500.0, -300.0),
    (-150.0, -60.0),
    (0.0, 0.0),
    (500.0, 180.0),
    (1100.0, 300.0),
    (1300.0, -300.0),
    (900.0, -1000.0),
    (200.0, -1500.0),
    (-700.0, -1450.0),
    (-1500.0, -1000.0),
  ];
  const speed = 1.15;
  final t0 = startMs ?? DateTime(2026, 10, 18, 9, 30).millisecondsSinceEpoch;
  final out = <RunFix>[];
  var t = 0.0;
  for (var i = 1; i < waypoints.length; i++) {
    final (ax, ay) = waypoints[i - 1];
    final (bx, by) = waypoints[i];
    final len = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2));
    // Slower uphill: the first third of the walk is the climb.
    final pace = i <= 4 ? speed * 0.75 : speed;
    final secs = len / pace;
    for (var s = 0.0; s < secs; s += everySec) {
      final f = s / secs;
      final x = ax + (bx - ax) * f;
      final y = ay + (by - ay) * f;
      final p = _at(x, y);
      out.add(
        RunFix(
          tMs: t0 + ((t + s) * 1000).round(),
          lat: p.lat,
          lng: p.lng,
          accuracyM: 4,
          altitudeM:
              hillHeightM(p.lat, p.lng) + 3 * math.sin((t + s) / 37) + 1.5,
        ),
      );
    }
    t += secs;
  }
  return out;
}

/// [believableHike], finished and in [db]: its run id.
Future<int> seedHike(AppDatabase db, {int everySec = 4}) async {
  final hikes = RunRepository(db, clock: () => DateTime(2026, 10, 18, 9, 30));
  final id = await hikes.start(kind: RunKind.hike);
  final t = RunTrack.hike();
  var first = true;
  for (final f in believableHike(everySec: everySec)) {
    t.add(f, segmentStart: first);
    await hikes.addPoint(id, f, segmentStart: first);
    first = false;
  }
  await hikes.finish(id, t, effort: 6);
  return id;
}
