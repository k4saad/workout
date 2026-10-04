import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/domain/terrain/terrain.dart';

/// The hike's country in 3D: which tiles, what heights, and a scene that
/// draws the land back to front and knows when a hill hides the trail.
void main() {
  // The Baumberge, west of Münster: the nearest thing to a hill.
  const centre = GeoPoint(51.97, 7.37);

  GeoPoint offset(GeoPoint p, double north, double east) {
    const m = 111195.0;
    return GeoPoint(
      p.lat + north / m,
      p.lng + east / (m * math.cos(p.lat * math.pi / 180)),
    );
  }

  RunFix fix(int s, GeoPoint p, {double? alt}) =>
      RunFix(tMs: s * 1000, lat: p.lat, lng: p.lng, altitudeM: alt);

  group('tiles', () {
    test('the equator and the meridian sit in the middle of the world', () {
      expect(tileX(0, 4), 8);
      expect(tileY(0, 4), closeTo(8, 1e-9));
    });

    test('tile coordinates go back to the same place', () {
      for (final z in [8, 12, 14]) {
        final x = tileX(centre.lng, z), y = tileY(centre.lat, z);
        expect(lngOfTileX(x, z), closeTo(centre.lng, 1e-9));
        expect(latOfTileY(y, z), closeTo(centre.lat, 1e-9));
      }
    });

    test('north is row zero', () {
      expect(tileY(52, 10), lessThan(tileY(51, 10)));
    });

    test('a small box in one tile needs one tile; a wide one more', () {
      final x = tileX(centre.lng, 10).floor();
      final y = tileY(centre.lat, 10).floor();
      final inside = GeoBounds(
        south: latOfTileY(y + 0.6, 10),
        west: lngOfTileX(x + 0.4, 10),
        north: latOfTileY(y + 0.4, 10),
        east: lngOfTileX(x + 0.6, 10),
      );
      expect(tilesCovering(inside, 10), [TileId(10, x, y)]);
      final wide = GeoBounds(
        south: latOfTileY(y + 1.5, 10),
        west: lngOfTileX(x - 0.5, 10),
        north: latOfTileY(y - 0.5, 10),
        east: lngOfTileX(x + 1.5, 10),
      );
      final tiles = tilesCovering(wide, 10);
      expect(tiles, hasLength(9));
      expect(tiles.first, TileId(10, x - 1, y - 1), reason: 'north-west');
    });

    test('the zoom is the sharpest that keeps to the tile budget', () {
      final box = GeoBounds.around([
        offset(centre, -2500, -2500),
        offset(centre, 2500, 2500),
      ]);
      final z = zoomFor(box, maxTiles: 9);
      expect(z, lessThanOrEqualTo(14));
      expect(tilesCovering(box, z).length, lessThanOrEqualTo(9));
      if (z < 14) {
        expect(tilesCovering(box, z + 1).length, greaterThan(9));
      }
      // A 5 km box at 52°N is a few km of tile at zoom 12 or 13.
      expect(z, inInclusiveRange(11, 13));
    });

    test('terrarium pixels decode to metres', () {
      expect(terrariumMetres(128, 0, 0), 0);
      expect(terrariumMetres(0, 0, 0), -32768);
      expect(terrariumMetres(128, 100, 128), 100.5);
      final h = decodeTerrarium(
        Uint8List.fromList([128, 100, 128, 255, 128, 0, 0, 255]),
      );
      expect(h, [100.5, 0]);
    });
  });

  group('heights', () {
    // Height rises 1 m per pixel east and 1000 m per pixel south: bilinear
    // interpolation is exact on a plane, so every answer is checkable.
    const size = 4;
    const z = 12;
    Map<TileId, Float32List> plane(int tx0, int ty0, {int across = 2}) => {
      for (var ty = ty0; ty < ty0 + across; ty++)
        for (var tx = tx0; tx < tx0 + across; tx++)
          TileId(z, tx, ty): Float32List.fromList([
            for (var py = 0; py < size; py++)
              for (var px = 0; px < size; px++)
                ((tx * size + px) + (ty * size + py) * 1000).toDouble(),
          ]),
    };

    test('a pixel centre reads its own value', () {
      final tiles = TileHeights(z, plane(100, 200), size: size);
      // Pixel (401, 802) has its centre at 401.5, 802.5.
      final p = GeoPoint(
        latOfTileY(802.5 / size, z),
        lngOfTileX(401.5 / size, z),
      );
      expect(tiles.heightAt(p), closeTo(401 + 802000, 1e-3));
    });

    test('between pixels, and across a tile edge, it interpolates', () {
      final tiles = TileHeights(z, plane(100, 200), size: size);
      // 403.5 .. 404.5 crosses from tile 100 into tile 101.
      final p = GeoPoint(
        latOfTileY(802.5 / size, z),
        lngOfTileX(404 / size, z),
      );
      expect(tiles.heightAt(p), closeTo(403.5 + 802000, 1e-3));
    });

    test('outside the tiles it has no answer', () {
      final tiles = TileHeights(z, plane(100, 200), size: size);
      final p = GeoPoint(latOfTileY(200.5, z), lngOfTileX(90.5, z));
      expect(tiles.heightAt(p), isNull);
    });

    test('a grid with a hole is no grid: never a cliff', () {
      final tiles = TileHeights(z, plane(100, 200), size: size);
      final half = GeoBounds(
        south: latOfTileY(201.5, z),
        west: lngOfTileX(101.5, z),
        north: latOfTileY(201.2, z),
        east: lngOfTileX(102.5, z), // into a tile that is not there
      );
      expect(HeightGrid.sample(tiles, half, cols: 8, rows: 8), isNull);
    });

    test('a grid is local metres from its centre, north up', () {
      final b = GeoBounds.around([
        offset(centre, -1000, -1500),
        offset(centre, 1000, 1500),
      ]);
      final g = HeightGrid(
        b,
        3,
        3,
        Float32List.fromList([10, 20, 30, 40, 50, 60, 70, 80, 90]),
      );
      final c = g.toLocal(b.centre);
      expect(c.x, closeTo(0, 1e-6));
      expect(c.y, closeTo(0, 1e-6));
      expect(g.widthM, closeTo(3000, 5));
      expect(g.depthM, closeTo(2000, 5));
      expect(g.heightAtLocal(0, 0), closeTo(50, 1e-3));
      expect(g.heightAtLocal(-1500, 1000), closeTo(10, 1e-3), reason: 'NW');
      expect(g.heightAtLocal(1500, -1000), closeTo(90, 1e-3), reason: 'SE');
      expect(g.heightAtLocal(9999, 9999), closeTo(30, 1e-3), reason: 'held');
      expect(g.minH, 10);
      expect(g.maxH, 90);
    });

    test('a box squares up and grows, never smaller than asked', () {
      final b = GeoBounds.around([centre, offset(centre, 400, 100)]);
      final s = b.squaredAndPadded(0.25, minSideM: 2000);
      expect(s.widthM, closeTo(s.heightM, 1));
      expect(s.widthM, closeTo(2000, 1));
      final big = GeoBounds.around([centre, offset(centre, 4000, 1000)]);
      expect(big.squaredAndPadded(0.25).heightM, closeTo(6000, 10));
    });
  });

  group('the scene', () {
    const style = TerrainStyle(
      low: 0xff202020,
      high: 0xffd0d0d0,
      fog: 0xff000000,
      wall: 0xff303030,
      curtain: 0x80c01030,
    );

    final bounds = GeoBounds.around([
      offset(centre, -2000, -2000),
      offset(centre, 2000, 2000),
    ]);

    /// A ridge 400 m high running east-west through the middle.
    HeightGrid ridge() {
      const n = 41;
      return HeightGrid(
        bounds,
        n,
        n,
        Float32List.fromList([
          for (var r = 0; r < n; r++)
            for (var c = 0; c < n; c++) 100 + (r == 20 ? 400.0 : 0.0),
        ]),
      );
    }

    /// A walk west to east, 1.5 km north of the ridge.
    List<List<RunFix>> northTrail() => [
      [
        for (var i = 0; i <= 30; i++)
          fix(i * 10, offset(centre, 1500, -1500 + i * 100.0)),
      ],
    ];

    test(
      'mountains stand as they are; flat country is lifted, and says so',
      () {
        expect(TerrainScene.autoExaggeration(1200, 5000), 1);
        expect(TerrainScene.autoExaggeration(20, 5000), 5);
        expect(TerrainScene.autoExaggeration(0, 5000), 1);
      },
    );

    test('the camera looks at the middle of the screen', () {
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
      );
      final cam = scene.fit(azimuth: 0, elevation: 0.5);
      final p = Projector(cam, 400, 300);
      final d = p.depthOf(0, 0, cam.targetZ);
      expect(p.screenX(0, 0, d), closeTo(200, 1e-6));
      expect(p.screenY(0, 0, cam.targetZ, d), closeTo(150, 1e-6));
      // Looking north from the south, east is to the right.
      final de = p.depthOf(500, 0, cam.targetZ);
      expect(p.screenX(500, 0, de), greaterThan(200));
    });

    test('every cell is drawn, with the near sides of the block', () {
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
      );
      final f = scene.frame(Projector(scene.fit(), 400, 400));
      const cells = 40 * 40;
      expect(f.vertexCount, greaterThan(cells * 6), reason: 'land and walls');
      expect(f.vertexCount % 3, 0);
      for (var i = 0; i < f.vertexCount * 2; i++) {
        expect(f.positions[i].isFinite, isTrue);
      }
    });

    test('land is drawn far to near', () {
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
      );
      // From the south: the northern rows (small screen y) come first.
      final f = scene.frame(Projector(scene.fit(azimuth: 0), 400, 400));
      double meanY(int tri) =>
          (f.positions[tri * 6 + 1] +
              f.positions[tri * 6 + 3] +
              f.positions[tri * 6 + 5]) /
          3;
      expect(meanY(0), lessThan(meanY(40 * 40 * 2 - 1)));
    });

    test('a ridge hides the trail behind it, and only then', () {
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
        exaggeration: 1,
      );
      // Low, from the south: the ridge is between the eye and the trail.
      final fromSouth = scene.frame(
        Projector(scene.fit(azimuth: 0, elevation: 0.12), 400, 400),
      );
      expect(fromSouth.trail.where((r) => r.visible), isEmpty);
      expect(fromSouth.trail.where((r) => !r.visible), isNotEmpty);
      // From the north the trail is in front of it.
      final fromNorth = scene.frame(
        Projector(scene.fit(azimuth: math.pi, elevation: 0.12), 400, 400),
      );
      expect(fromNorth.trail.where((r) => !r.visible), isEmpty);
      expect(fromNorth.trail.where((r) => r.visible), isNotEmpty);
    });

    test('the trail draws itself in', () {
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
      );
      final p = Projector(scene.fit(azimuth: math.pi), 400, 400);
      expect(scene.frame(p, reveal: 0).trail, isEmpty);
      final half = scene.frame(p, reveal: 0.5);
      final whole = scene.frame(p, reveal: 1);
      int points(TerrainFrame f) =>
          f.trail.fold(0, (a, r) => a + r.xy.length ~/ 2);
      expect(points(half), lessThan(points(whole)));
      expect(half.head, isNotNull);
      // Seen from the north, walking east is walking left.
      expect(half.head!.x, greaterThan(whole.head!.x));
    });

    test(
      'without terrain the trail stands on its GPS heights over a floor',
      () {
        final trail = [
          [
            for (var i = 0; i <= 20; i++)
              fix(
                i * 10,
                offset(centre, 0, -1000 + i * 100.0),
                alt: 60.0 + i * 5,
              ),
          ],
        ];
        final scene = TerrainScene(
          grid: HeightGrid.flat(bounds, 60),
          trail: trail,
          style: style,
          hasTerrain: false,
        );
        expect(scene.exaggeration, greaterThan(1), reason: '100 m over 4 km');
        final f = scene.frame(Projector(scene.fit(azimuth: 0.3), 400, 400));
        // A floor (one cell), its near walls, and a curtain quad per step.
        expect(f.vertexCount, greaterThan(6 + 20 * 6));
        expect(f.trail.every((r) => r.visible), isTrue);
        expect(scene.highestOnTrailM, isNull, reason: 'no terrain to read');
      },
    );

    test('contour lines come at a round interval, a dozen to the relief', () {
      expect(TerrainScene.niceInterval(33), 50);
      expect(TerrainScene.niceInterval(4), 5);
      expect(TerrainScene.niceInterval(21), 25);
      expect(TerrainScene.niceInterval(9000), 500);
      final scene = TerrainScene(
        grid: ridge(),
        trail: northTrail(),
        style: style,
      );
      expect(scene.contourIntervalM, 50, reason: '400 m of relief');
      final floor = TerrainScene(
        grid: HeightGrid.flat(bounds, 60),
        trail: northTrail(),
        style: style,
        hasTerrain: false,
      );
      expect(floor.contourIntervalM, isNull, reason: 'no ground to contour');
    });

    test('a slope carries its contour lines, drawn with the land', () {
      // A plain ramp, 0 to 400 m south to north: eight 50 m lines.
      const n = 21;
      final ramp = HeightGrid(
        bounds,
        n,
        n,
        Float32List.fromList([
          for (var r = 0; r < n; r++)
            for (var c = 0; c < n; c++) 400.0 * (n - 1 - r) / (n - 1),
        ]),
      );
      final scene = TerrainScene(grid: ramp, trail: northTrail(), style: style);
      final p = Projector(scene.fit(azimuth: 0), 400, 400);
      final withLines = scene.frame(p).vertexCount;
      const land = 20 * 20 * 6;
      // Lines at 50..350 m cross 20 cells each: 7 x 20 quads.
      expect(withLines, greaterThanOrEqualTo(land + 7 * 20 * 6));
    });

    test('the highest ground under the trail comes from the terrain', () {
      final crossing = [
        [
          for (var i = 0; i <= 30; i++)
            fix(i * 10, offset(centre, -1500 + i * 100.0, 0)),
        ],
      ];
      final scene = TerrainScene(grid: ridge(), trail: crossing, style: style);
      expect(scene.highestOnTrailM, closeTo(500, 1));
      expect(scene.trailLengthM, closeTo(3000, 10));
    });
  });
}
