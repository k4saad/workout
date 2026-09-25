import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/stats_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/stats_service.dart';
import '../../domain/metrics/plate_gap.dart';
import '../../domain/metrics/volume_metrics.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import 'lift_detail_screen.dart';

/// What twelve weeks actually produced.
///
/// Every number here is read off `set_logs`, never off the programme, so it
/// survives every swap and every edit.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Numbers')),
      body: async.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (bundle) {
          final week = bundle.calendar.weekNumberFor(ref.watch(todayProvider));
          final clamped = week.clamp(1, bundle.programme.totalWeeks);
          return ListView(
            padding: Gap.pagePadding,
            children: [
              _WeekVolume(weekNo: clamped, programme: bundle.programme),
              Gap.l,
              const _DurationCard(),
              Gap.l,
              _PlateGapCard(library: bundle.library),
              Gap.l,
              _NiggleTimeline(library: bundle.library),
              Gap.l,
              _StrengthTargets(programme: bundle.programme),
              Gap.l,
              const _LiftList(),
              Gap.xl,
            ],
          );
        },
      ),
    );
  }
}

/// Weekly sets per muscle group — the number that actually drives growth.
class _WeekVolume extends ConsumerWidget {
  const _WeekVolume({required this.weekNo, required this.programme});

  final int weekNo;
  final Programme programme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final volumes = ref.watch(weeklyVolumeProvider(weekNo)).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Week $weekNo sets per muscle', style: t.titleLarge),
        Gap.xs,
        Text(
          'Direct sets only — a muscle that is merely along for the ride is '
          'not being trained. Below ${VolumeMetrics.lowSets} is maintenance; '
          'above ${VolumeMetrics.highSets} mostly buys fatigue.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
        Gap.m,
        if (volumes == null)
          const Skeleton(height: 160)
        else if (volumes.isEmpty)
          Text(
            'Nothing logged this week yet.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          )
        else
          for (final v in volumes) _VolumeRow(volume: v),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.volume});

  final MuscleVolume volume;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colour = volume.isInRange
        ? AppTheme.good
        : volume.isLow
        ? AppTheme.warn
        : AppTheme.oxblood;
    final fraction = (volume.directSets / VolumeMetrics.highSets).clamp(
      0.0,
      1.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              volume.glyph,
              style: t.bodyMedium?.copyWith(color: colour),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              volume.muscle,
              style: t.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(colour),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${volume.directSets}',
              textAlign: TextAlign.right,
              style: t.bodyLarge?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// Is sixty minutes real, or is it eighty?
class _DurationCard extends ConsumerWidget {
  const _DurationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final stats = ref.watch(sessionStatsProvider).asData?.value;
    if (stats == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stats.ceilingIsFiction
                    ? Icons.running_with_errors
                    : Icons.timer_outlined,
                size: 20,
                color: stats.ceilingIsFiction
                    ? AppTheme.warn
                    : AppTheme.textDim,
              ),
              const SizedBox(width: 8),
              Text('The hour', style: t.titleMedium),
            ],
          ),
          Gap.s,
          Text(stats.verdict, style: t.bodyMedium),
          if (!stats.isEmpty) ...[
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(label: 'median ${stats.medianMinutes} min'),
                InfoChip(label: 'longest ${stats.longestMinutes} min'),
                if (stats.medianOverrunMinutes != 0)
                  InfoChip(
                    label:
                        '${stats.medianOverrunMinutes > 0 ? '+' : ''}'
                        '${stats.medianOverrunMinutes} vs estimate',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sometimes you are not stalling — the smallest plate you own is too big.
class _PlateGapCard extends ConsumerWidget {
  const _PlateGapCard({required this.library});

  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final report = ref.watch(plateGapProvider).asData?.value;
    if (report == null || report.gaps.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plate gaps', style: t.titleMedium),
          Gap.xs,
          Text(
            report.isClean
                ? 'Every lift can take its next jump without a jolt.'
                : 'On these lifts the smallest jump your plates can make is '
                      'more than ${(PlateGapReport.coarseThreshold * 100).round()}% '
                      'of the bar. That is not a stall; it is arithmetic.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          for (final g in report.gaps.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      g.isCoarse ? '!' : '✓',
                      style: t.bodyMedium?.copyWith(
                        color: g.isCoarse ? AppTheme.warn : AppTheme.good,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      library.resolve(g.exerciseId).name,
                      style: t.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${g.percent}%',
                    style: t.bodyLarge?.copyWith(
                      color: g.isCoarse ? AppTheme.warn : AppTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),
          if (report.suggestedPlateKg != null) ...[
            Gap.m,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warn.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.warn.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Buy a pair of ${_plate(report.suggestedPlateKg!)} kg '
                'microplates. They are the cheapest training upgrade '
                'available to you, and they unblock every lift above.',
                style: t.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _plate(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : '$kg';
}

/// Which joints complained, when, and doing what.
class _NiggleTimeline extends ConsumerWidget {
  const _NiggleTimeline({required this.library});

  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final niggles = ref.watch(nigglesProvider).asData?.value ?? [];
    if (niggles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What hurt', style: t.titleLarge),
        Gap.xs,
        Text(
          'A pattern here matters more than any single entry. The same joint '
          'against the same movement three times is the movement, not you.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
        Gap.m,
        for (final n in niggles.take(12))
          _NiggleRow(niggle: n, library: library),
      ],
    );
  }
}

class _NiggleRow extends ConsumerWidget {
  const _NiggleRow({required this.niggle, required this.library});

  final Niggle niggle;
  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final resolved = niggle.resolvedOn != null;
    final colour = resolved
        ? AppTheme.good
        : niggle.severity >= 4
        ? AppTheme.oxblood
        : AppTheme.warn;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              resolved ? '✓' : '!',
              style: t.titleMedium?.copyWith(color: colour),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${niggle.site.name} · severity ${niggle.severity}/5',
                  style: t.titleMedium?.copyWith(color: colour),
                ),
                Text(
                  [
                    DateFormat('d MMM').format(niggle.loggedOn),
                    if (niggle.exerciseId != null)
                      library.resolve(niggle.exerciseId!).name,
                    if (resolved)
                      'cleared ${DateFormat('d MMM').format(niggle.resolvedOn!)}',
                  ].join(' · '),
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
                if (niggle.note != null)
                  Text(niggle.note!, style: t.bodyMedium),
              ],
            ),
          ),
          if (!resolved)
            TextButton(
              onPressed: () async {
                final stats = await ref.read(statsServiceProvider.future);
                await stats.resolveNiggle(niggle.id, DateTime.now());
                ref.invalidate(nigglesProvider);
              },
              child: const Text('Cleared'),
            ),
        ],
      ),
    );
  }
}

