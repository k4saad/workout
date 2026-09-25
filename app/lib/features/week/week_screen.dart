import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:intl/intl.dart' show DateFormat;

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../app/run_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/calendar/adherence.dart';
import '../../domain/models/block.dart';
import '../../domain/models/programme.dart';
import '../../domain/run/run.dart' show formatKm;
import '../calendar/calendar_screen.dart';
import '../calendar/day_sheet.dart';
import '../common/widgets.dart';
import '../progress/checkpoint_checklist.dart';

/// The programme a week at a time: what is on, what got done, and what
/// is still to come. Swipe for the next week.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  /// Made once the programme has loaded: before that the week is not known,
  /// and a controller made early would open on week 1.
  PageController? _pages;
  bool _driving = false;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// [viewedWeekProvider] is the one source of truth; the pages follow it.
  void _follow(int week) {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final target = week - 1;
    final current = pages.page?.round() ?? target;
    if (current == target) return;
    if ((target - current).abs() == 1 && !AppMotion.reduced(context)) {
      _driving = true;
      pages
          .animateToPage(
            target,
            duration: AppMotion.medium,
            curve: AppMotion.curve,
          )
          .whenComplete(() => _driving = false);
    } else {
      pages.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(viewedWeekProvider, (_, w) => _follow(w));
    final async = ref.watch(bundleProvider);
    final week = ref.watch(viewedWeekProvider);
    final current = ref.watch(currentWeekProvider);
    final select = ref.read(selectedWeekProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Week'),
        actions: [
          if (async.hasValue && week != current)
            TextButton.icon(
              onPressed: () => select.select(null),
              icon: const Icon(Icons.today_outlined),
              label: const Text('This week'),
            ),
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.go('/week/calendar'),
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
          final total = b.programme.totalWeeks;
          final pages = _pages ??= PageController(initialPage: week - 1);
          void go(int w) => select.select(w == current ? null : w);
          return PageView.builder(
            controller: pages,
            itemCount: total,
            onPageChanged: (p) {
              if (!_driving) go(p + 1);
            },
            itemBuilder: (context, p) => _WeekPage(
              week: p + 1,
              programme: b.programme,
              planned: [
                for (final d in b.calendar.weekOf(p + 1))
                  CalendarEntry(planned: d),
              ],
              onPrev: p > 0 ? () => go(p) : null,
              onNext: p + 1 < total ? () => go(p + 2) : null,
            ),
          );
        },
      ),
    );
  }
}

class _WeekPage extends ConsumerWidget {
  const _WeekPage({
    required this.week,
    required this.programme,
    required this.planned,
    this.onPrev,
    this.onNext,
  });

  final int week;
  final Programme programme;

  /// The week as planned, drawn until what happened has loaded.
  final List<CalendarEntry> planned;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final entries =
        ref.watch(weekEntriesProvider(week)).asData?.value ?? planned;
    final block = programme.blockForWeek(week);
    final checkpoint = programme.checkpointForWeek(week);
    final isCurrent = ref.watch(currentWeekProvider) == week;
    final started = !entries.first.date.isAfter(today);
    final runs =
        ref
            .watch(
              runsBetweenProvider((
                from: entries.first.date,
                to: entries.last.date,
              )),
            )
            .asData
            ?.value ??
        const [];

    return ListView(
      padding: Gap.pagePadding,
      children: [
        _WeekBar(
          week: week,
          total: programme.totalWeeks,
          block: block,
          first: entries.first.date,
          last: entries.last.date,
          onPrev: onPrev,
          onNext: onNext,
        ),
        Gap.s,
        _WeekProgress(entries: entries, today: today, started: started),
        if (block != null && (block.isDeload || block.isTest)) ...[
          Gap.m,
          ToneBanner(
            tone: block.isTest ? Tone.accent : Tone.info,
            icon: block.isTest
                ? Icons.emoji_events_outlined
                : Icons.self_improvement,
            title: block.isTest ? 'Test week' : 'Deload week',
            body: block.summary,
          ),
        ],
        if (checkpoint != null) ...[
          Gap.m,
          _CheckpointCard(checkpoint: checkpoint, isCurrent: isCurrent),
        ],
        for (final e in entries) ...[
          Gap.m,
          _DayCard(
            entry: e,
            today: today,
            runKm: [
              for (final r in runs)
                if (r.runOn.year == e.date.year &&
                    r.runOn.month == e.date.month &&
                    r.runOn.day == e.date.day)
                  r.distanceM / 1000,
            ],
          ),
        ],
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.total,
    required this.block,
    required this.first,
    required this.last,
    this.onPrev,
    this.onNext,
  });

  final int week;
  final int total;
  final Block? block;
  final DateTime first;
  final DateTime last;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final span =
        '${DateFormat('d MMM').format(first)} – '
        '${DateFormat('d MMM').format(last)}';
    return Row(
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
              Text(
                [if (block != null) block!.name, span].join(' · '),
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
    );
  }
}

/// Sessions done, as a number, a bar with one segment per required session,
/// and the words for what the bar's colours say.
class _WeekProgress extends StatelessWidget {
  const _WeekProgress({
    required this.entries,
    required this.today,
    required this.started,
  });

  final List<CalendarEntry> entries;
  final DateTime today;
  final bool started;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tally = SessionTally.of(entries, today);
    if (tally.required == 0) return const SizedBox.shrink();
    final required = [
      for (final e in entries)
        if (e.isTrainingDay && !e.isOptional) e,
    ];

