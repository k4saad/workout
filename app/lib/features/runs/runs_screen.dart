import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/exercise_providers.dart';
import '../../app/providers.dart';
import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../domain/run/run.dart';
import 'hike_summary.dart';
import 'live_run_screen.dart';
import 'run_share_card.dart';
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
            if (open != null && open.kind == RunKind.run) ...[
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
    await context.push<bool>('/track', extra: const RunLaunch());
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
    final library = ref.watch(libraryProvider).asData?.value;
    final started = DateTime.fromMillisecondsSinceEpoch(run.startedAtMs);
    final pace = run.distanceM < 10 || run.movingMs <= 0
        ? null
        : (run.movingMs / 1000) / (run.distanceM / 1000);
    final kind = run.exerciseId == null
        ? 'Free run'
        : library?.resolve(run.exerciseId!).name ?? 'Programme run';

    Widget figure(String label, String value, [String? unit]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.overline.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        // Shrinks rather than overflows: "12:05 /km" at a large text size
        // in a third of a small phone.
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
      onTap: () => context.go('/progress/runs/${run.id}'),
      semanticLabel:
          '${runTitle(started, kind: run.kind)} on ${DateFormat('d MMMM').format(run.runOn)}, '
          '${formatKm(run.distanceM)} kilometres',
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
                      Text(
                        runTitle(started, kind: run.kind),
                        style: t.titleMedium,
                      ),
                      Text(
                        '${DateFormat('EEE d MMM · HH:mm').format(started)}'
                        ' · $kind',
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
                  child: figure('Distance', formatKm(run.distanceM), 'km'),
                ),
                Expanded(child: figure('Pace', formatPace(pace), '/km')),
                Expanded(child: figure('Time', formatClock(run.movingMs))),
              ],
            ),
          ),
          Container(
            height: 150,
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

/// One run, or one hike, read back.
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
        appBar: AppBar(title: const SizedBox.shrink()),
        body: const SkeletonPage(),
      );
    }
    final hike = run.kind == RunKind.hike;
    final noun = hike ? 'hike' : 'run';
    final repo = ref.read(runRepositoryProvider);
    final exerciseName = run.exerciseId == null
        ? null
        : library?.resolve(run.exerciseId!).name;
    void share() => showRunShareSheet(
      context,
      run: run,
      track: track,
      exerciseName: exerciseName,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMMM').format(run.runOn)),
        actions: [
          IconButton(
            tooltip: 'Share as an image',
            icon: const Icon(Icons.ios_share),
            onPressed: share,
          ),
          IconButton(
            tooltip: 'Delete this $noun',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: Text('Delete this $noun?'),
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
              ref
                ..invalidate(finishedRunsProvider)
                ..invalidate(finishedHikesProvider);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: hike
          ? HikeSummaryView(
              run: run,
              track: track,
              onShare: share,
              exerciseName: exerciseName,
              onEffort: (e) async {
                await repo.setEffort(runId, e);
                ref.invalidate(runProvider(runId));
              },
            )
          : RunSummaryView(
              run: run,
              track: track,
              onShare: share,
              exerciseName: exerciseName,
              onEffort: (e) async {
                await repo.setEffort(runId, e);
                ref.invalidate(runProvider(runId));
              },
            ),
    );
  }
}
