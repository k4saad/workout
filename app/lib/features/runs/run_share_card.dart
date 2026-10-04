import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ui/ui.dart';
import '../../data/db/database.dart' show Run;
import '../../data/db/tables.dart' show RunKind;
import '../../domain/run/run.dart';
import 'run_summary.dart' show runTitle;

/// The card's size in logical pixels; captured at [shareScale] it is a
/// 1080 × 1350 PNG — the 4:5 a feed shows whole.
const shareCardSize = Size(360, 450);
const shareScale = 3.0;

/// How much of each end of the route a shared card leaves off.
const shareHideM = 200.0;

/// A run as a picture to send: the route as a line on dark — no map, no
/// coordinates, the first and last 200 m cut unless he says otherwise —
/// and the three numbers.
///
/// A GPS trail is a home address. This is the one way it leaves the phone
/// outside a backup, and only when he taps Share (CLAUDE.md).
class RunShareCard extends StatelessWidget {
  const RunShareCard({
    super.key,
    required this.run,
    required this.route,
    this.hidesEnds = true,
    this.exerciseName,
  });

  final Run run;

  /// What of the route to draw — already trimmed. Empty draws the numbers
  /// large instead.
  final List<List<GeoPoint>> route;
  final bool hidesEnds;
  final String? exerciseName;

  @override
  Widget build(BuildContext context) {
    final started = DateTime.fromMillisecondsSinceEpoch(run.startedAtMs);
    final pace = run.distanceM < 10 || run.movingMs <= 0
        ? null
        : (run.movingMs / 1000) / (run.distanceM / 1000);
    final km = formatKm(run.distanceM.toDouble());
    final hike = run.kind == RunKind.hike;
    final climb = '${(run.elevGainM ?? 0).round()}';
    final speed = run.movingMs <= 0
        ? '–'
        : (run.distanceM / (run.movingMs / 1000) * 3.6).toStringAsFixed(1);
    final showRoute = route.any((s) => s.length > 1);
    const white = AppTheme.text;
    const dim = AppTheme.textDim;

    // A picture, not a page: the same 1080 x 1350 whatever text size the
    // phone is set to, so nothing reflows or runs off it.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: shareCardSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A070C), AppTheme.bg, Color(0xFF101013)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppTheme.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KELLER TWELVE',
                      style: AppTheme.overline.copyWith(color: white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEE d MMM yyyy')
                            .format(started)
                            .toUpperCase(),
                        style: AppTheme.overline,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  runTitle(started, kind: run.kind),
                  style: const TextStyle(
                    color: white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (exerciseName != null)
                  Text(
                    exerciseName!,
                    style: const TextStyle(color: dim, fontSize: 14),
                  ),
                Expanded(
                  child: showRoute
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: RouteLinePainter(
                              route,
                              markEnds: !hidesEnds,
                            ),
                          ),
                        )
                      : Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(km, style: AppTheme.numeric(104)),
                                const SizedBox(width: 6),
                                Text(
                                  'km',
                                  style: AppTheme.numeric(30, color: dim),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                Row(
                  children: [
                    if (showRoute)
                      Expanded(child: _Figure('Distance', km, 'km'))
                    else
                      Expanded(child: _Figure('Climb', climb, 'm')),
                    Expanded(child: _Figure('Time', formatClock(run.movingMs))),
                    // A hike is counted by its climb; a run by its pace.
                    if (hike && showRoute)
                      Expanded(child: _Figure('Climb', climb, 'm'))
                    else if (hike)
                      Expanded(child: _Figure('Speed', speed, 'km/h'))
                    else
                      Expanded(child: _Figure('Pace', formatPace(pace), '/km')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, [this.unit]);

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: AppTheme.overline),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTheme.numeric(30)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!, style: AppTheme.numeric(15, color: AppTheme.textDim)),
            ],
          ],
        ),
      ),
    ],
  );
}

/// A route drawn to fit a box, true to its shape: a soft glow, then the
/// line. With [markEnds], the start (white) and the finish (crimson).
class RouteLinePainter extends CustomPainter {
  RouteLinePainter(this.route, {this.markEnds = true, this.fine = false});

  final List<List<GeoPoint>> route;
  final bool markEnds;

