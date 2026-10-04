import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../domain/run/run.dart';
import '../domain/terrain/terrain.dart';

/// Elevation tiles, by id: heights, or null when the tile cannot be had.
abstract interface class TerrainTileSource {
  Future<Float32List?> heights(TileId tile);
}

/// AWS Terrain Tiles — Mapzen's open terrain on the AWS Open Data registry:
/// terrarium PNGs, no key, no account.
///
/// What leaves the phone is one GET per tile, naming the tile (an area some
/// kilometres across) and nothing else: no trail, no coordinate, no
/// identifier, no body. Saad approved fetching open map and elevation data
/// on 2026-10-04 (CLAUDE.md); test/privacy_audit_test.dart holds this file to
/// GET requests on this one host.
///
/// Tiles are kept in the app's cache folder: re-downloadable, so Android
/// may clear them, and never in a backup.
class AwsTerrainTiles implements TerrainTileSource {
  AwsTerrainTiles({this.cacheDir});

  /// Where tiles are kept: the app's cache folder when null.
  final Directory? cacheDir;
  Directory? _dir;

  static Uri urlFor(TileId t) => Uri.parse(
    'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/'
    '${t.z}/${t.x}/${t.y}.png',
  );

  Future<Directory> _folder() async => _dir ??=
      cacheDir ??
      Directory('${(await getApplicationCacheDirectory()).path}/terrain');

  @override
  Future<Float32List?> heights(TileId tile) async {
    try {
      final file = File(
        '${(await _folder()).path}/${tile.z}/${tile.x}/${tile.y}.png',
      );
      Uint8List? png;
      if (file.existsSync()) {
        png = await file.readAsBytes();
      } else {
        png = await _download(tile);
        if (png == null) return null;
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png, flush: true);
      }
      final bytes = png;
      final heights = await Isolate.run(() => decodeTerrariumPng(bytes));
      // A corrupt cached tile is thrown away, to be fetched again next time.
      if (heights == null && file.existsSync()) await file.delete();
      return heights;
    } on Object {
      return null;
    }
  }

  static Future<Uint8List?> _download(TileId tile) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = null;
    try {
      final request = await client.getUrl(urlFor(tile));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final out = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        out.add(chunk);
      }
      return out.takeBytes();
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// A terrarium PNG's heights, row-major from the north-west corner; null if
/// it is not a 256-pixel square tile.
Float32List? decodeTerrariumPng(Uint8List png) {
  final image = img.decodePng(png);
  if (image == null || image.width != 256 || image.height != 256) return null;
  final out = Float32List(256 * 256);
  var i = 0;
  for (final p in image) {
    out[i++] = terrariumMetres(p.r.toInt(), p.g.toInt(), p.b.toInt());
  }
  return out;
}

/// The ground a hike crossed, and the box drawn around it.
class HikeGround {
  const HikeGround({required this.area, this.terrain});

  final GeoBounds area;

  /// Real terrain; null when it could not be had (offline), and the scene
  /// stands the trail on the phone's own heights instead.
  final HeightGrid? terrain;
}

/// The square of country around [trail], with its terrain when every tile
/// it needs can be had. At the sharpest zoom that keeps to [maxTiles].
Future<HikeGround> loadHikeGround(
  TerrainTileSource source,
  List<List<RunFix>> trail, {
  int maxTiles = 9,
  int cols = 90,
}) async {
  final area = GeoBounds.around([
    for (final s in trail)
      for (final f in s) f.point,
  ]).squaredAndPadded(0.3, minSideM: 1500);
  final z = zoomFor(area, maxTiles: maxTiles);
  final ids = tilesCovering(area, z);
  final got = await Future.wait(ids.map(source.heights));
  if (got.any((h) => h == null)) return HikeGround(area: area);
  final tiles = {for (var i = 0; i < ids.length; i++) ids[i]: got[i]!};
  return HikeGround(
    area: area,
    terrain: HeightGrid.sample(
      TileHeights(z, tiles),
      area,
      cols: cols,
      rows: cols,
    ),
  );
}
