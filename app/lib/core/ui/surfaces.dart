import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// The card every screen is built from.
///
/// - [hero] fills it with the crimson gradient: the ONE thing on a screen.
/// - [accent] puts a thin crimson edge on the left: "this one is today".
/// - [onTap] makes the whole card pressable, with the press-scale and click.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(18),
    this.hero = false,
    this.accent,
    this.radius = AppRadius.l,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final bool hero;
  final Color? accent;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final fill = BoxDecoration(
      borderRadius: r,
      gradient: hero ? AppTheme.crimsonGradient : AppTheme.surfaceGradient,
      border: Border.all(
        color: hero
            ? AppTheme.crimsonBright.withValues(alpha: 0.35)
            : AppTheme.outlineSoft,
      ),
    );
    // Flat, not shadowed: on near-black an offset shadow reads as a dark
    // ledge under the card. Depth comes from the gradient and border; only
    // the hero glows, and evenly, so it lifts rather than drops.
    final glow = hero
        ? BoxDecoration(
            borderRadius: r,
            boxShadow: [
              BoxShadow(
                color: AppTheme.crimson.withValues(alpha: 0.30),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          )
        : null;
    final body = ClipRRect(
      borderRadius: r,
      // passthrough: the card's own constraints reach the child, so a
      // centred Column is centred, exactly as inside a Material Card.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
          Padding(
            padding: accent == null
                ? padding
                : padding.add(const EdgeInsets.only(left: 4)),
            child: child,
          ),
        ],
      ),
    );
    if (onTap == null && onLongPress == null) {
      return Semantics(
        label: semanticLabel,
        child: DecoratedBox(
          decoration: fill.copyWith(boxShadow: glow?.boxShadow),
          child: body,
        ),
      );
    }
    // The fill is INK on the pressable's Material, so the ripple paints on
    // top of it — with reduced motion (no press-scale) the ripple is the
    // only sign a tap landed, and an opaque box hid it.
    final pressable = Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: r,
      semanticLabel: semanticLabel,
      child: Ink(decoration: fill, child: body),
    );
    return glow == null
        ? pressable
        : DecoratedBox(decoration: glow, child: pressable);
  }
}

/// The tone of a banner. Every tone has its own glyph, so the meaning never
/// rests on colour alone.
enum Tone {
  info(AppTheme.textDim, Icons.info_outline),
  good(AppTheme.good, Icons.check_circle_outline),
  warn(AppTheme.warn, Icons.warning_amber_rounded),
  accent(AppTheme.crimson, Icons.bolt);

  const Tone(this.color, this.icon);
  final Color color;
  final IconData icon;
}

/// One banner for every "heads up" on every screen — replaces six hand-made
/// tinted boxes that had drifted apart.
class ToneBanner extends StatelessWidget {
  const ToneBanner({
    super.key,
    required this.tone,
    required this.title,
    this.body,
    this.icon,
    this.onTap,
    this.trailing,
  });

  final Tone tone;
  final String title;
  final String? body;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: tone.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? tone.icon, color: tone.color, size: 24),
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleMedium!.copyWith(
                    color: tone == Tone.info ? AppTheme.text : tone.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[Gap.xs, Text(body!, style: t.bodyMedium)],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right, color: tone.color),
        ],
      ),
    );
    if (onTap == null) return content;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: content,
    );
  }
}

/// A section label with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 22, 4, 10),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title.toUpperCase(), style: AppTheme.overline)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          ),
      ],
    ),
  );
}

/// A labelled number: "SQUAT · 34 kg".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.decimals = 0,
    this.glyph,
    this.color = AppTheme.text,
    this.labelColor,
    this.unitColor,
    this.size = 30,
  });

  final String label;
  final double value;
  final String? unit;
  final String? caption;
  final int decimals;
  final String? glyph;
  final Color color;

  /// Overline colour. Defaults to the dim grey; pass a light tint on a
  /// crimson hero, where grey has no contrast.
  final Color? labelColor;

  /// Unit colour ("kg", "kcal"). Pass white on a crimson hero, where the
  /// default grey sinks to about 1.7:1.
  final Color? unitColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: labelColor == null
              ? AppTheme.overline
              : AppTheme.overline.copyWith(color: labelColor),
        ),
        Gap.xs,
        // Big numbers shrink to fit rather than overflow: "2,900 kcal" in a
        // half-width tile on a small phone at a large text scale.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (glyph != null) ...[
                Text(
                  glyph!,
                  style: TextStyle(color: color, fontSize: size * .6),
                ),
                const SizedBox(width: 4),
              ],
              AnimatedCount(
                value: value,
                decimals: decimals,
                style: AppTheme.numeric(size, color: color),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: t.labelLarge!.copyWith(
                    color: unitColor ?? AppTheme.textDim,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (caption != null) ...[
          Gap.xs,
          Text(caption!, style: t.bodySmall!.copyWith(color: AppTheme.textDim)),
        ],
      ],
    );
  }
}

/// An animated progress ring with a label in the middle.
///
/// At or over 100 % it adds a tick glyph, so "done" is not a colour.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 11,
    this.color = AppTheme.crimson,
    this.track = AppTheme.surfaceHigher,
    this.center,
  });

  /// 0..1 (values above 1 draw a full ring).
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    Widget ring(double x) => CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(
        value: x,
        stroke: stroke,
        color: color,
        track: track,
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (AppMotion.reduced(context))
            ring(v)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: AppMotion.slow * 1.6,
              curve: AppMotion.emphasized,
              builder: (_, x, _) => ring(x),
            ),
          ?center,
          // The tick follows the SANITISED value, so the ring and the tick
          // can never disagree (a NaN draws empty and ticks nothing).
          if (v >= 1)
            Positioned(
              top: stroke * .2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  Icons.check,
                  size: stroke * 1.1,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(r);
    canvas.drawArc(r, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A row that goes somewhere: icon, title, optional subtitle, chevron.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: Icon(icon, color: iconColor ?? AppTheme.text, size: 22),
              ),
              Gap.m,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: t.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                      ),
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textFaint,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a screen shows before there is anything to show. Says what will be
/// here and how to put it there — never just "No data".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceHigh,
              border: Border.all(color: AppTheme.outlineSoft),
            ),
            child: Icon(icon, size: 34, color: AppTheme.textDim),
          ),
          Gap.l,
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          if (body != null) ...[
            Gap.s,
            Text(
              body!,
              style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            Gap.l,
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// A bottom sheet in the house style: rounded, scroll-safe, keyboard-aware.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: useRootNavigator,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: builder(ctx),
      ),
    ),
  ),
);
