import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../domain/run/run.dart';
import 'route_hero.dart';

/// A run's name, the way a running app names it: by the time of day.
String runTitle(DateTime started) {
  final h = started.hour;
  final part = h < 5
      ? 'Night'
      : h < 12
      ? 'Morning'
      : h < 17
      ? 'Afternoon'
      : h < 21
      ? 'Evening'
      : 'Night';
  return '$part run';
}

/// A finished run, read back: where it went, how far, how fast, and how it
/// felt. Shared by the end of the live screen and the run's own page.
class RunSummaryView extends StatelessWidget {
  const RunSummaryView({
    super.key,
    required this.run,
    required this.track,
    this.exerciseName,
    this.onEffort,
    this.footer,
  });

  final Run run;
  final RunTrack track;

  /// What it was logged as, for a run from a programme day.
  final String? exerciseName;

  /// Rate the effort; null when the rating cannot be changed here.
  final ValueChanged<int>? onEffort;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final started = DateTime.fromMillisecondsSinceEpoch(run.startedAtMs);
    final hasTrail = track.segments.any((s) => s.length > 1);
    final pace = run.distanceM < 10 || run.movingMs <= 0
        ? null
        : (run.movingMs / 1000) / (run.distanceM / 1000);

    return ListView(
      padding: Gap.pagePadding,
      children: [
        Text(runTitle(started), style: t.headlineSmall),
        Text(
          DateFormat('EEEE d MMMM · HH:mm').format(started),
          style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
        ),
        if (exerciseName != null) ...[
          Gap.xs,
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: AppTheme.good),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Logged as $exerciseName', style: t.bodyMedium),
              ),
            ],
          ),
        ],
        Gap.m,
        if (hasTrail)
          RouteHero(track: track)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: const SizedBox(height: 180, child: _NoTrail()),
          ),
        Gap.m,
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Distance',
                      value: run.distanceM / 1000,
                      decimals: 2,
                      unit: 'km',
                      size: 34,
                    ),
                  ),
                  Expanded(
                    child: _TextStat(
                      label: 'Moving time',
                      value: formatClock(run.movingMs),
                    ),
                  ),
                ],
              ),
              Gap.m,
              Row(
                children: [
                  Expanded(
                    child: _TextStat(
                      label: 'Avg pace',
                      value: formatPace(pace),
                      unit: '/km',
                    ),
                  ),
                  Expanded(
                    child: _TextStat(
                      label: 'Climb',
                      value: '${(run.elevGainM ?? 0).round()}',
                      unit: 'm',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (track.splits.isNotEmpty) ...[
          const SectionHeader('Splits'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _Splits(splits: track.splits),
          ),
        ],
        if (track.profile().length > 2) ...[
          const SectionHeader('Pace'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: SizedBox(
              height: 150,
              child: PaceChart(profile: track.profile(), average: pace),
            ),
          ),
        ],
        if (onEffort != null || run.effort != null) ...[
          const SectionHeader('How hard was it?'),
          _Effort(value: run.effort, onChanged: onEffort),
        ],
        ?footer,
        Gap.xl,
      ],
    );
  }
}

class _NoTrail extends StatelessWidget {
  const _NoTrail();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppTheme.surface,
    child: Center(
      child: EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No trail for this one',
        body: 'The GPS never got a good enough fix to draw it.',
      ),
    ),
  );
}

class _TextStat extends StatelessWidget {
  const _TextStat({required this.label, required this.value, this.unit});

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
        Gap.xs,
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTheme.numeric(30)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: t.labelLarge!.copyWith(color: AppTheme.textDim),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// One row a kilometre: pace, and a bar as long as the kilometre was quick.
/// The quickest carries a glyph, not just the longest bar.
class _Splits extends StatelessWidget {
  const _Splits({required this.splits});

