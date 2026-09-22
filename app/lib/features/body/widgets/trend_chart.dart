import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/metrics/bodyweight_trend.dart';

/// Bodyweight: the rolling average as a line, the raw readings as dots.
///
/// Hand-drawn rather than pulling in a charting package. This needs one line,
/// one scatter and a target rule; a chart library would be more code to
/// configure than to draw, and one fewer dependency in an app that holds a
/// year of training data is worth having.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    this.targetKg,
    this.compact = false,
  });

  final List<TrendPoint> points;
  final double? targetKg;

  /// Dashboard mode: just the line, no axis labels.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text(
          'Two weigh-ins and this becomes a line.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.textDim),
        ),
      );
    }
    return CustomPaint(
      painter: _TrendPainter(
        points: points,
        targetKg: targetKg,
        compact: compact,
        labelStyle: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: AppTheme.textDim, fontSize: 11),
      ),
      size: Size.infinite,
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.labelStyle,
    this.targetKg,
    this.compact = false,
  });

  final List<TrendPoint> points;
  final double? targetKg;
  final bool compact;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      ...points.map((p) => p.average),
      ...points.map((p) => p.raw),
      ?targetKg,
    ];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if ((hi - lo).abs() < 0.5) {
      lo -= 0.5;
      hi += 0.5;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;

    final left = compact ? 0.0 : 34.0;
    final bottom = compact ? 0.0 : 16.0;
    final w = size.width - left;
    final h = size.height - bottom;
    if (w <= 0 || h <= 0) return;

    double x(int i) => left + w * i / (points.length - 1);
    double y(double kg) => h - h * (kg - lo) / (hi - lo);

    // The target line, if the programme has one.
    if (targetKg != null && !compact) {
      final dash = Paint()
        ..color = AppTheme.good.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      final ty = y(targetKg!);
      for (var dx = left; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset(dx + 4, ty), dash);
      }
      _label(canvas, 'target', Offset(left + 2, ty - 14));
    }

    // Raw readings. Deliberately faint: they are the noise, not the signal.
    final dot = Paint()..color = AppTheme.textDim.withValues(alpha: 0.5);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].raw)), 1.8, dot);
    }

    // The rolling average: the line that actually decides anything.
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final at = Offset(x(i), y(points[i].average));
      if (i == 0) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.oxblood
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    if (compact) return;

    _label(canvas, hi.toStringAsFixed(1), Offset.zero);
    _label(canvas, lo.toStringAsFixed(1), Offset(0, h - 12));
    _label(canvas, '${points.length} readings', Offset(left, h + 2));
  }

  void _label(Canvas canvas, String text, Offset at) {
    TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points.length != points.length || old.targetKg != targetKg;
}
