import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/intervals/interval_engine.dart';

/// The rest countdown, pinned above the log button.
///
/// The countdown itself is cosmetic — the scheduled notification is what
/// actually gets you back to the bar. So this repaints from wall-clock time
/// and simply catches up if the app was suspended, rather than trying to be
/// the source of truth.
class RestTimerBar extends StatefulWidget {
  const RestTimerBar({
    super.key,
    required this.endsAt,
    required this.totalSec,
    required this.label,
    required this.setNumber,
    required this.onAdjust,
    required this.onSkip,
    required this.onDone,
  });

  final DateTime endsAt;
  final int totalSec;
  final String label;
  final int setNumber;
  final void Function(int seconds) onAdjust;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  Timer? _ticker;
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void didUpdateWidget(RestTimerBar old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) _buzzed = false;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final left = widget.endsAt.difference(DateTime.now()).inMilliseconds;
    if (left <= 0 && !_buzzed) {
      _buzzed = true;
      // Haptic beats sound in a basement — you feel it in your pocket over
      // the noise, and it does not wake anyone upstairs.
      HapticFeedback.heavyImpact();
      widget.onDone();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final remaining = widget.endsAt.difference(DateTime.now());
    final secondsLeft = remaining.inSeconds.clamp(0, 86400);
    final overdue = remaining.isNegative;

    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    final clock = '$m:${s.toString().padLeft(2, '0')}';

    final progress = widget.totalSec == 0
        ? 1.0
        : (1 - secondsLeft / widget.totalSec).clamp(0.0, 1.0);

    final color = overdue ? AppTheme.good : AppTheme.moss;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdue ? 'REST DONE' : 'RESTING',
                      style: t.labelLarge?.copyWith(
                        color: color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${widget.label} · set ${widget.setNumber}',
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                overdue ? 'GO' : clock,
                style: t.displaySmall?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppTheme.outline,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          // Flexible, not fixed: at 400 px these three buttons overflow a
          // plain Row by a few pixels, which Flutter treats as an error.
          Row(
            children: [
              Expanded(
                child: _RestButton(
                  label: '−15s',
                  onTap: () => widget.onAdjust(-15),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RestButton(
                  label: '+15s',
                  onTap: () => widget.onAdjust(15),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _RestButton(
                  label: overdue ? 'Clear' : 'Skip rest',
                  emphasis: true,
                  onTap: widget.onSkip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({
    required this.label,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48, // never smaller: chalky hands, bad light
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: emphasis ? AppTheme.text : AppTheme.textDim,
          side: BorderSide(color: emphasis ? AppTheme.moss : AppTheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(child: Text(label)),
      ),
    );
  }
}

/// A countdown for interval work — skipping rounds, bag rounds.
///
/// Same engine as the rest timer, different presentation: rounds matter here.
class IntervalTimerPanel extends StatefulWidget {
  const IntervalTimerPanel({
    super.key,
    required this.spec,
    required this.startedAt,
    required this.onFinished,
  });

  final IntervalSpec spec;
  final DateTime startedAt;
  final VoidCallback onFinished;

  @override
  State<IntervalTimerPanel> createState() => _IntervalTimerPanelState();
}

class _IntervalTimerPanelState extends State<IntervalTimerPanel> {
  Timer? _ticker;
  IntervalPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final tick = IntervalEngine(widget.spec)
        .atTime(widget.startedAt, DateTime.now());
    if (tick.phase != _lastPhase) {
      _lastPhase = tick.phase;
      HapticFeedback.mediumImpact();
      if (tick.isDone) widget.onFinished();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tick = IntervalEngine(widget.spec)
        .atTime(widget.startedAt, DateTime.now());

    final (label, color) = switch (tick.phase) {
      IntervalPhase.prepare => ('GET READY', AppTheme.warn),
      IntervalPhase.work => ('WORK', AppTheme.oxblood),
      IntervalPhase.rest => ('REST', AppTheme.moss),
      IntervalPhase.done => ('DONE', AppTheme.good),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: t.labelLarge?.copyWith(color: color, letterSpacing: 1.6),
          ),
          Text(
            tick.isDone ? '—' : tick.clock,
            style: t.displaySmall?.copyWith(
              fontSize: 52,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Round ${tick.round} of ${widget.spec.rounds}',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: tick.progress,
              minHeight: 5,
              backgroundColor: AppTheme.outline,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
