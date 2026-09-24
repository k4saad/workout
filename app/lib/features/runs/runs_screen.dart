import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/exercise_providers.dart';
import '../../app/providers.dart';
import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../domain/run/run.dart';
import 'run_summary.dart';

/// Every run, newest first, and the way to start a free one.
class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(finishedRunsProvider);
    final open = ref.watch(openRunProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Runs')),
      body: runs.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView(
          padding: Gap.pagePadding,
          children: [
            if (open != null) ...[
              AppCard(
                accent: AppTheme.crimson,
                onTap: () => _startRun(context, ref),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: AppTheme.crimson,
                    ),
                    Gap.m,
                    Expanded(
                      child: Text(
                        'A run is still open. Tap to pick it up.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textFaint),
                  ],
                ),
              ),
              Gap.m,
            ],
            _Totals(runs: list, today: ref.watch(todayProvider)),
            Gap.m,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startRun(context, ref),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.directions_run_rounded),
                label: const Text('Start a free run'),
              ),
            ),
            if (list.isEmpty)
              const EmptyState(
                icon: Icons.route_outlined,
                title: 'No runs yet',
                body:
                    'The programme\'s runs start from their day in the session '
                    'runner. A free run starts here. Either way the trail, '
                    'the splits and the pace land on this page.',
              )
            else ...[
              const SectionHeader('Every run'),
              for (var i = 0; i < list.length; i++) ...[
                FadeSlideIn(
                  index: i,
                  child: _RunTile(run: list[i]),
                ),
                Gap.s,
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startRun(BuildContext context, WidgetRef ref) async {
    await context.push<bool>('/track');
    ref
      ..invalidate(openRunProvider)
      ..invalidate(finishedRunsProvider);
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.runs, required this.today});

  final List<Run> runs;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final now = today;
    final month = runs.where(
      (r) => r.runOn.year == now.year && r.runOn.month == now.month,
    );
    final monthKm = month.fold<double>(0, (a, r) => a + r.distanceM) / 1000;
    final allKm = runs.fold<double>(0, (a, r) => a + r.distanceM) / 1000;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: DateFormat('MMMM').format(now),
              value: monthKm,
              decimals: 1,
              unit: 'km',
              caption: '${month.length} run${month.length == 1 ? '' : 's'}',
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'All time',
              value: allKm,
              decimals: 1,
              unit: 'km',
              caption: '${runs.length} run${runs.length == 1 ? '' : 's'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.run});

  final Run run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final track = ref.watch(runTrackProvider(run.id)).asData?.value;
    final pace = run.distanceM < 10 || run.movingMs <= 0
        ? null
        : (run.movingMs / 1000) / (run.distanceM / 1000);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.go('/progress/runs/${run.id}'),
      semanticLabel:
          'Run on ${DateFormat('d MMMM').format(run.runOn)}, '
          '${formatKm(run.distanceM)} kilometres',
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: track == null
                ? null
                : CustomPaint(painter: TrailThumbPainter(track.segments)),
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE d MMM').format(run.runOn),
                  style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatKm(run.distanceM), style: AppTheme.numeric(26)),
                    const SizedBox(width: 3),
                    Text(
                      'km',
                      style: t.labelLarge!.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
                Text(
                  '${formatClock(run.movingMs)} · ${formatPace(pace)} /km'
                  '${run.exerciseId == null ? '' : ' · programme'}',
                  style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textFaint),
        ],
      ),
    );
  }
}

/// One run, read back.
class RunDetailScreen extends ConsumerWidget {
  const RunDetailScreen({super.key, required this.runId});

  final int runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runProvider(runId)).asData?.value;
    final track = ref.watch(runTrackProvider(runId)).asData?.value;
    final library = ref.watch(libraryProvider).asData?.value;
    if (run == null || track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Run')),
        body: const SkeletonPage(),
      );
    }
    final repo = ref.read(runRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMMM').format(run.runOn)),
        actions: [
          IconButton(
            tooltip: 'Delete this run',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Delete this run?'),
                  content: const Text(
                    'The trail and its numbers go for good. A set it was '
                    'logged as stays in the session.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep it'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (sure != true) return;
              await repo.discard(runId);
              ref.invalidate(finishedRunsProvider);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: RunSummaryView(
        run: run,
        track: track,
        exerciseName: run.exerciseId == null
            ? null
            : library?.resolve(run.exerciseId!).name,
        onEffort: (e) async {
          await repo.setEffort(runId, e);
          ref.invalidate(runProvider(runId));
        },
      ),
    );
  }
}

/// A run's shape, drawn without a map: good enough to tell one route from
/// another in a list, and no tile fetched for it.
class TrailThumbPainter extends CustomPainter {
  TrailThumbPainter(this.segments);

  final List<List<RunFix>> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final s in segments) ...s];
    if (pts.length < 2) return;
    var minLat = pts.first.lat, maxLat = minLat;
    var minLng = pts.first.lng, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // Longitude degrees shrink with latitude; scale so the shape is true.
    final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max(1e-9, (maxLng - minLng) * k);
    final h = math.max(1e-9, maxLat - minLat);
    const pad = 8.0;
    final s = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final ox = (size.width - w * s) / 2;
    final oy = (size.height - h * s) / 2;
    Offset o(RunFix p) =>
        Offset(ox + (p.lng - minLng) * k * s, oy + (maxLat - p.lat) * s);

    final paint = Paint()
      ..color = AppTheme.crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final seg in segments) {
      if (seg.length < 2) continue;
      final path = Path()..moveTo(o(seg.first).dx, o(seg.first).dy);
      for (final p in seg.skip(1)) {
        path.lineTo(o(p).dx, o(p).dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(o(pts.first), 3, Paint()..color = AppTheme.text);
  }

  @override
  bool shouldRepaint(TrailThumbPainter old) => old.segments != segments;
}
