import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/ui/ui.dart';
import '../../domain/terrain/terrain.dart';

/// The land in the app's own greys, the trail in its one accent.
final terrainStyle = TerrainStyle(
  low: 0xFF2C2C34,
  high: 0xFFEDEDF3,
  fog: AppTheme.bg.toARGB32(),
  wall: AppTheme.surfaceHigher.toARGB32(),
  curtain: AppTheme.crimson.withValues(alpha: 0.42).toARGB32(),
);

/// Where the eye is, shared by the painter and the gestures.
class _View extends ChangeNotifier {
  _View({required this.homeElevation, required this.homeZoom})
    : elevation = homeElevation,
      zoom = homeZoom;

  /// Where it starts, and where a double tap puts it back.
  final double homeElevation;
  final double homeZoom;

  double azimuth = 0.6;
  double elevation;
  double zoom;

  void turn(double dAzimuth, [double dElevation = 0]) {
    azimuth += dAzimuth;
    elevation = (elevation + dElevation).clamp(0.22, 1.35);
    notifyListeners();
  }

  void zoomTo(double z) {
    zoom = z.clamp(0.75, 3.2);
    notifyListeners();
  }

  void reset() {
    azimuth = 0.6;
    elevation = homeElevation;
    zoom = homeZoom;
    notifyListeners();
  }
}

/// A hike's country in 3D: the land lit from the north-west, the trail
/// lying on it and drawing itself in, the whole thing turning slowly until
/// it is touched.
///
/// In a card, a sideways drag turns it and the page still scrolls; full
/// screen, one finger turns and tilts it and two zoom.
class TerrainView extends StatefulWidget {
  const TerrainView({
    super.key,
    required this.scene,
    this.fullScreen = false,
    this.onExpand,
    this.insets = EdgeInsets.zero,
  });

  final TerrainScene scene;
  final bool fullScreen;

  /// Opens it full screen; offered as a button in the card.
  final VoidCallback? onExpand;

  /// Room left for whatever sits over the edges (an app bar, a bottom bar).
  final EdgeInsets insets;

  @override
  State<TerrainView> createState() => _TerrainViewState();
}

