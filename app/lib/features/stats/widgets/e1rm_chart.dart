import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/metrics/strength_metrics.dart';

/// Estimated max over time, drawn by hand.
///
/// Same reasoning as the bodyweight chart: one line and a few dots is less
/// code to draw than a charting package is to configure, and this app keeps
/// its dependency list short on purpose.
///
/// The number plotted is an **estimate** — Epley from a working set. The
/// caller is responsible for saying so next to the chart.
class E1rmChart extends StatelessWidget {
  const E1rmChart({super.key, required this.points, this.compact = false});

  final List<E1rmPoint> points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text(
          points.isEmpty
              ? 'No loaded sets logged yet.'
              : 'One session in. Two makes a line.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.textDim),
          textAlign: TextAlign.center,
        ),
      );
    }
    return CustomPaint(
      painter: _E1rmPainter(
        points: points,
        compact: compact,
        labelStyle: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: AppTheme.textDim, fontSize: 11),
      ),
      size: Size.infinite,
    );
  }
}

class _E1rmPainter extends CustomPainter {
  _E1rmPainter({
    required this.points,
    required this.labelStyle,
    this.compact = false,
  });

  final List<E1rmPoint> points;
  final TextStyle labelStyle;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = compact ? 0.0 : 38.0;
    final bottomPad = compact ? 0.0 : 20.0;
    final plot = Rect.fromLTRB(
      leftPad,
      6,
      size.width - 4,
      size.height - bottomPad,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    var minKg = points.first.e1rmKg, maxKg = points.first.e1rmKg;
    for (final p in points) {
      if (p.e1rmKg < minKg) minKg = p.e1rmKg;
      if (p.e1rmKg > maxKg) maxKg = p.e1rmKg;
    }
    // A flat series must not divide by zero, and a 2 kg rise should not fill
    // the whole box as though it were a transformation.
    final pad = ((maxKg - minKg) * 0.15).clamp(1.0, 50.0);
    minKg -= pad;
    maxKg += pad;

    final firstMs = points.first.date.millisecondsSinceEpoch;
    final spanMs = points.last.date.millisecondsSinceEpoch - firstMs;

    Offset at(E1rmPoint p) {
      final x = spanMs == 0
          ? plot.center.dx
          : plot.left +
                plot.width *
                    ((p.date.millisecondsSinceEpoch - firstMs) / spanMs);
      final y =
          plot.bottom - plot.height * ((p.e1rmKg - minKg) / (maxKg - minKg));
      return Offset(x, y);
    }

    if (!compact) {
      final grid = Paint()
        ..color = AppTheme.outline.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var i = 0; i <= 2; i++) {
        final t = i / 2;
        final y = plot.bottom - plot.height * t;
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
        _label(
          canvas,
          '${(minKg + (maxKg - minKg) * t).round()}',
          Offset(0, y - 7),
        );
      }
    }

    final line = Paint()
      ..color = AppTheme.oxblood
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = at(points[i]);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = AppTheme.oxblood;
    final ring = Paint()..color = AppTheme.bg;
    for (final p in points) {
      final o = at(p);
      canvas.drawCircle(o, 4.5, ring);
      canvas.drawCircle(o, 3, dot);
    }

    if (!compact) {
      _label(
        canvas,
        _short(points.first.date),
        Offset(plot.left, plot.bottom + 4),
      );
      final last = _short(points.last.date);
      _label(
        canvas,
        last,
        Offset(plot.right - last.length * 6.0, plot.bottom + 4),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  static String _short(DateTime d) => '${d.day}/${d.month}';

  @override
  bool shouldRepaint(covariant _E1rmPainter old) =>
      old.points != points || old.compact != compact;
}
