import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/body_providers.dart';
import '../../../app/calendar_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/metrics/bodyweight_trend.dart';
import '../../../domain/models/programme.dart';
import '../../body/widgets/trend_chart.dart';
import '../../common/widgets.dart';

/// Where you are, in four numbers, above the fold.
///
/// Week and block, how many sessions this week are done, the streak, and
/// whether bodyweight is actually moving. Everything here is one tap from
/// the screen that explains it.
class DashboardStrip extends ConsumerWidget {
  const DashboardStrip({
    super.key,
    required this.programme,
    required this.weekNo,
  });

  final Programme programme;
  final int weekNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final adherence = ref.watch(blockAdherenceProvider).asData?.value;
    final done = ref.watch(weekProgressProvider(weekNo)).asData?.value;
    final entries = ref.watch(weightEntriesProvider).asData?.value ?? [];

    final points = entries.isEmpty
        ? const <TrendPoint>[]
        : BodyweightTrend(
            windowDays: programme.nutritionRules.rollingAverageDays,
          ).points(entries);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The date header above already names the week and the block;
            // repeating it here would just cost a line of screen.
            Row(
              children: [
                Expanded(
                  child: done == null
                      ? const SizedBox(height: 8)
                      : _WeekBar(done: done.done, planned: done.planned),
                ),
                if (adherence != null && adherence.currentStreak > 0) ...[
                  const SizedBox(width: 10),
                  InfoChip(
                    label: '${adherence.currentStreak} in a row',
                    icon: Icons.local_fire_department_outlined,
                    emphasis: true,
                  ),
                ],
              ],
            ),
            Gap.s,
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/body'),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 46,
                      child: points.length < 2
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Weigh in to start the trend',
                                style: t.bodyMedium?.copyWith(
                                  color: AppTheme.textDim,
                                ),
                              ),
                            )
                          : TrendChart(points: points, compact: true),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (points.isNotEmpty)
                  Text(
                    '${points.last.average.toStringAsFixed(1)} kg',
                    style: t.titleMedium,
                  ),
                IconButton(
                  tooltip: 'Numbers',
                  icon: const Icon(Icons.insights_outlined),
                  onPressed: () => context.go('/stats'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.done, required this.planned});

  final int done;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fraction = planned == 0 ? 0.0 : (done / planned).clamp(0.0, 1.0);
    final complete = planned > 0 && done >= planned;

    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            complete ? '✓' : '·',
            style: t.bodyMedium?.copyWith(
              color: complete ? AppTheme.good : AppTheme.textDim,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                complete ? AppTheme.good : AppTheme.oxblood,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$done / $planned',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }
}
