import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:keller_twelve/data/run_terrain.dart';
import 'package:keller_twelve/domain/terrain/terrain.dart';

import '../support/fake_terrain.dart';

/// The ground under a hike: which tiles it asks for, what it does with
/// them, and what it does without them. No network here: the real source is
/// exercised through its cache folder only.
void main() {
  Uint8List terrariumPng(int size, {int r = 128, int g = 100, int b = 128}) {
    final image = img.Image(width: size, height: size);
    for (final p in image) {
      p
        ..r = r
        ..g = g
        ..b = b;
    }
    return img.encodePng(image);
  }

  group('decoding', () {
    test('a terrarium tile decodes to metres', () {
      final h = decodeTerrariumPng(terrariumPng(256))!;
      expect(h, hasLength(256 * 256));
      expect(h.first, 100.5);
      expect(h.last, 100.5);
    });

    test('anything but a 256-pixel tile is refused', () {
      expect(decodeTerrariumPng(terrariumPng(64)), isNull);
      expect(decodeTerrariumPng(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('the tile source', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('kt_terrain_'));
    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows holds the handle a moment longer.
      }
    });

    test('names the tile and nothing else', () {
      expect(
        AwsTerrainTiles.urlFor(const TileId(12, 2134, 1371)).toString(),
        'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/'
        '12/2134/1371.png',
      );
    });

    test('a cached tile is read from the phone, not fetched', () async {
      final file = File('${tmp.path}/12/2134/1371.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(terrariumPng(256, g: 200));
      final h = await AwsTerrainTiles(cacheDir: tmp)
          .heights(const TileId(12, 2134, 1371));
      expect(h, isNotNull);
      expect(h!.first, 200.5);
    });

    test('a corrupt cached tile is thrown away, to be fetched again', () async {
      final file = File('${tmp.path}/12/1/1.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([0, 1, 2, 3]);
      final h = await AwsTerrainTiles(cacheDir: tmp)
          .heights(const TileId(12, 1, 1));
      expect(h, isNull);
      expect(file.existsSync(), isFalse);
    });
  });

  group('the ground under a hike', () {
    final trail = [believableHike(everySec: 10)];

    test(
      'with every tile, it is real terrain over a square of country',
      () async {
        final source = FakeTerrain();
        final ground = await loadHikeGround(source, trail, cols: 40);
        expect(ground.terrain, isNotNull);
        expect(source.requests, inInclusiveRange(1, 9));
        expect(ground.area.widthM, closeTo(ground.area.heightM, 1));
        // The hike spans about 2.8 km; the box is wider than the walk.
        expect(ground.area.widthM, greaterThan(3000));
        final top = ground.terrain!.heightAtLocal(
          ground.terrain!.toLocal(hillTop).x,
          ground.terrain!.toLocal(hillTop).y,
        );
        expect(top, closeTo(hillHeightM(hillTop.lat, hillTop.lng), 15));
      },
    );

    test('a short walk still gets a kilometre and a half of country', () async {
      final short = [believableHike(everySec: 10).take(20).toList()];
      final ground = await loadHikeGround(FakeTerrain(), short, cols: 20);
      expect(ground.area.widthM, greaterThanOrEqualTo(1499));
    });

    test(
      'offline it has the box and no terrain: never half a mountain',
      () async {
        final source = FakeTerrain(online: false);
        final ground = await loadHikeGround(source, trail, cols: 40);
        expect(ground.terrain, isNull);
        expect(ground.area.widthM, greaterThan(3000));
      },
    );

    test('one missing tile is as good as none', () async {
      final ground = await loadHikeGround(_Patchy(), trail, cols: 40);
      expect(ground.terrain, isNull);
    });
  });
}

/// Every tile but the first.
class _Patchy implements TerrainTileSource {
  final _real = FakeTerrain();
  bool _first = true;

  @override
  Future<Float32List?> heights(TileId t) {
    if (_first) {
      _first = false;
      return Future.value();
    }
    return _real.heights(t);
  }
}