class _TerrainViewState extends State<TerrainView>
    with TickerProviderStateMixin {
  // In a card, closer and lower: the land fills it and the hills stand up.
  late final _view = widget.fullScreen
      ? _View(homeElevation: 0.55, homeZoom: 1.55)
      : _View(homeElevation: 0.48, homeZoom: 1.3);
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final Ticker _orbit = createTicker(_onOrbit);
  Duration _last = Duration.zero;
  bool _orbiting = true;
  bool _reduced = false;
  bool _started = false;
  Timer? _idle;
  double _zoomAtStart = 1;

  /// A full turn in this long: slow enough to read, quick enough to see.
  static const _turnSeconds = 48.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    if (_started) return;
    _started = true;
    if (_reduced) {
      _reveal.value = 1;
      _orbiting = false;
    } else {
      unawaited(_reveal.forward());
      unawaited(_orbit.start());
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _orbit.dispose();
    _reveal.dispose();
    _view.dispose();
    super.dispose();
  }

  void _onOrbit(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_orbiting || dt <= 0 || dt > 0.25) return;
    _view.turn(dt * 2 * math.pi / _turnSeconds);
  }

  /// A finger on it stops the fly-around; left alone, it starts again.
  void _touched() {
    _orbiting = false;
    _idle?.cancel();
    if (_reduced) return;
    _idle = Timer(const Duration(seconds: 8), () => _orbiting = true);
  }

  void _replay() {
    _view.reset();
    if (_reduced) return;
    _reveal
      ..value = 0
      ..forward();
    _orbiting = true;
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final painter = CustomPaint(
      size: Size.infinite,
      painter: _TerrainPainter(scene: scene, view: _view, reveal: _reveal),
    );
    final gestures = widget.fullScreen
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _replay,
            onScaleStart: (_) {
              _touched();
              _zoomAtStart = _view.zoom;
            },
            onScaleUpdate: (d) {
              _touched();
              _view.turn(
                -d.focalPointDelta.dx * 0.008,
                d.focalPointDelta.dy * 0.005,
              );
              if (d.pointerCount > 1) _view.zoomTo(_zoomAtStart * d.scale);
            },
            child: painter,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _replay,
            onHorizontalDragStart: (_) => _touched(),
            onHorizontalDragUpdate: (d) {
              _touched();
              _view.turn(-d.delta.dx * 0.008);
            },
            child: painter,
          );

    final insets = widget.insets;
    return Semantics(
      image: true,
      label: scene.hasTerrain
          ? 'The hike in 3D on the terrain it crossed. '
                'Drag to turn it, double tap to replay.'
          : 'The hike in 3D at the heights the phone recorded. '
                'Drag to turn it, double tap to replay.',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17171D), AppTheme.bg],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: gestures),
            Positioned(
              left: 12,
              right: widget.onExpand == null ? 12 : 68,
              top: insets.top + 12,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Pill(
                  icon: scene.hasTerrain
                      ? Icons.terrain_outlined
                      : Icons.cloud_off_outlined,
                  text: scene.hasTerrain
                      ? '3D terrain'
                      : 'GPS heights · offline',
                ),
              ),
            ),
            if (widget.onExpand != null)
              Positioned(
                right: 8,
                top: insets.top + 8,
                child: _Round(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Full screen 3D',
                  onTap: widget.onExpand!,
                ),
              ),
            // Along the bottom: the compass, the chips (wrapping onto a
            // second line at a large text size), and the attribution in what
            // room is left. Nothing runs under anything.
            Positioned(
              left: 12,
              right: 12,
              bottom: insets.bottom + 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBuilder(
                    animation: _view,
                    builder: (_, _) => _Compass(azimuth: _view.azimuth),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (scene.exaggeration > 1.05)
                          _Pill(
                            text:
                                'Heights ×'
                                '${scene.exaggeration.toStringAsFixed(1)}',
                          ),
                        if (widget.fullScreen && scene.contourIntervalM != null)
                          _Pill(
                            text:
                                'Lines every '
                                '${scene.contourIntervalM!.round()} m',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: scene.hasTerrain
                        ? Text(
                            'Terrain: Mapzen · AWS Open Data',
                            textAlign: TextAlign.end,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppTheme.textFaint),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({
    required this.scene,
    required this.view,
    required this.reveal,
  }) : super(repaint: Listenable.merge([view, reveal]));

  final TerrainScene scene;
  final _View view;
  final Animation<double> reveal;

  static Path _path(Float32List xy) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final camera = scene.fit(
      azimuth: view.azimuth,
      elevation: view.elevation,
      zoom: view.zoom,
    );
    final t = Curves.easeInOutCubic.transform(reveal.value);
    final frame = scene.frame(
      Projector(camera, size.width, size.height),
      reveal: t,
    );

    if (frame.vertexCount > 0) {
      final vertices = ui.Vertices.raw(
        VertexMode.triangles,
        Float32List.sublistView(frame.positions, 0, frame.vertexCount * 2),
        colors: Int32List.sublistView(frame.colours, 0, frame.vertexCount),
      );
      // dst: the vertices' own colours, not the paint's.
      canvas.drawVertices(vertices, BlendMode.dst, Paint());
      vertices.dispose();
    }

    // Behind a hill: still there, faint.
    final hidden = Paint()
      ..color = AppTheme.crimson.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = AppTheme.crimson.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()
      ..color = AppTheme.crimsonBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final run in frame.trail) {
      if (!run.visible) canvas.drawPath(_path(run.xy), hidden);
    }
    for (final run in frame.trail) {
      if (!run.visible) continue;
      final p = _path(run.xy);
      canvas
        ..drawPath(p, glow)
        ..drawPath(p, core)
        ..drawPath(p, shine);
    }

    final start = frame.start;
    if (start != null) {
      final c = Offset(start.x, start.y);
      canvas
        ..drawCircle(c, 5.5, Paint()..color = AppTheme.bg)
        ..drawCircle(
          c,
          5.5,
          Paint()
            ..color = AppTheme.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
    final head = frame.head;
    if (head != null) {
      final c = Offset(head.x, head.y);
      canvas
        ..drawCircle(
          c,
          t < 1 ? 11 : 8,
          Paint()
            ..color = AppTheme.crimsonBright.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        )
        ..drawCircle(c, 5.5, Paint()..color = AppTheme.crimsonBright)
        ..drawCircle(
          c,
          5.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
    }
  }

  @override
  bool shouldRepaint(_TerrainPainter old) => old.scene != scene;
}

/// Where north is, as the model turns.
class _Compass extends StatelessWidget {
  const _Compass({required this.azimuth});

  final double azimuth;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: const Color(0xD90A0A0C),
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.outline),
    ),
    child: Transform.rotate(
      angle: -azimuth,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.navigation_rounded, size: 13, color: AppTheme.crimson),
          Text(
            'N',
            style: TextStyle(
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xD90A0A0C),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.outlineSoft),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppTheme.textDim),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppTheme.text),
          ),
        ),
      ],
    ),
  );
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xE60A0A0C),
      shape: const CircleBorder(side: BorderSide(color: AppTheme.outline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppTheme.text),
        ),
      ),
    ),
  );
}

/// The model filling the screen, above the tab bar: room to turn it, tilt
/// it and zoom in on the climb.
class TerrainFullScreen extends StatelessWidget {
  const TerrainFullScreen({
    super.key,
    required this.scene,
    required this.title,
    required this.subtitle,
  });

  final TerrainScene scene;
  final String title;
  final String subtitle;

  static Future<void> open(
    BuildContext context, {
    required TerrainScene scene,
    required String title,
    required String subtitle,
  }) {
    final reduced = AppMotion.reduced(context);
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        transitionDuration: reduced ? Duration.zero : AppMotion.medium,
        reverseTransitionDuration: reduced ? Duration.zero : AppMotion.fast,
        pageBuilder: (_, _, _) =>
            TerrainFullScreen(scene: scene, title: title, subtitle: subtitle),
        transitionsBuilder: (_, a, _, child) {
          final curved = CurvedAnimation(parent: a, curve: AppMotion.curve);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = MediaQuery.paddingOf(context);
    const bar = 64.0;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: TerrainView(
              scene: scene,
              fullScreen: true,
              insets: EdgeInsets.only(
                top: pad.top + bar,
                bottom: pad.bottom + 8,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE60A0A0C), Color(0x000A0A0C)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, pad.top + 4, 16, 20),
                child: Row(
                  children: [
                    _Round(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Gap.m,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: t.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: t.bodySmall?.copyWith(
                              color: AppTheme.textDim,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
