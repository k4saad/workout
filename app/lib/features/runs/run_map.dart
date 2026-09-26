import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/run/run.dart';
import 'map_style.dart';

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

/// The street, not the rooftops: close enough to see the turns, far enough
/// that the buildings are texture rather than detail.
const liveZoom = 16.0;

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// A stretch of trail in its pace colour: 1 the quickest, 0 the slowest.
typedef ShadedStretch = ({List<GeoPoint> points, double shade});

/// Slow to quick, in the one accent: deep crimson to bright crimson.
Color paceColour(double shade) => Color.lerp(
  const Color(0xFF5E0B1A),
  AppTheme.crimsonBright,
  shade.clamp(0.0, 1.0),
)!;

/// A run on the map: the trail (broken where it was paused), where it
/// started, where it ended or where he is now.
///
/// The tiles are quietened (map_style.dart) so the trail — glowing crimson
/// over a dark border — is the brightest thing on it. With no signal, or
/// tiles switched off, the trail still draws on plain dark.
class RunMap extends ConsumerStatefulWidget {
  const RunMap({
    super.key,
    required this.segments,
    this.fitTo,
    this.position,
    this.accuracyM,
    this.follow = false,
    this.showFinish = false,
    this.interactive = true,
    this.shaded,
    this.dot,
    this.fitPadding = const EdgeInsets.all(40),
  });

  /// The trail as it is drawn now — the whole of it, or the part revealed
  /// so far while it draws itself in.
  final List<List<GeoPoint>> segments;

  /// What the camera frames when it opens: the whole route, so it does not
  /// chase a line that is still being drawn. Defaults to [segments].
  final List<List<GeoPoint>>? fitTo;

  /// The live position; followed when [follow] is on.
  final GeoPoint? position;

  /// How sure the GPS is about [position]: drawn as a halo around it.
  final double? accuracyM;
  final bool follow;

  /// Mark the last point as the finish (a finished run).
  final bool showFinish;
  final bool interactive;

  /// Draw the trail in pace colours instead of plain crimson.
  final List<ShadedStretch>? shaded;

  /// The replay dot.
  final GeoPoint? dot;

  /// Room left around the route when the camera frames it: full screen
  /// keeps it clear of the title and the buttons over the map.
  final EdgeInsets fitPadding;

  @override
  ConsumerState<RunMap> createState() => _RunMapState();
}

class _RunMapState extends ConsumerState<RunMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RunMap old) {
    super.didUpdateWidget(old);
    final p = widget.position;
    if (_ready && widget.follow && p != null && p != old.position) {
      // Opened before the first fix, the map sits at city zoom; the first
      // real position brings it down to the street.
      final z = _controller.camera.zoom;
      _controller.move(_ll(p), z < 14 ? liveZoom : z);
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
    final drawn = widget.segments;
    final frame = [for (final s in widget.fitTo ?? drawn) ...s];
    final centre = widget.position ?? (frame.isEmpty ? null : frame.last);
    final fit = !widget.follow && frame.length > 1;

    final all = [for (final s in drawn) ...s];
    final start = frame.isEmpty ? null : frame.first;
    final end = widget.showFinish && all.length > 1 ? all.last : null;
    final pos = widget.position;
    final acc = widget.accuracyM;

    return ColoredBox(
      color: AppTheme.surfaceLow,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          backgroundColor: AppTheme.surfaceLow,
          initialCenter: centre == null
              ? const LatLng(51.9607, 7.6261) // Münster, until a fix arrives
              : _ll(centre),
          initialZoom: centre == null ? 12 : liveZoom,
          initialCameraFit: fit
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints([
                    for (final p in frame) _ll(p),
                  ]),
                  padding: widget.fitPadding,
                  maxZoom: 17,
                )
              : null,
          maxZoom: 18,
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
              tileBuilder: quietTileBuilder,
            ),
          if (pos != null && acc != null && acc > 8 && !widget.showFinish)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _ll(pos),
                  radius: acc,
                  useRadiusInMeter: true,
                  color: AppTheme.crimson.withValues(alpha: 0.10),
                  borderColor: AppTheme.crimson.withValues(alpha: 0.35),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
          PolylineLayer(
            polylines: [
              // The glow: wide, soft, underneath everything.
              for (final s in drawn)
                if (s.length > 1)
                  Polyline(
                    points: [for (final p in s) _ll(p)],
                    strokeWidth: 16,
                    color: AppTheme.crimson.withValues(alpha: 0.18),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
              // In pace colours: one dark edge under the whole trail, then
              // the stretches on it without edges of their own, so the line
              // runs on without a notch where one colour meets the next.
              if (widget.shaded != null)
                for (final s in drawn)
                  if (s.length > 1)
                    Polyline(
                      points: [for (final p in s) _ll(p)],
                      strokeWidth: 9,
                      color: const Color(0xE6000000),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
              if (widget.shaded case final shaded?)
                for (final st in shaded)
                  if (st.points.length > 1)
                    Polyline(
                      points: [for (final p in st.points) _ll(p)],
                      strokeWidth: 6,
                      color: paceColour(st.shade),
                      strokeCap: StrokeCap.butt,
                      strokeJoin: StrokeJoin.round,
                    ),
              if (widget.shaded == null)
                for (final s in drawn)
                  if (s.length > 1)
                    Polyline(
                      points: [for (final p in s) _ll(p)],
                      strokeWidth: 6,
                      color: AppTheme.crimson,
                      borderStrokeWidth: 1.5,
                      borderColor: const Color(0xE6000000),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
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
              if (pos != null && !widget.showFinish)
                Marker(
                  point: _ll(pos),
                  width: 48,
                  height: 48,
                  child: const _Here(),
                ),
              if (widget.dot case final d?)
                Marker(
                  point: _ll(d),
                  width: 24,
                  height: 24,
                  child: const _ReplayDot(),
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

/// You are here: a white dot in a crimson ring, with a ring that pulses out
/// from it so it can be found at a glance on a moving screen.
class _Here extends StatefulWidget {
  const _Here();

  @override
  State<_Here> createState() => _HereState();
}

class _HereState extends State<_Here> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You are here',
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final v = Curves.easeOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 + 30 * v,
              height: 18 + 30 * v,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.crimson.withValues(alpha: 0.35 * (1 - v)),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.text,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.crimson, width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 6),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ReplayDot extends StatelessWidget {
  const _ReplayDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.text,
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.crimsonBright, width: 5),
      boxShadow: [
        BoxShadow(
          color: AppTheme.crimson.withValues(alpha: 0.7),
          blurRadius: 12,
        ),
      ],
    ),
  );
}
