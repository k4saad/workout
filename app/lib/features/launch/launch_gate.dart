import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/quote_providers.dart';
import '../../app/run_providers.dart';
import '../../app/session_providers.dart';
import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/preferences_service.dart';
import '../../domain/content/quotes.dart';

/// The first thing on the first open of the day: a quote, addressed to him,
/// then out of the way.
///
/// It sits OVER the router rather than being a route, so a deep link, a
/// notification tap or a resumed session lands exactly where it would have
/// without it. It stands aside at once when a session or a run is waiting
/// to be picked up, when the quote is switched off in Settings, and on
/// every later open that day.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key, required this.child, this.now});

  final Widget child;

  /// The clock, for the greeting. Injectable for tests and screenshots.
  final DateTime Function()? now;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

enum _Phase { deciding, showing, leaving, gone }

class _LaunchGateState extends ConsumerState<LaunchGate>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.deciding;
  Quote? _quote;
  String _name = Preferences.defaultAthleteName;
  Timer? _auto;
  Timer? _safety;
  Duration _readTime = const Duration(seconds: 5);

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    // Never hold the app hostage: whatever is slow, the cover lifts.
    _safety = Timer(const Duration(milliseconds: 1500), () {
      if (_phase == _Phase.deciding) _leave();
    });
    unawaited(_decide());
  }

  @override
  void dispose() {
    _auto?.cancel();
    _safety?.cancel();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    try {
      Preferences prefs;
      try {
        prefs = await ref.read(preferencesProvider.future);
      } on Object {
        prefs = const Preferences();
      }
      if (!prefs.launchQuote) return _leave();
      _name = prefs.athleteName;

      // Something to go back to comes first.
      final resumable = await ref.read(resumableSessionProvider.future);
      final openRun = await ref.read(openRunProvider.future);
      if (resumable != null || openRun != null) return _leave();

      final daily = await ref.read(quoteOfDayProvider.future);
      if (daily == null || !daily.fresh || !mounted) return _leave();
      if (_phase != _Phase.deciding) return;

      _safety?.cancel();
      final chars = daily.quote.text.length;
      _readTime = Duration(
        milliseconds: (2600 + chars * 38).clamp(4000, 10000),
      );
      setState(() {
        _quote = daily.quote;
        _phase = _Phase.showing;
      });
      if (AppMotion.reduced(context)) {
        _enter.value = 1;
      } else {
        unawaited(_enter.forward());
      }
      _auto = Timer(_readTime, _leave);
    } on Object {
      _leave();
    }
  }

  void _leave() {
    if (!mounted || _phase == _Phase.leaving || _phase == _Phase.gone) return;
    _auto?.cancel();
    _safety?.cancel();
    setState(() => _phase = _Phase.leaving);
  }

  String get _greeting {
    final hour = (widget.now ?? DateTime.now)().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return '$part, $_name.';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_phase != _Phase.gone)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _phase == _Phase.leaving ? 0 : 1,
              duration: AppMotion.reduced(context)
                  ? Duration.zero
                  : AppMotion.slow,
              curve: AppMotion.curve,
              onEnd: () {
                if (_phase == _Phase.leaving) {
                  setState(() => _phase = _Phase.gone);
                }
              },
              child: _cover(context),
            ),
          ),
      ],
    );
  }

  Widget _cover(BuildContext context) {
    final quote = _quote;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _leave,
      child: ColoredBox(
        color: AppTheme.bg,
        child: quote == null
            ? const SizedBox.expand()
            : _QuoteCover(
                quote: quote,
                greeting: _greeting,
                enter: _enter,
                readTime: _readTime,
              ),
      ),
    );
  }
}

class _QuoteCover extends StatelessWidget {
  const _QuoteCover({
    required this.quote,
    required this.greeting,
    required this.enter,
    required this.readTime,
  });

  final Quote quote;
  final String greeting;
  final Animation<double> enter;
  final Duration readTime;

  /// One step of the entrance: fades and rises in over [begin]..[end] of it.
  Widget _step(double begin, double end, Widget child) {
    final a = CurvedAnimation(
      parent: enter,
      curve: Interval(begin, end, curve: AppMotion.emphasized),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - a.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final size = quote.text.length > 220
        ? 20.0
        : quote.text.length > 130
        ? 23.0
        : 27.0;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              _step(
                0,
                0.35,
                Text(
                  greeting,
                  style: t.titleMedium!.copyWith(color: AppTheme.textDim),
                ),
              ),
              Gap.l,
              _step(
                0.15,
                0.7,
                Semantics(
                  label: '${quote.text}. ${quote.attribution}.',
                  child: ExcludeSemantics(
                    child: Text(
                      quote.text,
                      style: AppTheme.serif(size, height: 1.45),
                    ),
                  ),
                ),
              ),
              Gap.l,
              _step(
                0.5,
                1,
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: enter,
                      builder: (context, _) => Container(
                        width: 8 + 28 * Curves.easeOut.transform(enter.value),
                        height: 2,
                        color: AppTheme.crimson,
                      ),
                    ),
                    Gap.m,
                    Expanded(
                      child: Text(quote.attribution, style: t.titleSmall),
                    ),
                  ],
                ),
              ),
              if (quote.translator != null) ...[
                Gap.xs,
                _step(
                  0.6,
                  1,
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Text(
                      quote.translator!,
                      style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              Center(
                child: Text(
                  'Tap to continue',
                  style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
                ),
              ),
              Gap.s,
              // How long until it steps aside by itself.
              _Countdown(duration: readTime),
            ],
          ),
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: duration,
    builder: (context, v, _) => Align(
      alignment: Alignment.center,
      child: Container(
        width: 120 * v,
        height: 2,
        decoration: BoxDecoration(
          color: AppTheme.outline,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    ),
  );
}
