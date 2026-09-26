import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../domain/run/run.dart';
import 'run_map.dart';

/// The top of a finished run: the route drawing itself in, then the map to
/// play with — coloured by pace on request, and a replay that runs a dot
/// along it with the distance and time ticking.
///
/// On the run's page it is a card, and a tap opens it full screen
/// ([RouteFullScreen]); there, the same stage fills the phone and the map
/// can be pinched and dragged.
class RouteHero extends StatefulWidget {
  const RouteHero({
    super.key,
    required this.track,
    this.height = 300,
    this.fullScreen = false,
    this.onExpand,
    this.onShare,
    this.overlayInsets = EdgeInsets.zero,
  });

  final RunTrack track;

  /// The card's height; ignored full screen, where it fills its parent.
  final double height;
  final bool fullScreen;

  /// Opens the full-screen view. Null on the full-screen view itself.
  final VoidCallback? onExpand;

  /// Opens the share card, when the page offers it.
  final VoidCallback? onShare;

  /// Room the overlays keep clear of — the status bar, the title and the
  /// gesture bar on the full-screen view.
  final EdgeInsets overlayInsets;

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
    duration: Duration(milliseconds: widget.fullScreen ? 2400 : 1600),
  );

  /// Long enough to follow, never a chore: 6 s for a short run, 14 s long —
  /// half as long again full screen, where there is time to watch it.
  late final AnimationController _replay =
      AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds:
              ((_path.lengthM * 2.2).clamp(6000, 14000) *
                      (widget.fullScreen ? 1.5 : 1))
                  .round(),
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

  /// Draws the route in again — full screen, where watching it is the point.
  void _redraw() {
    _replay
      ..stop()
      ..value = 0;
    setState(() {});
    if (AppMotion.reduced(context)) return;
    _draw.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final full = widget.fullScreen;
    final inset = widget.overlayInsets;
    final stage = AnimatedBuilder(
      animation: Listenable.merge([_draw, _replay]),
      builder: (context, _) {
        final drawn = _draw.isCompleted
            ? _whole
            : _path.upTo(Curves.easeInOutCubic.transform(_draw.value));
        final at = _replaying ? _path.at(_replay.value) : null;
        return Stack(
          children: [
            Positioned.fill(
              // On the card it is not pannable: it sits in a scrolling page,
              // and a drag over it must scroll the page — a tap opens it
              // full screen instead. Full screen, it pans and zooms.
              child: RunMap(
                interactive: full,
                segments: drawn,
                fitTo: _whole,
                showFinish: _draw.isCompleted,
                shaded: _byPace && _draw.isCompleted ? _shaded : null,
                dot: at?.point,
                fitPadding: full
                    ? EdgeInsets.fromLTRB(
                        36,
                        inset.top + 24,
                        36,
                        inset.bottom + 96,
                      )
                    : const EdgeInsets.all(40),
              ),
            ),
            if (!full && widget.onExpand != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onExpand,
                ),
              ),
            if (at != null)
              Positioned(
                left: 12,
                top: inset.top + 12,
                child: _Chip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${formatKm(at.distanceM)} km',
                        style: AppTheme.numeric(full ? 26 : 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatClock(at.elapsedMs),
                        style: AppTheme.numeric(
                          full ? 26 : 18,
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
                // Full screen has four buttons along the bottom: the key
                // sits above them rather than running into them.
                bottom: inset.bottom + (full ? 90 : 30),
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
                bottom: inset.bottom + (full ? 30 : 26),
                child: Row(
                  children: [
                    if (full) ...[
                      _RoundAction(
                        icon: Icons.replay,
                        tooltip: 'Draw it again',
                        onTap: _redraw,
                      ),
                      const SizedBox(width: 8),
                    ],
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
                    if (!full && widget.onExpand != null) ...[
                      const SizedBox(width: 8),
                      _RoundAction(
                        icon: Icons.open_in_full,
                        tooltip: 'Full screen',
                        onTap: widget.onExpand!,
                      ),
                    ],
                    if (full && widget.onShare != null) ...[
                      const SizedBox(width: 8),
                      _RoundAction(
                        icon: Icons.ios_share,
                        tooltip: 'Share as an image',
                        onTap: widget.onShare!,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (full) return stage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: SizedBox(height: widget.height, child: stage),
    );
  }
}

/// The route, and nothing else on the phone: pinch, drag, watch it draw in
/// and replay. Pushed over the tab bar — the way to look at a run, not a
/// page to do anything else from.
class RouteFullScreen extends StatelessWidget {
  const RouteFullScreen({
    super.key,
    required this.track,
    required this.title,
    required this.subtitle,
    this.onShare,
  });

  final RunTrack track;
  final String title;
  final String subtitle;
  final VoidCallback? onShare;

  /// Opens it above the tab bar, fading and settling in.
  static Future<void> open(
    BuildContext context, {
    required RunTrack track,
    required String title,
    required String subtitle,
    VoidCallback? onShare,
  }) {
    final reduced = AppMotion.reduced(context);
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        transitionDuration: reduced ? Duration.zero : AppMotion.medium,
        reverseTransitionDuration: reduced ? Duration.zero : AppMotion.fast,
        pageBuilder: (_, _, _) => RouteFullScreen(
          track: track,
          title: title,
          subtitle: subtitle,
          onShare: onShare,
        ),
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
            child: RouteHero(
              track: track,
              fullScreen: true,
              onShare: onShare,
              overlayInsets: EdgeInsets.only(
                top: pad.top + bar,
                bottom: pad.bottom,
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
                    Tooltip(
                      message: 'Close',
                      child: Material(
                        color: const Color(0xE60A0A0C),
                        shape: const CircleBorder(
                          side: BorderSide(color: AppTheme.outline),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.close, color: AppTheme.text),
                          ),
                        ),
                      ),
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
