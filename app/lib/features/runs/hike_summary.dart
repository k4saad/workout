import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../domain/run/run.dart';
import '../../domain/terrain/terrain.dart';
import 'route_hero.dart';
import 'run_summary.dart';
import 'terrain_view.dart';

/// Hike [id] as a 3D scene: on its terrain when that could be had, on the
/// phone's own heights when not. Null when there is no trail to draw.
final hikeSceneProvider = FutureProvider.family<TerrainScene?, int>((
  ref,
  id,
) async {
  final track = await ref.watch(runTrackProvider(id).future);
  final ground = await ref.watch(hikeGroundProvider(id).future);
  if (ground == null || !track.segments.any((s) => s.length > 1)) {
    return null;
  }
  final terrain = ground.terrain;
  return terrain != null
      ? TerrainScene(grid: terrain, trail: track.segments, style: terrainStyle)
      : TerrainScene(
          grid: HeightGrid.flat(ground.area, track.minAltM ?? 0),
          trail: track.segments,
          style: terrainStyle,
          hasTerrain: false,
        );
});

/// A finished hike, read back: the country in 3D, the climb, the profile
/// and the map. Shared by the end of the live screen and the hike's page.
class HikeSummaryView extends ConsumerWidget {
  const HikeSummaryView({
    super.key,
    required this.run,
    required this.track,
    this.exerciseName,
    this.onEffort,
    this.onShare,
  });

  final Run run;
  final RunTrack track;
  final String? exerciseName;
  final ValueChanged<int>? onEffort;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final started = DateTime.fromMillisecondsSinceEpoch(run.startedAtMs);
    final title = runTitle(started, kind: RunKind.hike);
    final subtitle =
        '${DateFormat('EEE d MMM').format(started)} · '
        '${formatKm(run.distanceM)} km · '
        '▲ ${(run.elevGainM ?? 0).round()} m';
    final hasTrail = track.segments.any((s) => s.length > 1);
    final scene = hasTrail ? ref.watch(hikeSceneProvider(run.id)) : null;
    final ready = scene?.asData?.value;
    final speed = run.movingMs <= 0 || run.distanceM < 10
        ? null
        : run.distanceM / (run.movingMs / 1000) * 3.6;
    final fromTerrain = ready?.highestOnTrailM;
    final highest = fromTerrain ?? run.maxAltM ?? track.maxAltM;
    final profile = track.elevationProfile();

    return ListView(
      padding: Gap.pagePadding,
      children: [
        Text(title, style: t.headlineSmall),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: SizedBox(
            height: 340,
            child: !hasTrail
                ? const NoTrail()
                : switch (scene!) {
                    AsyncData(value: final s?) => TerrainView(
                      scene: s,
                      onExpand: () => TerrainFullScreen.open(
                        context,
                        scene: s,
                        title: title,
                        subtitle: subtitle,
                      ),
                    ),
                    AsyncData() || AsyncError() => const NoTrail(),
                    _ => const _Fetching(),
                  },
          ),
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
                    child: SummaryStat(
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
                    child: SummaryStat(
                      label: '▲ Ascent',
                      value: '${(run.elevGainM ?? track.elevGainM).round()}',
                      unit: 'm',
                    ),
                  ),
                  Expanded(
                    child: SummaryStat(
                      label: '▼ Descent',
                      value: '${(run.elevLossM ?? track.elevLossM).round()}',
                      unit: 'm',
                    ),
                  ),
                ],
              ),
              Gap.m,
              Row(
                children: [
                  Expanded(
                    child: SummaryStat(
                      label: 'Highest point',
                      value: highest == null
                          ? '–'
                          : '${fromTerrain == null ? '≈' : ''}'
                                '${highest.round()}',
                      unit: highest == null ? null : 'm',
                    ),
                  ),
                  Expanded(
                    child: SummaryStat(
                      label: 'Avg speed',
                      value: speed == null ? '–' : speed.toStringAsFixed(1),
                      unit: 'km/h',
                    ),
                  ),
                ],
              ),
              if (highest != null) ...[
                Gap.s,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    fromTerrain != null
                        ? 'Highest point from the terrain under the trail.'
                        : 'Highest point by the phone\'s GPS, which can read '
                              'tens of metres off.',
                    style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (profile.length > 2) ...[
          const SectionHeader('Elevation'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: SizedBox(
              height: 160,
              child: ElevationChart(profile: profile),
            ),
          ),
        ],
        if (hasTrail) ...[
          const SectionHeader('On the map'),
          RouteHero(
            track: track,
            onShare: onShare,
            onExpand: () => RouteFullScreen.open(
              context,
              track: track,
              title: title,
              subtitle: subtitle,
              onShare: onShare,
            ),
          ),
        ],
        if (onEffort != null || run.effort != null) ...[
          const SectionHeader('How hard was it?'),
          EffortChips(value: run.effort, onChanged: onEffort),
        ],
        Gap.xl,
      ],
    );
  }
}