    Color segment(CalendarEntry e) {
      final own = e.own;
      if (own != null && own.counts) return AppTheme.good;
      if (own?.status == RecordStatus.skipped) return AppTheme.textFaint;
      return switch (e.state(today)) {
        EntryState.missed => AppTheme.warn,
        EntryState.inProgress => AppTheme.crimson,
        _ => AppTheme.surfaceHigher,
      };
    }

    final dim = t.bodyMedium!.copyWith(color: AppTheme.textDim);
    final words = [
      if (tally.missed > 0)
        TextSpan(
          text: '✕ ${tally.missed} missed',
          style: dim.copyWith(color: AppTheme.warn),
        ),
      if (tally.skipped > 0)
        TextSpan(text: '⊘ ${tally.skipped} skipped', style: dim),
      if (tally.remaining > 0)
        TextSpan(text: '${tally.remaining} to come', style: dim),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: started
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${tally.done}',
                              style: AppTheme.numeric(30),
                            ),
                            TextSpan(
                              text: ' of ${tally.required} sessions done',
                              style: t.titleMedium!.copyWith(
                                color: AppTheme.textDim,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        '${tally.required} sessions this week',
                        style: t.titleMedium,
                      ),
              ),
              if (tally.done == tally.required)
                Text(
                  '✓ all done',
                  style: t.labelLarge!.copyWith(color: AppTheme.good),
                ),
            ],
          ),
          Gap.s,
          Row(
            children: [
              for (final (i, e) in required.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: segment(e),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (started && words.isNotEmpty) ...[
            Gap.s,
            Text.rich(
              TextSpan(
                children: [
                  for (final (i, w) in words.indexed) ...[
                    if (i > 0) const TextSpan(text: '    '),
                    w,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What this week's checkpoint asks for, with what is already done
/// ticked.
class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({required this.checkpoint, required this.isCurrent});

  final Checkpoint checkpoint;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      accent: AppTheme.crimson,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.crimson, size: 20),
              Gap.s,
              Expanded(child: Text('Checkpoint', style: t.titleMedium)),
              CheckpointCount(week: checkpoint.week),
            ],
          ),
          Gap.s,
          CheckpointChecklist(checkpoint: checkpoint),
          if (isCurrent) ...[
            Gap.s,
            OutlinedButton.icon(
              onPressed: () => context.push('/capture?week=${checkpoint.week}'),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take the photos'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.entry,
    required this.today,
    this.runKm = const [],
  });

  final CalendarEntry entry;
  final DateTime today;

  /// GPS runs recorded on the day, programme or free.
  final List<double> runKm;

  bool get _isToday =>
      entry.date.year == today.year &&
      entry.date.month == today.month &&
      entry.date.day == today.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = entry.planned.day;
    final label = DateFormat('EEE d').format(entry.date);
    void open() => showDaySheet(context, ref, entry);

    if (day == null) {
      return Opacity(
        opacity: 0.45,
        child: AppCard(
          onTap: open,
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
      );
    }

    final state = entry.state(today);
    return AppCard(
      onTap: open,
      accent: _isToday ? AppTheme.crimson : null,
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
                    color: _isToday ? AppTheme.crimson : AppTheme.textDim,
                  ),
                ),
                if (_isToday)
                  Text(
                    'TODAY',
                    style: t.labelLarge?.copyWith(
                      fontSize: 11,
                      color: AppTheme.crimson,
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
                        InfoChip(label: setsLabel(day.totalWorkingSets)),
                      if (day.optional) const InfoChip(label: 'optional'),
                      if (day.warnings.isNotEmpty)
                        const InfoChip(
                          label: 'read first',
                          icon: Icons.warning_amber_rounded,
                        ),
                    ],
                  ),
                ],
                ..._status(t, state),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right, color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }

  /// What happened, in a glyph and words, under the plan.
  List<Widget> _status(TextTheme t, EntryState state) {
    Widget line(String glyph, String text, Color colour) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(glyph, style: TextStyle(color: colour, fontSize: 15)),
          ),
          Expanded(
            child: Text(text, style: t.labelLarge!.copyWith(color: colour)),
          ),
        ],
      ),
    );
    String day(DateTime d) => DateFormat('EEE d').format(d);

    final own = entry.own;
    return [
      if (state == EntryState.movedAway)
        line(
          state.glyph,
          'moved to ${day(entry.movedAway.first.scheduledDate)}'
          '${entry.movedAway.first.counts ? ' · done' : ''}',
          stateColour(state),
        )
      else if (state != EntryState.none && state != EntryState.movedHere)
        line(
          state.glyph,
          '${stateWord(state)}'
          '${own?.loggedRetroactively ?? false ? ' · from memory' : ''}',
          stateColour(state),
        ),
      for (final r in entry.movedHere)
        line(
          EntryState.movedHere.glyph,
          '${DateFormat('EEE').format(r.plannedDate)}’s session '
          '${r.counts ? 'done here' : 'moved here'}',
          stateColour(EntryState.movedHere),
        ),
      for (final km in runKm)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                child: Icon(
                  Icons.route_rounded,
                  size: 16,
                  color: AppTheme.crimson,
                ),
              ),
              Text(
                '${formatKm(km * 1000)} km run',
                style: t.labelLarge!.copyWith(color: AppTheme.text),
              ),
            ],
          ),
        ),
    ];
  }
}