  final List<RunSplit> splits;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paces = [
      for (final s in splits)
        if (!s.partial && s.paceSecPerKm != null) s.paceSecPerKm!,
    ];
    final fastest = paces.isEmpty ? null : paces.reduce(math.min);
    final slowest = paces.isEmpty ? null : paces.reduce(math.max);
    return Column(
      children: [
        for (final s in splits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    s.partial
                        ? '${(s.distanceM / 1000).toStringAsFixed(2)} km'
                        : 'km ${s.km}',
                    style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final p = s.paceSecPerKm;
                      var f = 0.6;
                      if (p != null &&
                          fastest != null &&
                          slowest != null &&
                          slowest > fastest) {
                        f = 0.35 + 0.65 * (slowest - p) / (slowest - fastest);
                      }
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 10,
                          width: c.maxWidth * f.clamp(0.2, 1.0),
                          decoration: BoxDecoration(
                            color: s.partial
                                ? AppTheme.surfaceHigher
                                : (p == fastest
                                      ? AppTheme.crimson
                                      : AppTheme.textFaint),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${s.paceSecPerKm == fastest && !s.partial ? '▲ ' : ''}'
                    '${formatPace(s.paceSecPerKm)}',
                    textAlign: TextAlign.end,
                    style: AppTheme.numeric(18),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pace along the run, faster higher, with the average dashed across.
class PaceChart extends StatelessWidget {
  const PaceChart({super.key, required this.profile, this.average});

  final List<PaceBucket> profile;
  final double? average;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Pace along the run',
    child: CustomPaint(
      size: Size.infinite,
      painter: _PaceChartPainter(profile, average),
    ),
  );
}

class _PaceChartPainter extends CustomPainter {
  _PaceChartPainter(this.profile, this.average);

  final List<PaceBucket> profile;
  final double? average;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    const left = 40.0;
    const bottom = 18.0;
    final w = size.width - left;
    final h = size.height - bottom;
    // Clip the extremes: one GPS hiccup should not flatten the whole line.
    final sorted = [for (final b in profile) b.paceSecPerKm]..sort();
    final lo = sorted[(sorted.length * 0.05).floor()];
    final hi =
        sorted[math.min(sorted.length - 1, (sorted.length * 0.95).ceil())];
    final span = math.max(20.0, hi - lo);
    final top = lo - span * 0.15;
    final bot = hi + span * 0.15;
    final dist = profile.last.distanceM;

    double x(double d) => left + w * (d / dist);
    double y(double pace) =>
        h * ((pace.clamp(top, bot) - top) / (bot - top)); // faster = higher

    final grid = Paint()
      ..color = AppTheme.outlineSoft
      ..strokeWidth = 1;
    final label = TextStyle(
      color: AppTheme.textFaint,
      fontSize: 11,
      fontFamily: AppTheme.numericFamily,
    );
    for (final p in [top + (bot - top) * 0.2, top + (bot - top) * 0.8]) {
      canvas.drawLine(Offset(left, y(p)), Offset(size.width, y(p)), grid);
      final tp = TextPainter(
        text: TextSpan(text: formatPace(p), style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(p) - tp.height / 2));
    }

    final path = Path();
    final fill = Path()..moveTo(x(0), h);
    var d0 = 0.0;
    for (var i = 0; i < profile.length; i++) {
      final b = profile[i];
      final mid = (d0 + b.distanceM) / 2;
      final pt = Offset(x(mid), y(b.paceSecPerKm));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      fill.lineTo(pt.dx, pt.dy);
      d0 = b.distanceM;
    }
    fill
      ..lineTo(x(d0), h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.crimson.withValues(alpha: 0.28),
            AppTheme.crimson.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(left, 0, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.crimson
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final avg = average;
    if (avg != null) {
      final ay = y(avg);
      const dash = 6.0;
      final p = Paint()
        ..color = AppTheme.textDim
        ..strokeWidth = 1.2;
      for (var sx = left; sx < size.width; sx += dash * 2) {
        canvas.drawLine(Offset(sx, ay), Offset(sx + dash, ay), p);
      }
    }

    final km = TextPainter(
      text: TextSpan(
        text: '${(dist / 1000).toStringAsFixed(1)} km',
        style: label,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    km.paint(canvas, Offset(size.width - km.width, h + 4));
    final zero = TextPainter(
      text: TextSpan(text: '0', style: label),
      textDirection: TextDirection.ltr,
    )..layout();
    zero.paint(canvas, Offset(left, h + 4));
  }

  @override
  bool shouldRepaint(_PaceChartPainter old) =>
      old.profile != profile || old.average != average;
}

/// 1 to 10: how hard it felt. Chips, not a keyboard.
class _Effort extends StatelessWidget {
  const _Effort({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int>? onChanged;

  static const _words = {
    2: 'Very easy',
    4: 'Easy, could chat',
    6: 'Steady',
    8: 'Hard',
    10: 'Everything',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= 10; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: value == i,
                onSelected: onChanged == null ? null : (_) => onChanged!(i),
                showCheckmark: false,
                labelStyle: AppTheme.numeric(
                  18,
                  color: value == i ? AppTheme.text : AppTheme.textDim,
                ),
                selectedColor: AppTheme.crimsonDeep,
                backgroundColor: AppTheme.surfaceHigh,
                side: BorderSide(
                  color: value == i ? AppTheme.crimson : AppTheme.outline,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        if (value != null) ...[
          Gap.s,
          Text(
            _words[value! + (value!.isOdd ? 1 : 0)] ?? '',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
        ],
      ],
    );
  }
}