  /// Thinner strokes, for a thumbnail.
  final bool fine;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final s in route) ...s];
    if (pts.length < 2) return;
    var minLat = pts.first.lat, maxLat = minLat;
    var minLng = pts.first.lng, maxLng = minLng;
    for (final q in pts) {
      minLat = math.min(minLat, q.lat);
      maxLat = math.max(maxLat, q.lat);
      minLng = math.min(minLng, q.lng);
      maxLng = math.max(maxLng, q.lng);
    }
    // Longitude degrees shrink with latitude; scale so the shape is true.
    final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max(1e-9, (maxLng - minLng) * k);
    final h = math.max(1e-9, maxLat - minLat);
    final pad = fine ? 8.0 : 18.0;
    final s = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final ox = (size.width - w * s) / 2;
    final oy = (size.height - h * s) / 2;
    Offset o(GeoPoint q) =>
        Offset(ox + (q.lng - minLng) * k * s, oy + (maxLat - q.lat) * s);

    final glow = Paint()
      ..color = AppTheme.crimson.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = fine ? 5 : 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fine ? 4 : 7);
    final line = Paint()
      ..color = AppTheme.crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = fine ? 2 : 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final seg in route) {
      if (seg.length < 2) continue;
      final path = Path()..moveTo(o(seg.first).dx, o(seg.first).dy);
      for (final q in seg.skip(1)) {
        path.lineTo(o(q).dx, o(q).dy);
      }
      canvas
        ..drawPath(path, glow)
        ..drawPath(path, line);
    }
    if (markEnds) {
      final r = fine ? 4.0 : 6.0;
      canvas.drawCircle(o(pts.first), r, Paint()..color = AppTheme.text);
      canvas.drawCircle(
        o(pts.last),
        r,
        Paint()..color = AppTheme.crimsonBright,
      );
    }
  }

  @override
  bool shouldRepaint(RouteLinePainter old) =>
      old.route != route || old.markEnds != markEnds || old.fine != fine;
}

/// Renders [boundary] to a 1080 × 1350 PNG.
Future<List<int>> renderShareCard(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: shareScale);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Hands a finished PNG to the phone's share sheet. Replaceable in tests,
/// where there is no share sheet.
typedef ShareRunImage = Future<void> Function(File png, String title);

Future<void> _shareWithSheet(File png, String title) =>
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(png.path, mimeType: 'image/png')],
        subject: title,
      ),
    );

/// The share sheet: the card as it will be sent, the two privacy choices,
/// and Share.
Future<void> showRunShareSheet(
  BuildContext context, {
  required Run run,
  required RunTrack track,
  String? exerciseName,
  ShareRunImage share = _shareWithSheet,
}) => showAppSheet<void>(
  context,
  builder: (_) => _ShareSheet(
    run: run,
    track: track,
    exerciseName: exerciseName,
    share: share,
  ),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.run,
    required this.track,
    required this.share,
    this.exerciseName,
  });

  final Run run;
  final RunTrack track;
  final String? exerciseName;
  final ShareRunImage share;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _showRoute = true;
  bool _hideEnds = true;
  bool _busy = false;

  late final bool _hasTrail = widget.track.segments.any((s) => s.length > 1);
  late final _trimmed = privateRoute(widget.track.segments, hideM: shareHideM);
  late final _whole = privateRoute(widget.track.segments, hideM: 0);

  List<List<GeoPoint>> get _route =>
      !_showRoute || !_hasTrail ? const [] : (_hideEnds ? _trimmed : _whole);

  Future<void> _send() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await renderShareCard(boundary);
      final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'share'),
      );
      await dir.create(recursive: true);
      final file = File(
        p.join(dir.path, 'keller-${widget.run.kind.name}-${widget.run.id}.png'),
      );
      await file.writeAsBytes(png, flush: true);
      final started = DateTime.fromMillisecondsSinceEpoch(
        widget.run.startedAtMs,
      );
      await widget.share(file, runTitle(started, kind: widget.run.kind));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final previewH = math.min(420.0, MediaQuery.sizeOf(context).height * 0.45);
    final tooShort = _showRoute && _hideEnds && _hasTrail && _trimmed.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share this run', style: t.headlineSmall),
        Gap.m,
        Center(
          child: SizedBox(
            height: previewH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: FittedBox(
                child: RepaintBoundary(
                  key: _card,
                  child: RunShareCard(
                    run: widget.run,
                    route: _route,
                    hidesEnds: _hideEnds,
                    exerciseName: widget.exerciseName,
                  ),
                ),
              ),
            ),
          ),
        ),
        Gap.s,
        if (_hasTrail) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show the route'),
            subtitle: const Text('As a line — never on a map.'),
            value: _showRoute,
            onChanged: (v) => setState(() => _showRoute = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide the start and finish'),
            subtitle: Text(
              tooShort
                  ? 'Too short to show without them: the card shows the '
                        'numbers instead.'
                  : 'The first and last ${shareHideM.round()} m are left '
                        'off, so the card does not show where you live.',
            ),
            value: _hideEnds,
            onChanged: _showRoute ? (v) => setState(() => _hideEnds = v) : null,
          ),
        ],
        Gap.s,
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.ios_share),
          label: Text(_busy ? 'Making the image…' : 'Share image'),
        ),
      ],
    );
  }
}
