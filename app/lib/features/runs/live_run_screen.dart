import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/run_repository.dart';
import '../../data/run_tracker.dart';
import '../../domain/run/run.dart';
import 'hike_summary.dart';
import 'run_map.dart';
import 'run_share_card.dart';
import 'run_summary.dart';

/// What the live screen was opened for: a programme day's run, or a free
/// one; or a hike.
class RunLaunch {
  const RunLaunch({
    this.link,
    this.title = 'Free run',
    this.exerciseName,
    this.kind = RunKind.run,
  });

  /// A hike, free or from a programme day.
  const RunLaunch.hike({this.link, this.title = 'Hike', this.exerciseName})
    : kind = RunKind.hike;

  final RunLink? link;
  final String title;

  /// Run or hike: a hike is counted for its climb, not its pace.
  final RunKind kind;

  /// What a programme run is logged as, for the summary.
  final String? exerciseName;
}

/// The run, live. Full screen, outside the tab bar: in a pocket, at pace,
/// there is nothing else to tap.
///
/// Numbers big enough to read at arm's length while moving, one control at
/// a time, and a finish that has to be HELD so a sweaty thigh cannot end
/// the run. Leaving mid-run asks first.
class LiveRunScreen extends ConsumerStatefulWidget {
  const LiveRunScreen({super.key, this.launch = const RunLaunch()});

  final RunLaunch launch;

  @override
  ConsumerState<LiveRunScreen> createState() => _LiveRunScreenState();
}