class _Fetching extends StatelessWidget {
  const _Fetching();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const Skeleton(height: 340, radius: 0),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terrain_outlined, color: AppTheme.textDim),
            Gap.s,
            Text(
              'Fetching the terrain',
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Height along the hike: the climb as a silhouette, the top marked with a
/// glyph as well as a dot.
class ElevationChart extends StatelessWidget {
  const ElevationChart({super.key, required this.profile});

  final List<ElevationSample> profile;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Height along the hike',
    child: CustomPaint(
      size: Size.infinite,
      painter: _ElevationPainter(profile),
    ),
  );
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.profile);

  final List<ElevationSample> profile;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    const left = 44.0;
    const bottom = 18.0;
    const top = 16.0;
    final w = size.width - left;
    final h = size.height - bottom - top;
    final lo = profile.map((e) => e.altitudeM).reduce(math.min);
    final hi = profile.map((e) => e.altitudeM).reduce(math.max);
    // At least 20 m of scale: a flat walk should look flat.
    final span = math.max(20.0, hi - lo);
    final floor = lo - span * 0.1;
    final ceil = floor + span * 1.2;
    final d0 = profile.first.distanceM;
    final dist = math.max(1.0, profile.last.distanceM - d0);

    double x(double d) => left + w * ((d - d0) / dist);
    double y(double alt) => top + h * (1 - (alt - floor) / (ceil - floor));

    final label = TextStyle(
      color: AppTheme.textFaint,
      fontSize: 11,
      fontFamily: AppTheme.numericFamily,
    );
    final grid = Paint()
      ..color = AppTheme.outlineSoft
      ..strokeWidth = 1;
    for (final alt in [lo, hi]) {
      canvas.drawLine(Offset(left, y(alt)), Offset(size.width, y(alt)), grid);
      final tp = TextPainter(
        text: TextSpan(text: '${alt.round()} m', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(alt) - tp.height / 2));
    }

    final line = Path();
    final fill = Path()..moveTo(x(d0), top + h);
    for (var i = 0; i < profile.length; i++) {
      final p = Offset(x(profile[i].distanceM), y(profile[i].altitudeM));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(x(profile.last.distanceM), top + h)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.textDim.withValues(alpha: 0.30),
              AppTheme.textDim.withValues(alpha: 0.03),
            ],
          ).createShader(Rect.fromLTWH(left, top, w, h)),
      )
      ..drawPath(
        line,
        Paint()
          ..color = AppTheme.crimson
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );

    final peak = profile.reduce((a, b) => a.altitudeM >= b.altitudeM ? a : b);
    final pp = Offset(x(peak.distanceM), y(peak.altitudeM));
    canvas.drawCircle(pp, 4, Paint()..color = AppTheme.text);
    // The summit's glyph, drawn: the chart's figures font has no triangle.
    canvas.drawPath(
      Path()
        ..moveTo(pp.dx, pp.dy - 15)
        ..lineTo(pp.dx + 5, pp.dy - 8)
        ..lineTo(pp.dx - 5, pp.dy - 8)
        ..close(),
      Paint()..color = AppTheme.text,
    );

    final km = TextPainter(
      text: TextSpan(
        text: '${(profile.last.distanceM / 1000).toStringAsFixed(1)} km',
        style: label,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    km.paint(canvas, Offset(size.width - km.width, top + h + 4));
    final zero = TextPainter(
      text: TextSpan(text: '0', style: label),
      textDirection: TextDirection.ltr,
    )..layout();
    zero.paint(canvas, Offset(left, top + h + 4));
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.profile != profile;
}
