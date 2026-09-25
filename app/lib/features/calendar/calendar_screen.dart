import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/calendar/adherence.dart';
import '../../domain/calendar/day_markers.dart';
import '../../domain/models/block.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import '../progress/checkpoint_checklist.dart';
import 'day_sheet.dart';

/// The month, swiped.
///
/// Hand-built rather than pulling in a calendar package: every cell needs a
/// rail, a glyph, a row of markers and a state tint, and every week row a
/// programme week, a block and a checkpoint flag.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

/// Months as page indices, so the PageView can run in both directions.
int _pageOf(DateTime m) => m.year * 12 + m.month - 1;
DateTime _monthOf(int page) => DateTime(page ~/ 12, page % 12 + 1);

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final PageController _pages = PageController(
    initialPage: _pageOf(ref.read(visibleMonthProvider)),
  );

  /// True while a button is turning the page, so the pages it passes on
  /// the way do not write themselves back into the provider.
  bool _driving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The provider is the one source of truth; the PageView follows it.
  void _follow(DateTime month) {
    if (!_pages.hasClients) return;
    final target = _pageOf(month);
    final current = _pages.page?.round() ?? target;
    if (current == target) return;
    if ((target - current).abs() == 1 && !AppMotion.reduced(context)) {
      _driving = true;
      _pages
          .animateToPage(
            target,
            duration: AppMotion.medium,
            curve: AppMotion.curve,
          )
          .whenComplete(() => _driving = false);
    } else {
      _pages.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visibleMonthProvider, (_, next) => _follow(next));
    final month = ref.watch(visibleMonthProvider);
    final today = ref.watch(todayProvider);
    final stats = ref.watch(programmeAdherenceProvider).asData?.value;
    final months = ref.read(visibleMonthProvider.notifier);
    final onToday = month.year == today.year && month.month == today.month;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(month)),
        actions: [
          if (!onToday)
            TextButton.icon(
              onPressed: () => months.jumpTo(today),
              icon: const Icon(Icons.today_outlined),
              label: const Text('Today'),
            ),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(
            month: month,
            onPrev: () => months.shift(-1),
            onNext: () => months.shift(1),
          ),
          if (stats != null) _AdherenceStrip(stats: stats),
          const _WeekdayHeader(),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              onPageChanged: (p) {
                if (!_driving) months.jumpTo(_monthOf(p));
              },
              itemBuilder: (context, page) =>
                  _MonthPage(month: _monthOf(page), today: today),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final prev = DateTime(month.year, month.month - 1);
    final next = DateTime(month.year, month.month + 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, size: 26),
            label: Text(DateFormat('MMM').format(prev)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textDim),
          ),
          Expanded(
            child: Text(
              'swipe',
              textAlign: TextAlign.center,
              style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
            ),
          ),
          TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(foregroundColor: AppTheme.textDim),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('MMM').format(next)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Adherence is done over what was DUE, not over the whole programme; the
/// programme gets its own number beside it.
class _AdherenceStrip extends StatelessWidget {
  const _AdherenceStrip({required this.stats});

