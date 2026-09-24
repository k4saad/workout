import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/run/run.dart';

/// The OpenStreetMap tile server, and the only host the app ever asks for
/// anything. The OSM tile policy, kept:
///
///  * a real User-Agent (flutter_map sends the app id below);
///  * visible attribution, tappable to the copyright page;
///  * no bulk download or prefetch: only the tiles on screen, as you look;
///  * a cache, bounded, in app-private storage, so a route run twice does
///    not fetch its tiles twice.
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmCopyright = 'https://www.openstreetmap.org/copyright';
const _appId = 'de.saad.kellertwelve';

/// 80 MB: a few months of the same neighbourhood at every zoom.
const _tileCacheBytes = 80 * 1024 * 1024;

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// A run on the map: the trail (broken where it was paused), where it
/// started, where it ended or where he is now.
///
/// Dark tiles, so the crimson trail is the brightest thing on it. With no
/// signal, or tiles switched off, the trail still draws on plain dark.
class RunMap extends ConsumerStatefulWidget {
  const RunMap({
    super.key,
    required this.segments,
    this.position,
    this.follow = false,
    this.showFinish = false,
    this.interactive = true,
  });

  final List<List<GeoPoint>> segments;

  /// The live position; followed when [follow] is on.
  final GeoPoint? position;
  final bool follow;

  /// Mark the last point as the finish (a finished run).
  final bool showFinish;
  final bool interactive;

  @override
  ConsumerState<RunMap> createState() => _RunMapState();
}

class _RunMapState extends ConsumerState<RunMap> {
  final _controller = MapController();
  bool _ready = false;

  List<GeoPoint> get _all => [for (final s in widget.segments) ...s];

  @override
  void didUpdateWidget(RunMap old) {
    super.didUpdateWidget(old);
    final p = widget.position;
    if (_ready && widget.follow && p != null && p != old.position) {
      // Opened before the first fix, the map sits at city zoom over
      // Münster; the first real position brings it down to the street.
      final z = _controller.camera.zoom;
      _controller.move(_ll(p), z < 15 ? 16.5 : z);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(mapTilesEnabledProvider);
    final all = _all;
    final centre = widget.position ?? (all.isEmpty ? null : all.last);
    final fit = !widget.follow && all.length > 1;

    final start = all.isEmpty ? null : all.first;
    final end = widget.showFinish && all.length > 1 ? all.last : null;

    return ColoredBox(
      color: AppTheme.surfaceLow,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          backgroundColor: AppTheme.surfaceLow,
          initialCenter: centre == null
              ? const LatLng(51.9607, 7.6261) // Münster, until a fix arrives
              : _ll(centre),
          initialZoom: centre == null ? 12 : 16.5,
          initialCameraFit: fit
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints([
                    for (final p in all) _ll(p),
                  ]),
                  padding: const EdgeInsets.all(36),
                  maxZoom: 17,
                )
              : null,
          maxZoom: 19,
          minZoom: 3,
          interactionOptions: InteractionOptions(
            flags: widget.interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
          onMapReady: () => _ready = true,
        ),
        children: [
          if (tiles)
            TileLayer(
              urlTemplate: _osmTiles,
              userAgentPackageName: _appId,
              maxNativeZoom: 19,
              tileProvider: NetworkTileProvider(
                cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                  maxCacheSize: _tileCacheBytes,
                ),
                silenceExceptions: true,
              ),
              tileBuilder: darkModeTileBuilder,
            ),
          PolylineLayer(
            polylines: [
              for (final s in widget.segments)
                if (s.length > 1)
                  Polyline(
                    points: [for (final p in s) _ll(p)],
                    strokeWidth: 5,
                    color: AppTheme.crimson,
                    borderStrokeWidth: 2,
                    borderColor: const Color(0xCC000000),
                  ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (start != null)
                Marker(
                  point: _ll(start),
                  width: 26,
                  height: 26,
                  child: const _Pin(
                    glyph: Icons.play_arrow_rounded,
                    fill: AppTheme.text,
                    ink: AppTheme.bg,
                    label: 'Start',
                  ),
                ),
              if (end != null)
                Marker(
                  point: _ll(end),
                  width: 26,
                  height: 26,
                  child: const _Pin(
                    glyph: Icons.flag_rounded,
                    fill: AppTheme.crimson,
                    ink: AppTheme.text,
                    label: 'Finish',
                  ),
                ),
              if (widget.position != null && !widget.showFinish)
                Marker(
                  point: _ll(widget.position!),
                  width: 22,
                  height: 22,
                  child: const _Here(),
                ),
            ],
          ),
          if (tiles)
            SimpleAttributionWidget(
              source: const Text('OpenStreetMap contributors'),
              backgroundColor: const Color(0xAA0A0A0C),
              onTap: () => launchUrl(
                Uri.parse(_osmCopyright),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

/// Start and finish: a glyph in a disc, so neither rests on colour.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.glyph,
    required this.fill,
    required this.ink,
    required this.label,
  });

  final IconData glyph;
  final Color fill;
  final Color ink;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.bg, width: 2),
      ),
      child: Icon(glyph, size: 16, color: ink),
    ),
  );
}

/// You are here.
class _Here extends StatelessWidget {
  const _Here();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You are here',
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.text,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.crimson, width: 4),
      ),
    ),
  );
}