/// The programme's own projections, shown as floors rather than goals.
class _StrengthTargets extends ConsumerWidget {
  const _StrengthTargets({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    if (programme.strengthTargets.isEmpty) return const SizedBox.shrink();

    final summaries = ref.watch(liftSummariesProvider).asData?.value ?? [];
    final byId = {for (final s in summaries) s.exerciseId: s};
    final library = ref.watch(exerciseLibraryProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Against the projection', style: t.titleLarge),
        Gap.xs,
        Text(
          'These are FLOORS — what the programme\'s own increments produce if '
          'nothing goes wrong. Missing one is information, not failure.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
        Gap.m,
        for (final target in programme.strengthTargets)
          if (target.week12Kg != null)
            _TargetRow(
              // A target you have never trained still deserves its name.
              name:
                  library?.resolve(target.exerciseId).name ??
                  byId[target.exerciseId]?.name ??
                  target.exerciseId,
              targetKg: target.week12Kg!.last,
              achievedKg: byId[target.exerciseId]?.best?.weightKg,
              isFloor: target.isFloor,
            ),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.name,
    required this.targetKg,
    required this.achievedKg,
    required this.isFloor,
  });

  final String name;
  final double targetKg;
  final double? achievedKg;
  final bool isFloor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = achievedKg != null && achievedKg! >= targetKg;
    final fraction = achievedKg == null
        ? 0.0
        : (achievedKg! / targetKg).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  done ? '✓' : '·',
                  style: t.bodyMedium?.copyWith(
                    color: done ? AppTheme.good : AppTheme.textDim,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: t.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${achievedKg == null ? '—' : _kg(achievedKg!)} / '
                '${_kg(targetKg)} kg',
                style: t.bodyMedium?.copyWith(
                  color: done ? AppTheme.good : AppTheme.textDim,
                ),
              ),
            ],
          ),
          Gap.xs,
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: AppTheme.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                done ? AppTheme.good : AppTheme.oxblood,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _LiftList extends ConsumerWidget {
  const _LiftList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final summaries = ref.watch(liftSummariesProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Every lift', style: t.titleLarge),
        Gap.s,
        if (summaries == null)
          const Skeleton(height: 220)
        else if (summaries.isEmpty)
          Text(
            'Log a session and this fills up.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          )
        else
          for (final s in summaries) _LiftRow(summary: s),
      ],
    );
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.summary});

  final LiftSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final change = summary.changeFraction;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summary.name, style: t.titleMedium),
      subtitle: Text(
        [
          '${summary.workingSets} sets',
          if (summary.best != null) 'best ${summary.best!.setLabel}',
          if (summary.lastTrainedOn != null)
            DateFormat('d MMM').format(summary.lastTrainedOn!),
        ].join(' · '),
        style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
      ),
      trailing: change == null
          ? const Icon(Icons.chevron_right, color: AppTheme.textDim)
          : Text(
              '${change >= 0 ? '+' : ''}${(change * 100).round()}%',
              style: t.titleMedium?.copyWith(
                color: change >= 0 ? AppTheme.good : AppTheme.warn,
              ),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiftDetailScreen(exerciseId: summary.exerciseId),
        ),
      ),
    );
  }
}