class _LiveRunScreenState extends ConsumerState<LiveRunScreen> {
  late final RunTracker _tracker = RunTracker(
    repo: ref.read(runRepositoryProvider),
    source: ref.read(locationSourceProvider),
    link: widget.launch.link,
    kind: widget.launch.kind,
  );
  Timer? _tick;
  bool _follow = true;
  bool _busy = false;
  Run? _saved;
  RunTrack? _savedTrack;
  late final DateTime _openedAt = DateTime.now();

  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    unawaited(_tracker.prepare());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tracker.snapshot.isLive) _tracker.tick();
    });
    // Back from Settings with precise location on, or Location switched on:
    // try again without being asked.
    _life = AppLifecycleListener(
      onResume: () {
        final s = _tracker.snapshot.status;
        if (s == TrackerStatus.approximate ||
            s == TrackerStatus.denied ||
            s == TrackerStatus.serviceOff) {
          unawaited(_tracker.prepare());
        }
      },
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _life.dispose();
    _tracker.dispose();
    super.dispose();
  }

  bool get _hike => _tracker.snapshot.kind == RunKind.hike;
  String get _noun => _hike ? 'hike' : 'run';

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    await HapticFeedback.mediumImpact();
    await _tracker.start();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await HapticFeedback.heavyImpact();
    final run = await _tracker.finish();
    ref.invalidate(openRunProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = run;
      _savedTrack = _tracker.track;
    });
  }

  Future<void> _discard() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Throw this $_noun away?'),
        content: const Text(
          'The trail and every number go. Nothing is logged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _tracker.discard();
    ref.invalidate(openRunProvider);
    if (mounted) Navigator.of(context).pop(false);
  }

  /// Back while the run is live: finish, keep going, or throw it away.
  Future<void> _onBack() async {
    if (_saved != null) {
      Navigator.of(context).pop(true);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Your $_noun is still recording'),
        content: const Text(
          'Finish it now to save it, or keep running. Leaving the screen '
          'without finishing keeps it open until you come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: Text(_hike ? 'Keep hiking' : 'Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'finish'),
            child: const Text('Finish and save'),
          ),
        ],
      ),
    );
    switch (choice) {
      case 'finish':
        await _finish();
      case 'discard':
        await _discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    if (saved != null) return _savedView(saved);

    return ValueListenableBuilder<RunSnapshot>(
      valueListenable: _tracker.state,
      builder: (context, s, _) => PopScope(
        canPop: !s.isLive,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_onBack());
        },
        child: Scaffold(
          backgroundColor: AppTheme.bg,
          body: switch (s.status) {
            TrackerStatus.denied => _Blocked(
              icon: Icons.location_disabled_outlined,
              title: 'Location is off for this app',
              body:
                  'The run map needs your position while it records, and '
                  'only then. It never leaves this phone.',
              primary: 'Allow location',
              onPrimary: _tracker.prepare,
              secondary: 'Open app settings',
              onSecondary: _tracker.openSettings,
            ),
            TrackerStatus.serviceOff => _Blocked(
              icon: Icons.gps_off_outlined,
              title: 'Location is switched off',
              body: 'Turn Location on in the quick settings, then try again.',
              primary: 'Try again',
              onPrimary: _tracker.prepare,
            ),
            TrackerStatus.approximate => _Blocked(
              icon: Icons.location_searching,
              title: 'Precise location is off',
              body:
                  'This app has approximate location: a position a '
                  'kilometre wide, so the GPS would never find you. A run '
                  'needs precise.\n\nSettings → Permissions → Location → turn '
                  'on "Use precise location", then come back.',
              primary: 'Open app settings',
              onPrimary: _tracker.openSettings,
              secondary: 'Try again',
              onSecondary: _tracker.prepare,
            ),
            _ => _live(s),
          },
        ),
      ),
    );
  }

  Widget _live(RunSnapshot s) {
    final link = widget.launch.link;
    final target = link?.target;
    final band = target is DistanceTarget
        ? null
        : ref.watch(paceBandProvider(link?.exerciseId)).asData?.value;
    final locatingFor = DateTime.now().difference(_openedAt);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: RunMap(
                  segments: s.segments,
                  position: s.position,
                  accuracyM: s.accuracyM,
                  follow: _follow,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _MapButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _GpsChip(accuracyM: s.accuracyM, status: s.status),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _MapButton(
                  icon: _follow
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  tooltip: _follow ? 'Stop following' : 'Follow me',
                  onTap: () => setState(() => _follow = !_follow),
                ),
              ),
            ],
          ),
        ),
        _Panel(
          title: widget.launch.title,
          snapshot: s,
          target: target,
          zone: s.kind == RunKind.hike
              ? null
              : band?.judge(s.currentPaceSecPerKm),
          controls: _controls(s, locatingFor),
        ),
      ],
    );
  }

  Widget _controls(RunSnapshot s, Duration locatingFor) {
    const tall = Size.fromHeight(64);
    switch (s.status) {
      case TrackerStatus.recording:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _tracker.pause,
                style: OutlinedButton.styleFrom(minimumSize: tall),
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HoldToFinish(onHeld: _finish, enabled: !_busy),
            ),
          ],
        );
      case TrackerStatus.paused:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _tracker.resume,
                    style: FilledButton.styleFrom(minimumSize: tall),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoldToFinish(onHeld: _finish, enabled: !_busy),
                ),
              ],
            ),
            TextButton(onPressed: _discard, child: Text('Discard this $_noun')),
          ],
        );
      default:
        // Start never waits for a perfect fix: the clock starts now, the
        // trail at the first usable fix.
        final ready = s.status == TrackerStatus.ready;
        final waitedLong = locatingFor > const Duration(seconds: 20);
        return Column(
          children: [
            _StartButton(onTap: _busy ? null : _start),
            if (!ready)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  waitedLong
                      ? 'Still looking. Step outside, away from tall buildings. '
                            'You can start anyway: the trail begins once it '
                            'finds you.'
                      : 'Finding you. You can start now: the trail begins '
                            'once the GPS locks.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!
                      .copyWith(color: AppTheme.textDim),
                ),
              ),
          ],
        );
    }
  }

  Widget _savedView(Run run) {
    final repo = ref.read(runRepositoryProvider);
    final track = _savedTrack ?? RunTrack();
    final exerciseName = run.setLogId == null
        ? null
        : widget.launch.exerciseName;
    void share() => showRunShareSheet(
      context,
      run: run,
      track: track,
      exerciseName: exerciseName,
    );
    Future<void> effort(int e) async {
      await repo.setEffort(run.id, e);
      if (mounted) {
        setState(() => _saved = run.copyWith(effort: Value(e)));
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(run.kind == RunKind.hike ? 'Hike saved' : 'Run saved'),
          actions: [
            IconButton(
              tooltip: 'Share as an image',
              icon: const Icon(Icons.ios_share),
              onPressed: share,
            ),
          ],
        ),
        body: run.kind == RunKind.hike
            ? HikeSummaryView(
                run: run,
                track: track,
                exerciseName: exerciseName,
                onShare: share,
                onEffort: effort,
              )
            : RunSummaryView(
                run: run,
                onShare: share,
                track: track,
                exerciseName: exerciseName,
                onEffort: effort,
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}

/// The numbers, big: distance first, then time and pace.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.snapshot,
    required this.controls,
    this.target,
    this.zone,
  });

  final String title;
  final RunSnapshot snapshot;
  final RunTarget? target;
  final PaceZone? zone;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final t = Theme.of(context).textTheme;
    final live = s.isLive;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outlineSoft)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTheme.overline,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (s.status == TrackerStatus.paused)
                  const _Flag(icon: Icons.pause_rounded, text: 'Paused')
                else if (s.autoPaused)
                  const _Flag(
                    icon: Icons.pause_circle_outline,
                    text: 'Auto-paused',
                  ),
              ],
            ),
            Gap.xs,
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatKm(s.distanceM),
                  style: AppTheme.numeric(64, color: AppTheme.text),
                ),
                const SizedBox(width: 6),
                Text(
                  'km',
                  style: t.titleMedium!.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _Figure(label: 'Time', value: formatClock(s.movingMs)),
                ),
                // A hike is counted by its climb: how far up, and where now.
                if (s.kind == RunKind.hike) ...[
                  Expanded(
                    child: _Figure(
                      label: '▲ Climb',
                      value: '${s.elevGainM.round()}',
                      unit: 'm',
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Height',
                      value: s.altitudeM == null
                          ? '–'
                          : '${s.altitudeM!.round()}',
                      unit: 'm',
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _Figure(
                      label: 'Pace',
                      value: formatPace(live ? s.currentPaceSecPerKm : null),
                      unit: '/km',
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Speed',
                      value: s.speedKmh == null
                          ? '–'
                          : s.speedKmh!.toStringAsFixed(1),
                      unit: 'km/h',
                    ),
                  ),
                ],
              ],
            ),
            if (target != null) ...[
              Gap.s,
              _TargetBar(target: target!, snapshot: s),
            ],
            if (live && zone != null && zone != PaceZone.none) ...[
              Gap.s,
              _PaceGuide(zone: zone!),
            ] else if (live &&
                zone == null &&
                target is! DistanceTarget &&
                s.kind == RunKind.run) ...[
              Gap.s,
              Text(
                'Easy means you could talk in sentences.',
                style: t.bodySmall!.copyWith(color: AppTheme.textDim),
              ),
            ],
            Gap.m,
            controls,
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTheme.overline),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTheme.numeric(32)),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: t.labelMedium!.copyWith(color: AppTheme.textDim),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetBar extends StatelessWidget {
  const _TargetBar({required this.target, required this.snapshot});

  final RunTarget target;
  final RunSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = target.progress(
      movingMs: snapshot.movingMs,
      distanceM: snapshot.distanceM,
    );
    final done = p >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 6,
            color: AppTheme.crimson,
            backgroundColor: AppTheme.surfaceHigher,
          ),
        ),
        Gap.xs,
        Row(
          children: [
            if (done) ...[
              const Icon(Icons.check_circle, size: 16, color: AppTheme.good),
              const SizedBox(width: 6),
            ],
            Text(
              done
                  ? 'Target done. Finish when you like.'
                  : target.remainingLabel(
                      movingMs: snapshot.movingMs,
                      distanceM: snapshot.distanceM,
                    ),
              style: t.bodyMedium!.copyWith(
                color: done ? AppTheme.good : AppTheme.textDim,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// His live pace against his own easy pace. A glyph with every colour.
class _PaceGuide extends StatelessWidget {
  const _PaceGuide({required this.zone});

  final PaceZone zone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (glyph, text, colour) = switch (zone) {
      PaceZone.easeOff => (
        '▲',
        'Quicker than your easy pace: ease off',
        AppTheme.warn,
      ),
      PaceZone.onPace => ('●', 'On your easy pace', AppTheme.good),
      PaceZone.pickUp => (
        '▼',
        'Slower than easy: fine on a hill',
        AppTheme.textDim,
      ),
      PaceZone.none => ('', '', AppTheme.textDim),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Text(glyph, style: TextStyle(color: colour, fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: t.bodyMedium!.copyWith(color: colour)),
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppTheme.warn),
      const SizedBox(width: 4),
      Text(
        text,
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: AppTheme.warn),
      ),
    ],
  );
}

/// GPS quality, as a glyph and a number: bars, not a colour.
class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.accuracyM, required this.status});

  final double? accuracyM;
  final TrackerStatus status;

  @override
  Widget build(BuildContext context) {
    final a = accuracyM;
    final (icon, text) = a == null
        ? (Icons.gps_not_fixed_rounded, 'Waiting for GPS')
        : a <= 12
        ? (Icons.gps_fixed_rounded, 'GPS good ±${a.round()} m')
        : a <= 30
        ? (Icons.gps_fixed_rounded, 'GPS fair ±${a.round()} m')
        : (Icons.gps_not_fixed_rounded, 'GPS weak ±${a.round()} m');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.text),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xCC0A0A0C),
    shape: const CircleBorder(side: BorderSide(color: AppTheme.outlineSoft)),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.text),
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
    ),
  );
}

