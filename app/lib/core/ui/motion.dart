import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shrinks a touch under the finger and clicks. The difference between a
/// surface that feels pressed and one that merely changes colour.
///
/// Pass [onTap] null for a surface that is visible but inert.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    if (!enabled) {
      // Inert: no ripple, no scale, nothing that suggests it can be tapped.
      return Semantics(label: widget.semanticLabel, child: widget.child);
    }
    final reduced = AppMotion.reduced(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.l);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down && !reduced ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTapDown: (_) => _set(true),
            onTapCancel: () => _set(false),
            onTapUp: (_) => _set(false),
            onTap: widget.onTap == null
                ? null
                : () {
                    if (widget.haptic) HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.onLongPress!();
                  },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts a child into place once, the first time it builds.
///
/// [index] staggers siblings so a list arrives as a cascade instead of a
/// block. With reduced motion it simply appears.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = AppMotion.slow,
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = AppMotion.stagger * widget.index.clamp(0, 12);
  // One controller covers delay + motion, so the stagger needs no Timer: a
  // pending Timer fails every widget test that pumps this.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration + _delay,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay.inMicroseconds / (widget.duration + _delay).inMicroseconds,
      1,
      curve: AppMotion.emphasized,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (_, child) => Opacity(
      opacity: _t.value.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _t.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// A number that counts to its new value instead of jumping.
///
/// The final value is always exactly [value] formatted with [decimals]; the
/// tween is only the journey there.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppMotion.slow,
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;
  final Duration duration;

  String _fmt(double v) {
    // Round FIRST: grouping and the sign are decided on what is printed, so
    // 999.6 prints "1,000" and -0.4 prints "0", never "-0".
    var s = v.toStringAsFixed(decimals);
    if (double.parse(s) == 0) s = s.replaceFirst('-', '');
    if (decimals > 0 || double.parse(s).abs() < 1000) {
      return '$prefix$s$suffix';
    }
    // Grouped thousands: 2,600 kcal reads at a glance, 2600 has to be read.
    final digits = s.replaceAll('-', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '$prefix${s.startsWith('-') ? '-' : ''}$buf$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) {
      return Text(_fmt(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: AppMotion.emphasized,
      builder: (_, v, _) => Text(_fmt(v), style: style),
    );
  }
}

/// A shimmering placeholder in the shape of the content that is loading —
/// far calmer than a spinner in the middle of an empty page.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppRadius.s,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final x = -1.5 + 3 * _c.value;
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(x - 1, 0),
            end: Alignment(x + 1, 0),
            colors: const [
              AppTheme.surfaceHigh,
              AppTheme.surfaceHigher,
              AppTheme.surfaceHigh,
            ],
          ),
        ),
      );
    },
  );
}

/// A page-shaped skeleton: a title bar and a few card-sized blocks.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: Gap.pagePadding,
    children: [
      const Skeleton(height: 14, width: 140),
      Gap.m,
      const Skeleton(height: 30, width: 240),
      Gap.l,
      for (var i = 0; i < cards; i++) ...[
        Skeleton(height: i == 0 ? 180 : 110, radius: AppRadius.l),
        Gap.m,
      ],
    ],
  );
}
