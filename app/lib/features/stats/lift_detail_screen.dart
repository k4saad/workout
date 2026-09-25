import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/session_providers.dart';
import '../../app/stats_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/stats_service.dart';
import '../common/widgets.dart';
import 'widgets/e1rm_chart.dart';

/// One lift, everything known about it.
class LiftDetailScreen extends ConsumerWidget {
  const LiftDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(liftSummaryProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(title: Text(async.asData?.value.name ?? 'Lift')),
      body: async.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (summary) => ListView(
          padding: Gap.pagePadding,
          children: [
            _Headline(summary: summary),
            Gap.l,

            Text('Estimated max', style: t.titleLarge),
            Gap.xs,
            Text(
              'Epley, from your best working set each day. It is an '
              'ESTIMATE — you have never lifted this number, and above about '
              'eight reps the formula flatters you.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            SizedBox(height: 190, child: E1rmChart(points: summary.trend)),

            Gap.xl,
            _History(exerciseId: exerciseId),
            Gap.xl,
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.summary});

  final LiftSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final change = summary.changeFraction;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.best != null) ...[
            Text('Best set', style: t.labelLarge),
            Gap.xs,
            Text(summary.best!.setLabel, style: t.headlineSmall),
            Text(
              '${DateFormat('d MMMM').format(summary.best!.date)} · '
              'about ${summary.best!.e1rmKg.toStringAsFixed(1)} kg max '
              '(estimated)',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ] else
            Text(
              'No loaded sets yet — this movement is logged by reps or '
              'time, so there is no weight to estimate from.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(label: '${summary.workingSets} working sets'),
              if (summary.tonnageKg > 0)
                InfoChip(
                  label:
                      '${(summary.tonnageKg / 1000).toStringAsFixed(1)} t '
                      'lifted',
                ),
              if (change != null)
                InfoChip(
                  label:
                      '${change >= 0 ? '+' : ''}${(change * 100).round()}% '
                      'since session one',
                  emphasis: change >= 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<SetLog>>(
      future: db.historyForExercise(exerciseId),
      builder: (context, snap) {
        final rows = snap.data ?? const <SetLog>[];
        if (rows.isEmpty) {
          return Text(
            'Nothing logged yet.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          );
        }

        // Newest first, grouped by the day they were performed.
        final byDay = <DateTime, List<SetLog>>{};
        for (final r in rows) {
          final day = DateTime(
            r.completedAt.year,
            r.completedAt.month,
            r.completedAt.day,
          );
          (byDay[day] ??= []).add(r);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Every set', style: t.titleLarge),
            Gap.s,
            for (final day in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE d MMMM').format(day),
                      style: t.titleMedium,
                    ),
                    Gap.xs,
                    Text(
                      byDay[day]!.map(_setLabel).join('   ·   '),
                      style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _setLabel(SetLog l) {
    final reps = l.reps ?? l.durationSec ?? 0;
    final unit = l.reps != null ? '' : 's';
    final load = l.loadKg == null
        ? ''
        : ' @ ${l.loadKg == l.loadKg!.roundToDouble() ? l.loadKg!.toStringAsFixed(0) : l.loadKg}';
    final rir = l.rir == null ? '' : ' (RIR ${l.rir})';
    return '$reps$unit$load$rir';
  }
}