  final AdherenceStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      // Wrap, not Row: the chips do not fit a 400 px phone on one line once
      // the numbers get to three digits.
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InfoChip(
            label: stats.hasDue
                ? '${stats.percent}% of what was due'
                : 'nothing due yet',
            emphasis: stats.hasDue && stats.percent >= 90,
          ),
          InfoChip(
            label: '${stats.progressPercent}% of the programme',
            icon: Icons.flag_outlined,
          ),
          InfoChip(
            label: 'streak ${stats.currentStreak}',
            icon: Icons.local_fire_department_outlined,
          ),
          if (stats.missed > 0)
            Text(
              '✕ ${stats.missed} missed',
              style: t.labelLarge?.copyWith(color: AppTheme.warn),
            ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Monday-first: German convention, and the programme is weekday-keyed.
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          SizedBox(
            width: _WeekColumn.width,
            child: Text(
              'wk',
              textAlign: TextAlign.center,
              style: t.labelSmall?.copyWith(color: AppTheme.textFaint),
            ),
          ),
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(
                  l,
                  style: t.labelMedium?.copyWith(color: AppTheme.textDim),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One month: the grid, the month in numbers, and what the marks mean.
class _MonthPage extends ConsumerWidget {
  const _MonthPage({required this.month, required this.today});

  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthEntriesProvider(month));
    final programme = ref.watch(bundleProvider).asData?.value.programme;
    return async.when(
      loading: () => const SkeletonPage(cards: 2),
      error: (e, _) =>
          AsyncScaffoldBody(loading: false, error: e, child: const SizedBox()),
      data: (entries) {
        final markers = entries.isEmpty
            ? const <DateTime, DayMarkers>{}
            : ref
                      .watch(
                        dayMarkersProvider((
                          from: entries.first.date,
                          to: entries.last.date,
                        )),
                      )
                      .asData
                      ?.value ??
                  const <DateTime, DayMarkers>{};
        final summary = ref.watch(monthSummaryProvider(month)).asData?.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
          children: [
            _MonthGrid(
              entries: entries,
              today: today,
              month: month,
              markers: markers,
              programme: programme,
            ),
            if (summary != null && summary.sessionsDue + summary.runs > 0) ...[
              Gap.m,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _MonthSummaryCard(month: month, s: summary),
              ),
            ],
            Gap.m,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: CalendarLegend(),
            ),
          ],
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.entries,
    required this.today,
    required this.month,
    required this.markers,
    this.programme,
  });

  final List<CalendarEntry> entries;
  final DateTime today;
  final DateTime month;
  final Map<DateTime, DayMarkers> markers;
  final Programme? programme;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CalendarEntry>>[];
    for (var i = 0; i < entries.length; i += 7) {
      rows.add(entries.sublist(i, (i + 7).clamp(0, entries.length)));
    }

    final children = <Widget>[];
    String? lastBlock;
    for (final row in rows) {
      // A row belongs to the programme week of its Monday; a band opens
      // each block the first time the month shows it.
      final first = row.firstWhere(
        (e) => e.planned.weekNo != null,
        orElse: () => row.first,
      );
      final week = first.planned.weekNo;
      final block = first.planned.block;
      if (block != null && block.id != lastBlock) {
        children.add(_BlockBand(block: block));
        lastBlock = block.id;
      }
      final checkpoint = week == null
          ? null
          : programme?.checkpointForWeek(week);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          // A fixed row height, not stretch: inside a scroll view the
          // available height is unbounded.
          child: SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeekColumn(week: week, block: block, checkpoint: checkpoint),
                for (final e in row)
                  Expanded(
                    child: _Cell(
                      entry: e,
                      today: today,
                      inMonth: e.date.month == month.month,
                      markers:
                          markers[DateTime(
                            e.date.year,
                            e.date.month,
                            e.date.day,
                          )] ??
                          const DayMarkers(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(key: const ValueKey('month-grid'), children: children);
  }
}

/// Block colours: greys that step lighter, and crimson for the test week —
/// the one the other eleven are for.
Color blockColour(BlockKind k) => switch (k) {
  BlockKind.intro => AppTheme.textFaint,
  BlockKind.accumulation => AppTheme.textDim,
  BlockKind.deload => AppTheme.kindRest,
  BlockKind.test => AppTheme.crimson,
};

/// Where a block starts: its name and weeks, across the grid.
class _BlockBand extends StatelessWidget {
  const _BlockBand({required this.block});

  final Block block;

  @override
  Widget build(BuildContext context) {
    final c = blockColour(block.blockKind);
    final weeks = block.firstWeek == block.lastWeek
        ? 'WEEK ${block.firstWeek}'
        : 'WEEKS ${block.firstWeek}–${block.lastWeek}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${block.name.toUpperCase()} · $weeks',
            style: AppTheme.overline.copyWith(
              color: block.isTest ? AppTheme.crimson : AppTheme.textDim,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppTheme.outlineSoft)),
        ],
      ),
    );
  }
}

/// The programme week, on a rail in its block's colour; a flag on a
/// checkpoint week, which opens its list.
class _WeekColumn extends StatelessWidget {
  const _WeekColumn({required this.week, this.block, this.checkpoint});