/// When location cannot be used: say why, and offer the way out.
class _Blocked extends StatelessWidget {
  const _Blocked({
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primary;
  final Future<void> Function() onPrimary;
  final String? secondary;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  EmptyState(icon: icon, title: title, body: body),
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 56),
                    ),
                    child: Text(primary),
                  ),
                  if (secondary != null) ...[
                    Gap.s,
                    TextButton(onPressed: onSecondary, child: Text(secondary!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A finish button that has to be held, filling as it goes. A tap only
/// says so.
class HoldToFinish extends StatefulWidget {
  const HoldToFinish({
    super.key,
    required this.onHeld,
    this.enabled = true,
    this.hold = const Duration(milliseconds: 1200),
  });

  final VoidCallback onHeld;
  final bool enabled;
  final Duration hold;

  @override
  State<HoldToFinish> createState() => _HoldToFinishState();
}

class _HoldToFinishState extends State<HoldToFinish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.hold,
  )..addStatusListener(_done);

  /// Set when a hold completes, so letting go afterwards is not mistaken
  /// for a tap that needs the "hold it" hint.
  bool _fired = false;

  void _done(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _fired = true;
      _c.value = 0;
      widget.onHeld();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Hold to finish the run',
      onLongPress: widget.enabled ? widget.onHeld : null,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _c.forward() : null,
        onTapUp: (_) {
          if (_fired) {
            _fired = false;
            return;
          }
          if (_c.status != AnimationStatus.completed) {
            _c.reverse();
            ScaffoldMessenger.maybeOf(context)
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Hold the button to finish')),
              );
          }
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppTheme.crimson),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: _c.value,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppTheme.crimson),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stop_rounded, color: AppTheme.text),
                          const SizedBox(width: 6),
                          Text('Hold to finish', style: t.labelLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big round Start, the one thing to press.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      button: true,
      label: 'Start the run',
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Ink(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.crimsonGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.crimson.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_run_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                Text(
                  'Start',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
