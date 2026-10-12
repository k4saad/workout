import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/planner_providers.dart';
import '../../../app/providers.dart';
import '../../../core/ui/ui.dart';
import '../../../domain/planner/planner.dart';
import '../../planner/planner_style.dart';

/// What the rest of today holds, from the planner: what he is in now, and
/// the next few things — so a glance between sets says when to leave.
class YourDayCard extends ConsumerWidget {
  const YourDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final plan = ref.watch(dayPlanProvider(today)).asData?.value;
    if (plan == null) return const SizedBox.shrink();

    // The live minute on the real today; the whole day on any other.
    final clock = DateTime.now();
    final isNow =
        clock.year == today.year &&
        clock.month == today.month &&
        clock.day == today.day;
    final minute = isNow ? clock.hour * 60 + clock.minute : 0;
    final (now, _) = plan.nowAndNext(minute);
    final upcoming = [
      for (final i in plan.items)
        if (i.kind != PlanKind.travel && i.start >= minute && i != now) i,
    ].take(4).toList();

    String line(PlanItem i) => [
      formatHhmm(i.start),
      i.title,
      if (i.room != null) i.room!,
      if (i.packed) 'packed',
      if (i.kind == PlanKind.job) 'leave ${formatHhmm(i.start - 30)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        onTap: () => context.go('/week/planner'),
        semanticLabel: 'Your day, in the planner',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('YOUR DAY', style: AppTheme.overline),
                const Spacer(),
                Text(
                  'Planner',
                  style: t.labelLarge!.copyWith(color: AppTheme.textDim),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textFaint),
              ],
            ),
            if (now != null) ...[
              Gap.s,
              Row(
                children: [
                  Icon(plannerIcon(now), color: plannerColour(now.kind)),
                  Gap.s,
                  Expanded(
                    child: Text(
                      'Now · ${now.title} · until ${formatHhmm(now.end)}',
                      style: t.titleSmall,
                    ),
                  ),
                ],
              ),
            ],
            Gap.s,
            if (upcoming.isEmpty)
              Text(
                plan.items.isEmpty
                    ? 'Nothing planned today.'
                    : 'Nothing more today.',
                style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
              )
            else
              for (final i in upcoming)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        plannerIcon(i),
                        size: 18,
                        color: i.kind == PlanKind.session || i.sessionFuel
                            ? AppTheme.crimson
                            : AppTheme.textDim,
                      ),
                      Gap.s,
                      Expanded(
                        child: Text(
                          line(i),
                          style:
                              (i.kind == PlanKind.meal
                                      ? t.bodySmall
                                      : t.bodyMedium)!
                                  .copyWith(
                                    color: i.kind == PlanKind.meal
                                        ? AppTheme.textDim
                                        : AppTheme.text,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
