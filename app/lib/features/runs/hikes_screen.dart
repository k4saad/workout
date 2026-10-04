import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../domain/run/run.dart';
import 'live_run_screen.dart';
import 'run_share_card.dart' show RouteLinePainter;
import 'run_summary.dart';

/// Every hike, newest first, and the way to start one.
class HikesScreen extends ConsumerWidget {
  const HikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hikes = ref.watch(finishedHikesProvider);
    final open = ref.watch(openRunProvider).asData?.value;
    final openHike = open != null && open.kind == RunKind.hike;

    return Scaffold(
      appBar: AppBar(title: const Text('Hikes')),
      body: hikes.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView(
          padding: Gap.pagePadding,
          children: [
            if (openHike) ...[
              AppCard(
                accent: AppTheme.crimson,
                onTap: () => _startHike(context, ref),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: AppTheme.crimson,
                    ),
                    Gap.m,
                    Expanded(
                      child: Text(
                        'A hike is still open. Tap to pick it up.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textFaint),
                  ],
                ),
              ),
              Gap.m,
            ],
            _Totals(hikes: list, today: ref.watch(todayProvider)),
            Gap.m,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startHike(context, ref),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.hiking_rounded),
                label: const Text('Start a hike'),
              ),
            ),
            if (list.isEmpty)
              const EmptyState(
                icon: Icons.terrain_outlined,
                title: 'No hikes yet',
                body:
                    'Start one here, or from Sunday in the session runner. '
                    'Afterwards the trail stands on the hills it crossed, '
                    'in 3D, with the climb and the profile.',
              )
            else ...[
              const SectionHeader('Every hike'),
              for (var i = 0; i < list.length; i++) ...[
                FadeSlideIn(
                  index: i,
                  child: _HikeTile(hike: list[i]),
                ),
                Gap.s,
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startHike(BuildContext context, WidgetRef ref) async {
    await context.push<bool>('/track', extra: RunLaunch.hike());
    ref
      ..invalidate(openRunProvider)
      ..invalidate(finishedHikesProvider);
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.hikes, required this.today});

  final List<Run> hikes;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final month = hikes.where(
      (r) => r.runOn.year == today.year && r.runOn.month == today.month,
    );
    double km(Iterable<Run> rs) =>
        rs.fold<double>(0, (a, r) => a + r.distanceM) / 1000;
    final climb = hikes.fold<double>(0, (a, r) => a + (r.elevGainM ?? 0));
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: DateFormat('MMMM').format(today),
              value: km(month),
              decimals: 1,
              unit: 'km',
              caption: '${month.length} hike${month.length == 1 ? '' : 's'}',
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'All time',
              value: km(hikes),
              decimals: 1,
              unit: 'km',
              caption: '▲ ${climb.round()} m climbed',
            ),
          ),
        ],
      ),
    );
  }
}

class _HikeTile extends ConsumerWidget {
  const _HikeTile({required this.hike});

  final Run hike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final track = ref.watch(runTrackProvider(hike.id)).asData?.value;
    final started = DateTime.fromMillisecondsSinceEpoch(hike.startedAtMs);
    final title = runTitle(started, kind: RunKind.hike);
    final profile = track?.elevationProfile() ?? const <ElevationSample>[];

    Widget figure(String label, String value, [String? unit]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.overline.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTheme.numeric(22)),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: t.labelMedium!.copyWith(color: AppTheme.textDim),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/progress/hikes/${hike.id}'),
      semanticLabel:
          '$title on ${DateFormat('d MMMM').format(hike.runOn)}, '
          '${formatKm(hike.distanceM)} kilometres, '
          '${(hike.elevGainM ?? 0).round()} metres climbed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      Text(
                        DateFormat('EEE d MMM · HH:mm').format(started),
                        style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textFaint),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: figure('Distance', formatKm(hike.distanceM), 'km'),
                ),
                Expanded(
                  child: figure(
                    '▲ Climb',
                    '${(hike.elevGainM ?? 0).round()}',
                    'm',
                  ),
                ),
                Expanded(child: figure('Time', formatClock(hike.movingMs))),
              ],
            ),
          ),
          Container(
            height: 110,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF121216), Color(0xFF0C0C0F)],
              ),
              border: Border(top: BorderSide(color: AppTheme.outlineSoft)),
            ),
            child: track == null
                ? null
                : profile.length > 2
                ? CustomPaint(painter: _SilhouettePainter(profile))
                : CustomPaint(
                    painter: RouteLinePainter([
                      for (final s in track.segments)
                        [for (final f in s) f.point],
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The hike's profile as a ridge line across the bottom of its card.
class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.profile);

  final List<ElevationSample> profile;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = profile.map((e) => e.altitudeM).reduce(math.min);
    final hi = profile.map((e) => e.altitudeM).reduce(math.max);
    final span = math.max(30.0, hi - lo);
    final d0 = profile.first.distanceM;
    final dist = math.max(1.0, profile.last.distanceM - d0);
    const pad = 14.0;
    double x(double d) => pad + (size.width - 2 * pad) * (d - d0) / dist;
    double y(double a) =>
        size.height - 10 - (size.height - 30) * (a - lo) / span;
    final line = Path();
    final fill = Path()..moveTo(x(d0), size.height);
    for (var i = 0; i < profile.length; i++) {
      final p = Offset(x(profile[i].distanceM), y(profile[i].altitudeM));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(x(profile.last.distanceM), size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()..color = AppTheme.textDim.withValues(alpha: 0.14),
      )
      ..drawPath(
        line,
        Paint()
          ..color = AppTheme.crimson
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.profile != profile;
}
