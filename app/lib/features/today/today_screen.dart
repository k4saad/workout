import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/body_providers.dart';
import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../app/quote_providers.dart';
import '../../app/run_providers.dart';
import '../../app/session_providers.dart';
import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/tables.dart' show RunKind;
import '../../domain/calendar/adherence.dart';
import '../../domain/calendar/programme_calendar.dart';
import '../../domain/content/quotes.dart';
import '../../domain/models/day.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/programme.dart';
import '../body/body_screen.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/day_sheet.dart';
import '../common/widgets.dart';
import '../progress/checkpoint_checklist.dart';
import '../runs/live_run_screen.dart' show RunLaunch;
import 'widgets/backup_nag.dart';
import 'widgets/next_meal_card.dart';
import 'widgets/upgrade_notice.dart';
import 'widgets/your_day_card.dart';

/// The day, in the order it is lived: what to train, a line to take into
/// it, what to eat next, the scale, and where the week stands.
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
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (b) {
          final planned = b.calendar.forDate(today);
          final active = planned.status == ProgrammeStatus.active;
          final week = planned.weekNo;
          final checkpoint = week == null
              ? null
              : b.programme.checkpointForWeek(week);
          final cardio = week == null ? null : b.programme.cardioForWeek(week);

          return ListView(
            padding: Gap.pagePadding,
            children: [
              _Greeting(
                date: today,
                planned: planned,
                totalWeeks: b.programme.totalWeeks,
              ),
              const _ResumeBanner(),
              const _OpenRunBanner(),
              BackupNag(
                hasTrainingData:
                    (ref.watch(completedSessionCountProvider).asData?.value ??
                        0) >
                    0,
              ),
              const UpgradeNotice(),
              Gap.l,
              FadeSlideIn(
                child: switch (planned.status) {
                  ProgrammeStatus.before => _BeforeCard(programme: b.programme),
                  ProgrammeStatus.complete => _CompleteCard(
                    programme: b.programme,
                  ),
                  ProgrammeStatus.active => _DayCard(
                    planned: planned,
                    programme: b.programme,
                    next: b.calendar.nextSession(today),
                  ),
                },
              ),
              if (active) const YourDayCard(),
              const _QuoteCard(),
              if (active)
                // The plan he has to go and look for is the plan he stops
                // following in week three.
                const NextMealCard(),
              Gap.m,
              const _WeighInCard(),
              if (active && week != null) ...[
                Gap.m,
                _WeekStrip(week: week, today: today),
              ],
              if (active && checkpoint != null) ...[
                Gap.m,
                _CheckpointCard(checkpoint: checkpoint),
              ],
              if (active && cardio != null && cardio.longRunLabel != null) ...[
                Gap.m,
                _MiniCard(
                  icon: Icons.directions_run,
                  title: 'Cardio this week',
                  lines: [
                    if (cardio.longRunLabel != null)
                      'Sunday run · ${cardio.longRunLabel}',
                    if (cardio.skipping != null)
                      'Skipping · ${cardio.skipping}',
                    if (cardio.bag != null) 'Bag · ${cardio.bag}',
                    if (cardio.note != null) cardio.note!,
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Good morning, by name, and where the day sits in the programme.
class _Greeting extends ConsumerWidget {
  const _Greeting({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name =
        ref.watch(preferencesProvider).asData?.value.athleteName ?? 'Saad';
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$part, $name.', style: t.headlineSmall),
        Gap.xs,
        Text(
          DateFormat('EEEE d MMMM').format(date).toUpperCase(),
          style: AppTheme.overline,
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

/// A session the app was killed during. You should never lose one because
/// the phone reclaimed memory between sets.
class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumable = ref.watch(resumableSessionProvider).asData?.value;
    if (resumable == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ToneBanner(
        tone: Tone.accent,
        icon: Icons.play_circle_outline,
        title: 'Session in progress',
        body: 'Week ${resumable.weekNo}. Pick it up where you left it.',
        onTap: () => context.push(
          sessionRunPath(resumable, today: ref.read(todayProvider)),
        ),
      ),
    );
  }
}

/// A run the app was killed or closed during. It is still open in the
/// database; the tracker picks it up as a new stretch of trail.
class _OpenRunBanner extends ConsumerWidget {
  const _OpenRunBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openRunProvider).asData?.value;
    if (open == null) return const SizedBox.shrink();
    final hike = open.kind == RunKind.hike;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ToneBanner(
        tone: Tone.accent,
        icon: hike ? Icons.hiking_rounded : Icons.route_rounded,
        title: hike ? 'Hike still open' : 'Run still open',
        body: 'Pick it up where the trail stopped, or finish it.',
        onTap: () async {
          await context.push<bool>(
            '/track',
            extra: hike ? const RunLaunch.hike() : const RunLaunch(),
          );
          ref.invalidate(openRunProvider);
        },
      ),
    );
  }
}

/// Today's session: the one thing on the screen, until it is done.
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.planned,
    required this.programme,
    required this.next,
  });

  final PlannedDay planned;
  final Programme programme;

  /// The next required session, which a rest day names.
  final PlannedDay? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = planned.day;
    final today = ref.watch(todayProvider);
    final week = planned.weekNo!;

    if (day == null) {
      return AppCard(
        child: Text(
          'Nothing scheduled today. The programme starts '
          '${DateFormat('EEEE d MMMM').format(programme.startDate)}.',
          style: t.bodyLarge,
        ),
      );
    }

    final entries = ref.watch(weekEntriesProvider(week)).asData?.value;
    final entry =
        entries?.where((e) => _sameDay(e.date, today)).firstOrNull ??
        CalendarEntry(planned: planned);
    final state = entry.state(today);
    void sheet() => showDaySheet(context, ref, entry);

    if (!day.isTrainingDay) {
      return AppCard(
        onTap: sheet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KindRail(kind: day.kind, optional: day.optional, height: 4),
            Gap.m,
            Text(day.title, style: t.headlineMedium),
            if (day.note != null) ...[
              Gap.s,
              Text(
                day.note!,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
            for (final r in entry.movedHere) ...[
              Gap.m,
              Text(
                '${EntryState.movedHere.glyph}  '
                '${DateFormat('EEEE').format(r.plannedDate)}’s session is '
                'here today',
                style: t.titleSmall,
              ),
            ],
            if (next case final n? when entry.movedHere.isEmpty) ...[
              Gap.m,
              Row(
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppTheme.textDim,
                  ),
                  Gap.s,
                  Expanded(
                    child: Text(
                      'Next: ${n.day!.title}, '
                      '${ProgrammeCalendar.daysBetween(today, n.date) == 1 ? 'tomorrow' : DateFormat('EEEE').format(n.date)}',
                      style: t.titleSmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Done, skipped or moved: say so, quietly. The hero is for what is
    // still to do.
    if (state != EntryState.none && state != EntryState.inProgress) {
      final moved = entry.movedAway.firstOrNull;
      return AppCard(
        onTap: sheet,
        accent: stateColour(state),
        child: Row(
          children: [
            Text(
              state.glyph,
              style: TextStyle(fontSize: 30, color: stateColour(state)),
            ),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.title, style: t.titleLarge),
                  Text(switch (state) {
                    EntryState.movedAway when moved != null =>
                      'Moved to '
                          '${DateFormat('EEEE d MMM').format(moved.scheduledDate)}',
                    EntryState.done => 'Done today. Eat, and sleep.',
                    EntryState.partial => 'Part done — it still counts.',
                    EntryState.skipped => 'Skipped today.',
                    _ => stateWord(state),
                  }, style: t.bodyMedium?.copyWith(color: AppTheme.textDim)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textDim),
          ],
        ),
      );
    }

    return _SessionHero(
      day: day,
      week: week,
      resuming: state == EntryState.inProgress,
    );
  }
}

/// The session still to do, in the crimson hero.
class _SessionHero extends StatelessWidget {
  const _SessionHero({
    required this.day,
    required this.week,
    required this.resuming,
  });

  final Day day;
  final int week;
  final bool resuming;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const white = Colors.white;
    final dim = white.withValues(alpha: 0.78);
    final facts = [
      '${AppTheme.glyphForKind(day.kind)} ${day.kind.name}',
      if (day.estMinutes > 0) '~${day.estMinutes} min',
      if (day.totalWorkingSets > 0) setsLabel(day.totalWorkingSets),
      if (day.optional) 'optional',
    ];
    return AppCard(
      hero: true,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resuming ? 'IN PROGRESS' : 'TODAY',
            style: AppTheme.overline.copyWith(color: dim),
          ),
          Gap.xs,
          Text(day.title, style: t.displaySmall!.copyWith(color: white)),
          Gap.s,
          Text(facts.join('  ·  '), style: t.titleSmall!.copyWith(color: dim)),
          if (day.note != null) ...[
            Gap.s,
            Text(day.note!, style: t.bodyMedium!.copyWith(color: dim)),
          ],
          Gap.l,
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: white,
                foregroundColor: AppTheme.crimsonDeep,
              ),
              onPressed: () => context.push('/run/$week/${day.id}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(resuming ? 'Resume session' : 'Start session'),
            ),
          ),
          Gap.xs,
          Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: white),
              onPressed: day.kind == DayKind.cardio
                  ? () => context.go('/more/cardio')
                  : () => context.go('/week/$week/day/${day.id}'),
              child: Text(
                day.kind == DayKind.cardio
                    ? 'Interval timers'
                    : 'Just show me the plan',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quote of the day, for a second look after the launch screen.
class _QuoteCard extends ConsumerWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(quoteOfDayProvider).asData?.value?.quote;
    if (quote == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: QuoteCard(quote: quote),
    );
  }
}

/// A quote, set in the serif, with exactly where it is from.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quote.text, style: AppTheme.serif(18, height: 1.45)),
          Gap.m,
          Row(
            children: [
              Container(width: 22, height: 2, color: AppTheme.crimson),
              Gap.s,
              Expanded(
                child: Text(
                  quote.attribution,
                  style: t.labelLarge!.copyWith(color: AppTheme.textDim),
                ),
              ),
            ],
          ),
          if (quote.translator != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                quote.translator!,
                style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

/// The scale, one tap from the home screen.
class _WeighInCard extends ConsumerWidget {
  const _WeighInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final entries = ref.watch(weightEntriesProvider).asData?.value;
    if (entries == null) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final todays = entries.where((e) => _sameDay(e.date, today)).firstOrNull;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onTap: () => context.go('/progress/body'),
      child: Row(
        children: [
          Icon(
            todays == null ? Icons.monitor_weight_outlined : Icons.check_circle,
            color: todays == null ? AppTheme.textDim : AppTheme.good,
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todays == null
                      ? 'Not weighed in yet'
                      : '${todays.kg.toStringAsFixed(1)} kg this morning',
                  style: t.titleMedium,
                ),
                if (entries.length >= 2)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: BodyweightSparkline(),
                  ),
              ],
            ),
          ),
          if (todays == null)
            FilledButton(
              onPressed: () => showWeighIn(context, ref),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              child: const Text('Weigh in'),
            ),
        ],
      ),
    );
  }
}

