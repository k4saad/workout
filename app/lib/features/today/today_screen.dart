import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/calendar/programme_calendar.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import 'widgets/backup_nag.dart';
import 'widgets/dashboard_strip.dart';

/// The home screen: what am I doing today, and is the rest of it on track.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Keller Twelve'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/history'),
          ),
        ],
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
          final planned = b.calendar.forDate(today);
          return ListView(
            padding: Gap.pagePadding,
            children: [
              _DateHeader(
                date: today,
                planned: planned,
                totalWeeks: b.programme.totalWeeks,
              ),
              const _ResumeBanner(),
              BackupNag(
                hasTrainingData:
                    (ref.watch(completedSessionCountProvider).asData?.value ??
                        0) >
                    0,
              ),
              if (planned.status == ProgrammeStatus.active &&
                  planned.weekNo != null) ...[
                Gap.m,
                DashboardStrip(programme: b.programme, weekNo: planned.weekNo!),
              ],
              Gap.l,
              switch (planned.status) {
                ProgrammeStatus.before => _BeforeCard(
                  programme: b.programme,
                  calendar: b.calendar,
                ),
                ProgrammeStatus.complete => _CompleteCard(
                  programme: b.programme,
                ),
                ProgrammeStatus.active => _ActiveBody(
                  planned: planned,
                  bundle: b,
                  ref: ref,
                ),
              },
              if (!b.inventory.isCalibrated) ...[
                Gap.l,
                const _CalibrationNag(),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A session the app was killed during. You should never lose one because
/// the phone reclaimed memory between sets.
class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumable = ref.watch(resumableSessionProvider).asData?.value;
    if (resumable == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.oxblood.withValues(alpha: 0.15),
          border: Border.all(color: AppTheme.oxblood),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppTheme.oxblood),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session in progress', style: t.titleMedium),
                  Text(
                    'Week ${resumable.weekNo} · ${resumable.dayId}',
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () =>
                  context.push('/run/${resumable.weekNo}/${resumable.dayId}'),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.planned,
    required this.totalWeeks,
  });

  final DateTime date;
  final PlannedDay planned;

  /// From the programme. Twelve weeks is this cycle's length, not a fact
  /// about the app — cycle 2 is eight.
  final int totalWeeks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE d MMMM').format(date).toUpperCase(),
          style: t.labelLarge?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 1.1,
          ),
        ),
        if (planned.weekNo != null && planned.block != null) ...[
          Gap.xs,
          Text(
            'Week ${planned.weekNo} of $totalWeeks · ${planned.block!.name}',
            style: t.titleMedium?.copyWith(color: AppTheme.textDim),
          ),
        ],
      ],
    );
  }
}

class _ActiveBody extends StatelessWidget {
  const _ActiveBody({
    required this.planned,
    required this.bundle,
    required this.ref,
  });

  final PlannedDay planned;
  final ProgrammeBundle bundle;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final day = planned.day;

