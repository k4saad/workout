import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/calendar/adherence.dart';
import '../../domain/models/enums.dart';
import '../common/widgets.dart';
import 'day_sheet.dart';

/// The month grid.
///
/// Hand-built rather than pulling in a calendar package: every cell needs a
/// rail, a glyph, a dot cluster and a state tint, which means fighting a
/// package's cell API for no gain. A month is six rows of seven.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final async = ref.watch(monthEntriesProvider(month));
    final statsAsync = ref.watch(programmeAdherenceProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(month)),
        actions: [
          IconButton(
            tooltip: 'Jump to today',
            icon: const Icon(Icons.my_location),
            onPressed: () =>
                ref.read(visibleMonthProvider.notifier).jumpTo(today),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (entries) => Column(
          children: [
            _MonthBar(
              month: month,
              onPrev: () => ref.read(visibleMonthProvider.notifier).shift(-1),
              onNext: () => ref.read(visibleMonthProvider.notifier).shift(1),
            ),
            if (statsAsync.asData != null)
              _AdherenceStrip(stats: statsAsync.asData!.value),
            const _WeekdayHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                child: _MonthGrid(entries: entries, today: today),
              ),
            ),
          ],
        ),
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
    return Row(
      children: [
        IconButton(
          iconSize: 28,
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
        ),
        const Spacer(),
        IconButton(
          iconSize: 28,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

class _AdherenceStrip extends StatelessWidget {
  const _AdherenceStrip({required this.stats});

  final AdherenceStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      // Wrap, not Row: three chips plus a count do not fit a 400 px phone on
      // one line once the numbers get to three digits.
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InfoChip(
            label: '${stats.percent}% adherence',
            emphasis: stats.percent >= 90,
          ),
          InfoChip(
            label: 'streak ${stats.currentStreak}',
            icon: Icons.local_fire_department_outlined,
          ),
          if (stats.missed > 0)
            Text(
              '${stats.missed} missed',
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
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          const SizedBox(width: 26),
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(
                  l,
                  style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.entries, required this.today});

  final List<CalendarEntry> entries;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CalendarEntry>>[];
    for (var i = 0; i < entries.length; i += 7) {
      rows.add(entries.sublist(i, (i + 7).clamp(0, entries.length)));
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            // A fixed row height, not stretch: inside a scroll view the
            // available height is unbounded, and stretch would demand
            // infinity.
            child: SizedBox(
              height: 74,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Programme week number, not the ISO week.
                  SizedBox(
                    width: 26,
                    child: Center(
                      child: Text(
                        row.first.planned.weekNo?.toString() ?? '',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppTheme.textDim, fontSize: 12),
                      ),
                    ),
                  ),
                  for (final e in row)
                    Expanded(
                      child: _Cell(entry: e, today: today),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Cell extends ConsumerWidget {
  const _Cell({required this.entry, required this.today});

  final CalendarEntry entry;
  final DateTime today;

  bool get _isToday =>
      entry.date.year == today.year &&
      entry.date.month == today.month &&
      entry.date.day == today.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = entry.planned.day;
    final outside = entry.planned.weekNo == null;
    final missed = entry.missed(today);
    final glyph = entry.glyph(today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Opacity(
        opacity: outside ? 0.3 : 1,
        child: Material(
          color: missed
              ? AppTheme.warn.withValues(alpha: 0.07)
              : AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _isToday ? AppTheme.oxblood : AppTheme.outline,
              width: _isToday ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showDaySheet(context, ref, entry),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${entry.date.day}',
                        style: t.labelLarge?.copyWith(
                          fontSize: 13,
                          color: _isToday ? AppTheme.oxblood : AppTheme.text,
                        ),
                      ),
                      const Spacer(),
                      if (entry.record?.loggedRetroactively ?? false)
                        const Icon(
                          Icons.edit_note,
                          size: 11,
                          color: AppTheme.textDim,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (day != null)
                    KindRail(kind: day.kind, optional: day.optional, height: 3)
                  else
                    const SizedBox(height: 3),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 22,
                    child: day == null
                        ? const SizedBox.shrink()
                        : Text(
                            _shortLabel(day.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(
                              fontSize: 10.5,
                              height: 1.1,
                              color: AppTheme.textDim,
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 15,
                    child: Text(
                      glyph,
                      style: TextStyle(
                        fontSize: 12,
                        color: _glyphColour(glyph),
                      ),
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

  static Color _glyphColour(String glyph) => switch (glyph) {
    '✓' => AppTheme.good,
    '◐' => AppTheme.warn,
    '✕' => AppTheme.warn,
    '▶' => AppTheme.oxblood,
    '↷' => AppTheme.dusk,
    _ => AppTheme.textDim,
  };

  /// "Lower A · Squat" is too long for a cell; "Lower A" is not.
  static String _shortLabel(String title) {
    final cut = title.split('·').first.trim();
    return cut.isEmpty ? title : cut;
  }
}

/// An agenda list for one week — easier to scan than a grid when you just
/// want to know what tomorrow is.
class WeekAgenda extends ConsumerWidget {
  const WeekAgenda({super.key, required this.weekNo});

  final int weekNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weekEntriesProvider(weekNo));
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (entries) => Column(
        children: [
          for (final e in entries)
            ListTile(
              onTap: () => showDaySheet(context, ref, e),
              leading: SizedBox(
                width: 40,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(e.date).toUpperCase(),
                      style: t.labelLarge?.copyWith(
                        fontSize: 11,
                        color: AppTheme.textDim,
                      ),
                    ),
                    Text('${e.date.day}', style: t.titleMedium),
                  ],
                ),
              ),
              title: Text(e.planned.day?.title ?? 'Nothing scheduled'),
              subtitle: e.planned.day == null
                  ? null
                  : Text(
                      '${e.planned.day!.kind.name}'
                      '${e.planned.day!.estMinutes > 0 ? ' · ${e.planned.day!.estMinutes} min' : ''}',
                    ),
              trailing: Text(
                e.glyph(today),
                style: TextStyle(
                  fontSize: 18,
                  color: _Cell._glyphColour(e.glyph(today)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which day kinds exist, as a key for the grid.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final kind in DayKind.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.forKind(kind),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                kind.name,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
      ],
    );
  }
}