  static const width = 26.0;

  final int? week;
  final Block? block;
  final Checkpoint? checkpoint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = block == null
        ? Colors.transparent
        : blockColour(block!.blockKind);
    final body = SizedBox(
      width: width,
      child: Row(
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Programme week number, not the ISO week.
                Text(
                  week?.toString() ?? '',
                  style: t.labelLarge?.copyWith(
                    color: AppTheme.textDim,
                    fontSize: 12,
                  ),
                ),
                if (checkpoint != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: AppTheme.crimson,
                      semanticLabel: 'Checkpoint week',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (checkpoint == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showCheckpointSheet(context, checkpoint!),
      child: body,
    );
  }
}

/// What a checkpoint week asks for.
Future<void> showCheckpointSheet(BuildContext context, Checkpoint c) =>
    showAppSheet<void>(
      context,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: AppTheme.crimson),
                Gap.s,
                Expanded(
                  child: Text(
                    'Week ${c.week} checkpoint',
                    style: t.headlineSmall,
                  ),
                ),
                CheckpointCount(week: c.week),
              ],
            ),
            Gap.m,
            CheckpointChecklist(checkpoint: c),
          ],
        );
      },
    );

class _Cell extends ConsumerWidget {
  const _Cell({
    required this.entry,
    required this.today,
    required this.inMonth,
    required this.markers,
  });

  final CalendarEntry entry;
  final DateTime today;
  final bool inMonth;
  final DayMarkers markers;