    if (day == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Nothing scheduled today. The programme starts '
            '${DateFormat('EEEE d MMMM').format(bundle.programme.startDate)}.',
            style: t.bodyLarge,
          ),
        ),
      );
    }

    final week = planned.weekNo!;
    final checkpoint = bundle.programme.checkpointForWeek(week);
    final nutrition = bundle.programme.nutritionForWeek(week);
    final cardio = bundle.programme.cardioForWeek(week);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/week/$week/day/${day.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KindRail(kind: day.kind, optional: day.optional, height: 4),
                  Gap.m,
                  Text(day.title, style: t.displaySmall),
                  Gap.s,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(
                        label:
                            '${AppTheme.glyphForKind(day.kind)} ${day.kind.name}',
                      ),
                      if (day.estMinutes > 0)
                        InfoChip(
                          label: '~${day.estMinutes} min',
                          icon: Icons.schedule_outlined,
                        ),
                      if (day.totalWorkingSets > 0)
                        InfoChip(label: '${day.totalWorkingSets} sets'),
                      if (day.optional) const InfoChip(label: 'optional'),
                    ],
                  ),
                  if (day.note != null) ...[
                    Gap.m,
                    Text(
                      day.note!,
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                  if (day.isTrainingDay) ...[
                    Gap.m,
                    FilledButton.icon(
                      onPressed: () => context.push('/run/$week/${day.id}'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start session'),
                    ),
                    Gap.s,
                    if (day.kind == DayKind.cardio)
                      OutlinedButton.icon(
                        onPressed: () => context.go('/more/cardio'),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Interval timers'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () =>
                            context.go('/week/$week/day/${day.id}'),
                        child: const Text('Just show me the plan'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),

        if (checkpoint != null) ...[
          Gap.l,
          _CheckpointCard(week: week, items: checkpoint.items),
        ],

        if (cardio != null && cardio.longRunLabel != null) ...[
          Gap.l,
          _MiniCard(
            icon: Icons.directions_run,
            title: 'Cardio this week',
            lines: [
              if (cardio.longRunLabel != null)
                'Sunday run · ${cardio.longRunLabel}',
              if (cardio.skipping != null) 'Skipping · ${cardio.skipping}',
              if (cardio.bag != null) 'Bag · ${cardio.bag}',
              if (cardio.note != null) cardio.note!,
            ],
          ),
        ],

        if (nutrition != null) ...[
          Gap.l,
          _MiniCard(
            icon: Icons.restaurant,
            title: 'Eat today',
            lines: [
              '${nutrition.kcal} kcal · ${nutrition.proteinG} g protein',
              '${nutrition.carbsG} g carbs · ${nutrition.fatG} g fat',
              if (nutrition.note != null) nutrition.note!,
            ],
          ),
        ],
      ],
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({required this.week, required this.items});

  final int week;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.good.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.good.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppTheme.good),
              Gap.s,
              Expanded(
                child: Text(
                  'Week $week checkpoint',
                  style: t.titleLarge?.copyWith(color: AppTheme.good),
                ),
              ),
            ],
          ),
          Gap.s,
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.check_box_outline_blank,
                      size: 18,
                      color: AppTheme.textDim,
                    ),
                  ),
                  Expanded(child: Text(i, style: t.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.textDim),
                Gap.s,
                Expanded(child: Text(title, style: t.titleMedium)),
              ],
            ),
            Gap.s,
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  l,
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BeforeCard extends StatelessWidget {
  const _BeforeCard({required this.programme, required this.calendar});

  final Programme programme;
  final ProgrammeCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week 1 starts',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.xs,
            // The date, not a countdown. "In six days" is a number you have
            // to do arithmetic on to use; a date is one you can look at a
            // calendar and act on.
            Text(
              DateFormat('EEEE d MMMM').format(programme.startDate),
              style: t.headlineSmall,
            ),
            Gap.m,
            Text(
              'Before then: weigh both bars, count the plates, and take the '
              'four baseline photos — you cannot shoot week 1 later.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Twelve weeks, done.', style: t.headlineSmall),
            Gap.s,
            Text(
              'Your week-12 test numbers seed the next cycle. Foundation is '
              'skipped — you are not a beginner at these patterns any more.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.go('/more/settings/next-cycle'),
                icon: const Icon(Icons.auto_graph),
                label: const Text('Build the next cycle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Until the bars have been on a scale, every suggested load is a guess.
/// Say so rather than pretending.
class _CalibrationNag extends StatelessWidget {
  const _CalibrationNag();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.go('/more/settings/gym'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warn.withValues(alpha: 0.10),
          border: Border.all(color: AppTheme.warn.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.straighten, color: AppTheme.warn, size: 22),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bar weights are still estimates',
                    style: t.titleMedium?.copyWith(color: AppTheme.warn),
                  ),
                  Gap.xs,
                  Text(
                    'Every load below is computed from a guessed bar weight. '
                    'Put both bars on the bathroom scale and correct them — '
                    'it takes five minutes and it makes every number in this '
                    'app real. Tap to do it now.',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.warn),
          ],
        ),
      ),
    );
  }
}
