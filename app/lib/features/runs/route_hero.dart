import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../domain/run/run.dart';
import 'run_map.dart';

/// The top of a finished run: the route drawing itself in, then the map to
/// play with — coloured by pace on request, and a replay that runs a dot
/// along it with the distance and time ticking.
class RouteHero extends StatefulWidget {
  const RouteHero({super.key, required this.track, this.height = 300});

  final RunTrack track;
  final double height;

  @override
  State<RouteHero> createState() => _RouteHeroState();
}

class _RouteHeroState extends State<RouteHero> with TickerProviderStateMixin {
  late final RoutePath _path = RoutePath(widget.track.segments);
  late final List<List<GeoPoint>> _whole = [
    for (final s in widget.track.segments) [for (final f in s) f.point],
  ];
  late final List<ShadedStretch> _shaded = () {
    final stretches = paceStretches(widget.track.segments);
    final shades = paceShades(stretches);
    return [
      for (var i = 0; i < stretches.length; i++)
        (points: stretches[i].points, shade: shades[i]),
    ];
  }();

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Long enough to follow, never a chore: 6 s for a short run, 14 s long.
  late final AnimationController _replay =
      AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: (_path.lengthM * 2.2).clamp(6000, 14000).round(),
        ),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() {});
      });

  bool _byPace = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draw.value == 0 && !_draw.isAnimating) {
      if (AppMotion.reduced(context)) {
        _draw.value = 1;
      } else {
        _draw.forward();
      }
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _replay.dispose();
    super.dispose();
  }

  bool get _replaying => _replay.isAnimating;

  void _toggleReplay() {
    setState(() {
      if (_replaying) {
        _replay.stop();
        _replay.value = 0;
      } else {
        _replay.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _replay]),
          builder: (context, _) {
            final drawn = _draw.isCompleted
                ? _whole
                : _path.upTo(Curves.easeInOutCubic.transform(_draw.value));
            final at = _replaying ? _path.at(_replay.value) : null;
            return Stack(
              children: [
                Positioned.fill(
                  // Not pannable: it sits in a scrolling page, and a drag
                  // over it must scroll the page, not slide the map.
                  child: RunMap(
                    interactive: false,
                    segments: drawn,
                    fitTo: _whole,
                    showFinish: _draw.isCompleted,
                    shaded: _byPace && _draw.isCompleted ? _shaded : null,
                    dot: at?.point,
                  ),
                ),
                if (at != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Chip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${formatKm(at.distanceM)} km',
                            style: AppTheme.numeric(18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatClock(at.elapsedMs),
                            style: AppTheme.numeric(
                              18,
                              color: AppTheme.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_byPace && _draw.isCompleted)
                  Positioned(
                    left: 12,
                    bottom: 30,
                    child: _Chip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('slower', style: t.labelSmall),
                          const SizedBox(width: 6),
                          Container(
                            width: 64,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [paceColour(0), paceColour(1)],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('quicker', style: t.labelSmall),
                        ],
                      ),
                    ),
                  ),
                if (_draw.isCompleted)
                  Positioned(
                    right: 10,
                    bottom: 26,
                    child: Row(
                      children: [
                        _RoundAction(
                          icon: Icons.speed_rounded,
                          tooltip: _byPace
                              ? 'Plain trail'
                              : 'Colour the route by pace',
                          selected: _byPace,
                          onTap: () => setState(() => _byPace = !_byPace),
                        ),
                        const SizedBox(width: 8),
                        _RoundAction(
                          icon: _replaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: _replaying ? 'Stop the replay' : 'Replay',
                          selected: _replaying,
                          onTap: _toggleReplay,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xD90A0A0C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.outlineSoft),
    ),
    child: child,
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: selected ? AppTheme.crimson : const Color(0xE60A0A0C),
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
