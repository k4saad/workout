import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/calendar/programme_calendar.dart';
import '../../domain/models/enums.dart';
import '../common/widgets.dart';

/// Seven day cards for one programme week, with paging.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleProvider);
    final week = ref.watch(viewedWeekProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.today_outlined),
          tooltip: 'Today',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Week'),
      ),
      body: async.when(
        loading: () => const AsyncScaffoldBody(
          loading: true,
          error: null,
          child: SizedBox(),
        ),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (b) {
          final block = b.programme.blockForWeek(week);
          final days = b.calendar.weekOf(week);
          final todayWeek = b.calendar.weekNumberFor(today);

          return Column(
            children: [
              _WeekBar(
                week: week,
                total: b.programme.totalWeeks,
                blockName: block?.name ?? '',
                onPrev: week > 1
                    ? () => ref
                          .read(selectedWeekProvider.notifier)
                          .select(week - 1)
                    : null,
                onNext: week < b.programme.totalWeeks
                    ? () => ref
                          .read(selectedWeekProvider.notifier)
                          .select(week + 1)
                    : null,
              ),
              if (block?.blockKind == BlockKind.deload)
                const _BlockBanner(
                  icon: Icons.self_improvement,
                  color: AppTheme.dusk,
                  title: 'Deload week',
                  body:
                      'Seventy per cent of the load, sixty per cent of the '
                      'sets, supersets unwound. You will want to skip this '
                      'week. Don’t — it is the week the previous '
                      'three turn into muscle.',
                ),
              if (block?.blockKind == BlockKind.test)
                const _BlockBanner(
                  icon: Icons.emoji_events_outlined,
                  color: AppTheme.good,
                  title: 'Test week',
                  body:
                      'Work up to one hard set of five. Hard means the last '
                      'rep grinds but the bar moves and the shape holds — '
                      'not a failed rep, not a maximal single. You train alone.',
                ),
              Expanded(
                child: ListView.separated(
                  padding: Gap.pagePadding,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => Gap.m,
                  itemBuilder: (context, i) => _DayCard(
                    planned: days[i],
                    week: week,
                    isToday: days[i].date == today && week == todayWeek,
                    libraryLength: b.library.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.total,
    required this.blockName,
    this.onPrev,
    this.onNext,
  });

  final int week;
  final int total;
  final String blockName;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            iconSize: 30,
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
          ),
          Expanded(
            child: Column(
              children: [
                Text('Week $week of $total', style: t.titleLarge),
                if (blockName.isNotEmpty)
                  Text(
                    blockName,
                    style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                  ),
              ],
            ),
          ),
          IconButton(
            iconSize: 30,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
          ),
        ],
      ),
    );
  }
}

class _BlockBanner extends StatelessWidget {
  const _BlockBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium?.copyWith(color: color)),
                Gap.xs,
                Text(body, style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.planned,
    required this.week,
    required this.isToday,
    required this.libraryLength,
  });

  final PlannedDay planned;
  final int week;
  final bool isToday;
  final int libraryLength;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final day = planned.day;
    final label = DateFormat('EEE d').format(planned.date);

    if (day == null) {
      return Opacity(
        opacity: 0.45,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(width: 68, child: Text(label, style: t.titleMedium)),
                Text(
                  '— not scheduled',
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isToday ? AppTheme.oxblood : AppTheme.outline,
          width: isToday ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: day.isTrainingDay
            ? () => context.go('/week/$week/day/${day.id}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: t.labelLarge?.copyWith(
                        color: isToday ? AppTheme.oxblood : AppTheme.textDim,
                      ),
                    ),
                    if (isToday)
                      Text(
                        'TODAY',
                        style: t.labelLarge?.copyWith(
                          fontSize: 11,
                          color: AppTheme.oxblood,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KindRail(kind: day.kind, optional: day.optional),
                    Gap.s,
                    Row(
                      children: [
                        // Glyph carries the kind, never colour alone.
                        Text(
                          AppTheme.glyphForKind(day.kind),
                          style: TextStyle(
                            color: AppTheme.forKind(day.kind),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(day.title, style: t.titleMedium)),
                      ],
                    ),
                    if (day.isTrainingDay) ...[
                      Gap.s,
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (day.estMinutes > 0)
                            InfoChip(label: '${day.estMinutes} min'),
                          if (day.totalWorkingSets > 0)
                            InfoChip(label: '${day.totalWorkingSets} sets'),
                          if (day.optional) const InfoChip(label: 'optional'),
                          if (day.warnings.isNotEmpty)
                            const InfoChip(
                              label: 'read first',
                              icon: Icons.warning_amber_rounded,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (day.isTrainingDay)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right, color: AppTheme.textDim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