  bool get _isToday =>
      entry.date.year == today.year &&
      entry.date.month == today.month &&
      entry.date.day == today.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = entry.planned.day;
    final state = entry.state(today);
    final outsideProgramme = entry.planned.weekNo == null;
    final extra = entry.records.length > 1
        ? '+${entry.records.length - 1}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Opacity(
        opacity: !inMonth ? 0.3 : (outsideProgramme ? 0.45 : 1),
        child: Material(
          color: state == EntryState.missed
              ? AppTheme.warn.withValues(alpha: 0.07)
              : AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _isToday ? AppTheme.crimson : AppTheme.outline,
              width: _isToday ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showDaySheet(context, ref, entry),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 3, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${entry.date.day}',
                        style: t.labelLarge?.copyWith(
                          fontSize: 13,
                          color: _isToday ? AppTheme.crimson : AppTheme.text,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // The date wins the space; the glyph yields first.
                      Expanded(
                        child: Text(
                          '${state.glyph}$extra',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1,
                            color: stateColour(state),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (day != null)
                    KindRail(kind: day.kind, optional: day.optional, height: 3)
                  else
                    const SizedBox(height: 3),
                  const SizedBox(height: 3),
                  Expanded(
                    child: day == null
                        ? const SizedBox.shrink()
                        : Text(
                            _shortLabel(day.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(
                              fontSize: 10,
                              height: 1.1,
                              color: AppTheme.textDim,
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (final m in markers.ordered.take(3))
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              markerIcon(m),
                              size: 11,
                              color: m == DayMarker.run
                                  ? AppTheme.crimson
                                  : AppTheme.textDim,
                              semanticLabel: markerLabel(m),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Lower A · Squat" is too long for a cell; "Lower A" is not.
  static String _shortLabel(String title) {
    final cut = title.split('·').first.trim();
    return cut.isEmpty ? title : cut;
  }
}

/// A second way to read a state. Every state has its own glyph; the colour
/// never carries it alone.
Color stateColour(EntryState s) => switch (s) {
  EntryState.done => AppTheme.good,
  EntryState.partial || EntryState.missed => AppTheme.warn,
  EntryState.inProgress => AppTheme.crimson,
  EntryState.movedAway || EntryState.movedHere => AppTheme.text,
  EntryState.skipped || EntryState.none => AppTheme.textDim,
};

/// The word for a state, beside its glyph.
String stateWord(EntryState s) => switch (s) {
  EntryState.done => 'done',
  EntryState.partial => 'part done',
  EntryState.skipped => 'skipped',
  EntryState.missed => 'missed',
  EntryState.inProgress => 'in progress',
  EntryState.movedAway => 'moved away',
  EntryState.movedHere => 'moved here',
  EntryState.none => '',
};

IconData markerIcon(DayMarker m) => switch (m) {
  DayMarker.shoot => Icons.photo_camera_outlined,
  DayMarker.run => Icons.route_rounded,
  DayMarker.weighIn => Icons.monitor_weight_outlined,
  DayMarker.fed => Icons.restaurant_rounded,
};

String markerLabel(DayMarker m) => switch (m) {
  DayMarker.shoot => 'photo shoot',
  DayMarker.run => 'ran',
  DayMarker.weighIn => 'weighed in',
  DayMarker.fed => 'meals hit',
};

/// The month in numbers.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.month, required this.s});

  final DateTime month;
  final MonthSummary s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textDim),
          Gap.s,
          Expanded(child: Text(text, style: t.bodyMedium)),
        ],
      ),
    );
    String plural(int n, String one, [String? many]) =>
        '$n ${n == 1 ? one : (many ?? '${one}s')}';
    final change = s.weightChangeKg;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM').format(month).toUpperCase(),
            style: AppTheme.overline,
          ),
          Gap.s,
          if (s.sessionsDue > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${s.sessionsDone}', style: AppTheme.numeric(34)),
                Flexible(
                  child: Text(
                    ' of ${s.sessionsDue} sessions due',
                    style: t.titleMedium!.copyWith(color: AppTheme.textDim),
                  ),
                ),
              ],
            ),
          if (s.missed > 0 || s.skipped > 0) ...[
            Gap.xs,
            Text(
              [
                if (s.missed > 0) '✕ ${s.missed} missed',
                if (s.skipped > 0) '⊘ ${s.skipped} skipped',
              ].join('    '),
              style: t.bodyMedium!.copyWith(color: AppTheme.warn),
            ),
          ],
          Gap.s,
          if (s.runs > 0)
            line(
              Icons.route_rounded,
              '${s.km.toStringAsFixed(1)} km in ${plural(s.runs, 'run')}',
            ),
          if (s.weighIns > 0)
            line(
              Icons.monitor_weight_outlined,
              '${plural(s.weighIns, 'weigh-in')}'
              '${change == null ? '' : ' · ${change >= 0 ? '▲ +' : '▼ −'}'
                        '${change.abs().toStringAsFixed(1)} kg'}',
            ),
          if (s.fedDays > 0)
            line(
              Icons.restaurant_rounded,
              '${plural(s.fedDays, 'day')} with the meals hit',
            ),
          if (s.shoots > 0)
            line(Icons.photo_camera_outlined, plural(s.shoots, 'photo shoot')),
        ],
      ),
    );
  }
}

/// What the marks mean.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 20, child: Center(child: mark)),
        const SizedBox(width: 5),
        Text(text, style: t.bodySmall?.copyWith(color: AppTheme.textDim)),
      ],
    );
    Widget row(List<Widget> items) =>
        Wrap(spacing: 14, runSpacing: 8, children: items);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WHAT THE MARKS MEAN', style: AppTheme.overline),
          Gap.m,
          row([
            for (final s in EntryState.values)
              if (s != EntryState.none)
                item(
                  Text(
                    s.glyph,
                    style: TextStyle(color: stateColour(s), fontSize: 13),
                  ),
                  stateWord(s),
                ),
          ]),
          Gap.m,
          row([
            for (final m in DayMarker.values)
              item(
                Icon(
                  markerIcon(m),
                  size: 14,
                  color: m == DayMarker.run
                      ? AppTheme.crimson
                      : AppTheme.textDim,
                ),
                markerLabel(m),
              ),
            item(
              const Icon(Icons.flag_rounded, size: 14, color: AppTheme.crimson),
              'checkpoint week',
            ),
          ]),
          Gap.m,
          row([
            for (final kind in DayKind.values)
              item(KindRail(kind: kind), kind.name),
            item(
              const KindRail(kind: DayKind.cardio, optional: true),
              'optional (dashed)',
            ),
          ]),
        ],
      ),
    );
  }
}