/// The week in seven marks: what is done, what is left, and today.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({required this.week, required this.today});

  final int week;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final entries = ref.watch(weekEntriesProvider(week)).asData?.value;
    if (entries == null) return const Skeleton(height: 96);
    final tally = SessionTally.of(entries, today);
    final streak = ref.watch(programmeAdherenceProvider).asData?.value;

    return AppCard(
      onTap: () => context.go('/week'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THIS WEEK', style: AppTheme.overline),
              Gap.s,
              // One text that can wrap: at a large text size the tally and
              // the streak ran off the card.
              Expanded(
                child: Text(
                  [
                    '${tally.done} of ${tally.required} done',
                    if (streak != null && streak.currentStreak > 1)
                      '${streak.currentStreak} in a row',
                  ].join(' · '),
                  textAlign: TextAlign.end,
                  style: t.labelLarge!.copyWith(color: AppTheme.textDim),
                ),
              ),
            ],
          ),
          Gap.m,
          Row(
            children: [
              for (final e in entries)
                Expanded(
                  child: _DayMark(entry: e, today: today),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({required this.entry, required this.today});

  final CalendarEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isToday = _sameDay(entry.date, today);
    final state = entry.state(today);
    final day = entry.planned.day;
    final glyph = state.glyph.isNotEmpty
        ? state.glyph
        : day == null
        ? ''
        : AppTheme.glyphForKind(day.kind);
    final colour = state.glyph.isNotEmpty
        ? stateColour(state)
        : day == null
        ? AppTheme.textFaint
        : AppTheme.forKind(day.kind).withValues(alpha: 0.7);
    return Column(
      children: [
        Text(
          DateFormat('EEEEE').format(entry.date),
          style: t.labelMedium!.copyWith(
            color: isToday ? AppTheme.crimson : AppTheme.textDim,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surfaceHigh,
            border: Border.all(
              color: isToday ? AppTheme.crimson : AppTheme.outlineSoft,
              width: isToday ? 2 : 1,
            ),
          ),
          child: Text(glyph, style: TextStyle(fontSize: 14, color: colour)),
        ),
      ],
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({required this.checkpoint});

  final Checkpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      accent: AppTheme.crimson,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.crimson),
              Gap.s,
              Expanded(
                child: Text(
                  'Week ${checkpoint.week} checkpoint',
                  style: t.titleLarge,
                ),
              ),
              CheckpointCount(week: checkpoint.week),
            ],
          ),
          Gap.s,
          CheckpointChecklist(checkpoint: checkpoint),
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
    return AppCard(
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
    );
  }
}

class _BeforeCard extends StatelessWidget {
  const _BeforeCard({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final firstWeek = programme.checkpointForWeek(1);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week 1 starts',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          Gap.xs,
          // The date, not a countdown. "In six days" is a number you have to
          // do arithmetic on to use; a date is one you can look at a
          // calendar and act on.
          Text(
            DateFormat('EEEE d MMMM').format(programme.startDate),
            style: t.headlineSmall,
          ),
          // What to do before then is the programme's own week-1
          // checkpoint, not copy typed here.
          if (firstWeek != null) ...[
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Before then',
                    style: t.titleSmall?.copyWith(color: AppTheme.textDim),
                  ),
                ),
                CheckpointCount(week: firstWeek.week),
              ],
            ),
            Gap.xs,
            CheckpointChecklist(checkpoint: firstWeek),
          ],
        ],
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
    return AppCard(
      accent: AppTheme.crimson,
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
    );
  }
}
