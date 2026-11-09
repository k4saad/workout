import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/planner_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/calendar/programme_calendar.dart';
import '../../domain/models/enums.dart';
import '../../domain/planner/planner.dart';
import 'planner_sheets.dart';
import 'planner_style.dart';

/// The semester, a week at a time: seven days at a glance, then the chosen
/// day as a timeline — classes, work, the ride between, the session, the
/// meals, and the free time left. Tap anything to see it or change it; add
/// your own. The week underneath is his to change too: "Your week", top
/// right.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key, this.initialDate});

  /// The day to open on; today when null.
  final DateTime? initialDate;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime? _selected;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final today = _day(ref.watch(todayProvider));
    final selected = _selected ?? _day(widget.initialDate ?? today);
    final monday = mondayOf(selected);
    final calendar = ref.watch(bundleProvider).asData?.value.calendar;
    final week = calendar?.weekNumberFor(monday);
    final inProgramme =
        week != null &&
        calendar != null &&
        week >= 1 &&
        week <= calendar.programme.totalWeeks;
    final sunday = ProgrammeCalendar.addDays(monday, 6);
    final range =
        '${DateFormat('d MMM').format(monday)} – '
        '${DateFormat('d MMM').format(sunday)}';
    void go(DateTime d) => setState(() => _selected = _day(d));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: [
          IconButton(
            tooltip: 'Your week',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => context.go('/week/planner/timetable'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEventSheet(context, ref, date: selected),
        icon: const Icon(Icons.add),
        label: const Text('Add to this day'),
      ),
      body: ListView(
        padding: Gap.pagePadding.copyWith(bottom: 96),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: () => go(ProgrammeCalendar.addDays(selected, -7)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      inProgramme ? 'Week $week of 12' : 'Week of $range',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (inProgramme)
                      Text(
                        range,
                        style: Theme.of(context).textTheme.bodySmall!
                            .copyWith(color: AppTheme.textDim),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () => go(ProgrammeCalendar.addDays(selected, 7)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (mondayOf(today) != monday)
            Center(
              child: TextButton(
                onPressed: () => go(today),
                child: const Text('This week'),
              ),
            ),
          Gap.s,
          _WeekStrip(
            monday: monday,
            selected: selected,
            today: today,
            onSelect: go,
          ),
          Gap.l,
          _DayAgenda(date: selected, today: today),
        ],
      ),
    );
  }
}

/// Seven days side by side, each with its day drawn in from 07:00 to 21:00:
/// the week's shape at a glance, like the timetable on the wall.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({
    required this.monday,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime monday;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: () {
              final date = ProgrammeCalendar.addDays(monday, i);
              final plan = ref.watch(dayPlanProvider(date)).asData?.value;
              final isSelected = date == selected;
              final isToday = date == today;
              return Semantics(
                button: true,
                selected: isSelected,
                label: DateFormat('EEEE d MMMM').format(date),
                child: Pressable(
                  onTap: () => onSelect(date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.surfaceHigh
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.crimson
                            : AppTheme.outlineSoft,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: AppTheme.overline.copyWith(
                            fontSize: 10,
                            color: isToday ? AppTheme.crimson : null,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: AppTheme.numeric(
                            18,
                            color: isToday ? AppTheme.crimson : AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 104,
                          width: double.infinity,
                          child: CustomPaint(painter: _MiniDayPainter(plan)),
                        ),
                        const SizedBox(height: 4),
                        // The session as a glyph, not only a red bar.
                        Icon(
                          plan?.session == null
                              ? Icons.remove
                              : Icons.fitness_center,
                          size: 14,
                          color: plan?.session == null
                              ? AppTheme.textFaint
                              : AppTheme.crimson,
                          semanticLabel: plan?.session == null
                              ? 'no session'
                              : 'session',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ),
      ],
    );
  }
}

/// A day from 07:00 to 21:00 as a column of bars: classes and work grey,
/// the session crimson, travel faint, his own study an outline.
class _MiniDayPainter extends CustomPainter {
  _MiniDayPainter(this.plan);

  final DayPlan? plan;
  static const _from = 7 * 60, _to = 21 * 60;

  @override
  void paint(Canvas canvas, Size size) {
    final rail = Paint()..color = AppTheme.outlineSoft;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 1, 0, 2, size.height),
        const Radius.circular(1),
      ),
      rail,
    );
    final p = plan;
    if (p == null) return;
    double y(int m) =>
        size.height * ((m.clamp(_from, _to) - _from) / (_to - _from));
    for (final i in p.items) {
      if (i.kind == PlanKind.meal) continue;
      final top = y(i.start), bottom = y(i.end);
      if (bottom - top < 0.5) continue;
      final paint = Paint()
        ..color = switch (i.kind) {
          PlanKind.session => AppTheme.crimson,
          PlanKind.travel => AppTheme.surfaceHigher,
          PlanKind.job => AppTheme.textFaint,
          _ => AppTheme.textDim,
        };
      final inset = i.kind == PlanKind.travel ? size.width * 0.3 : 3.0;
      // Study is drawn hollow: told apart by its shape, not its grey.
      if (i.kind == PlanKind.study) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            inset,
            top,
            size.width - inset,
            math.max(bottom, top + 2),
          ),
          const Radius.circular(3),
        ).deflate(i.kind == PlanKind.study ? 0.75 : 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniDayPainter old) => old.plan != plan;
}

/// One day as a timeline: every stretch, the free time between, what was
/// skipped, and the shifts that only happen when marked.
class _DayAgenda extends ConsumerWidget {
  const _DayAgenda({required this.date, required this.today});

  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(dayPlanProvider(date));
    final timetable = ref.watch(timetableProvider).asData?.value;
    final plan = async.asData?.value;
    if (plan == null) {
      return const SizedBox(height: 240, child: Skeleton(height: 240));
    }
    final markable = [
      for (final b in timetable?.on(Weekday.fromDateTime(date)) ?? const [])
        if (b.onlyWhenMarked) b,
    ];
    final busy = plan.commitments;
    final summary = busy.isEmpty
        ? (plan.session == null ? 'A free day' : 'Nothing on but the session')
        : '${formatHhmm(busy.first.start)}–${formatHhmm(busy.last.end)} on'
              '${plan.session == null ? '' : ' · session ${formatHhmm(plan.session!.start)}'}';

    // Free stretches of an hour or more between things (meals fit inside
    // them): what is left to plan with, listed where they start.
    final rows = <(int, int, Widget)>[];
    int? cursor;
    for (final i in plan.items) {
      if (i.kind == PlanKind.meal) continue;
      if (cursor != null && i.start - cursor >= 60) {
        rows.add((cursor, 0, _FreeRow(start: cursor, end: i.start)));
      }
      cursor = math.max(cursor ?? i.end, i.end);
    }
    for (final i in plan.items) {
      rows.add((i.start, 1, _ItemRow(item: i, date: date, today: today)));
    }
    rows.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(DateFormat('EEEE d MMMM').format(date), style: t.titleLarge),
        Text(summary, style: t.bodyMedium!.copyWith(color: AppTheme.textDim)),
        if (plan.breakName != null) ...[
          Gap.m,
          ToneBanner(
            tone: Tone.info,
            icon: Icons.beach_access_outlined,
            title: plan.breakName!,
            body:
                'No lectures. Work, study and everything of your own still '
                'are.',
          ),
        ] else if (!plan.lectures &&
            timetable != null &&
            date.isAfter(timetable.lecturesTo)) ...[
          Gap.m,
          const ToneBanner(
            tone: Tone.info,
            icon: Icons.school_outlined,
            title: 'Lectures are over',
            body: 'Work, study and everything of your own still are.',
          ),
        ],
        for (final b in markable) ...[
          Gap.m,
          _MarkTile(date: date, block: b, plan: plan),
        ],
        Gap.m,
        if (plan.items.isEmpty)
          const EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'Nothing planned',
            body: 'A day of your own. Add something if it needs a time.',
          )
        else
          for (final r in rows) r.$3,
        if (plan.skipped.isNotEmpty) ...[
          const SectionHeader('Skipped'),
          for (final s in plan.skipped) _SkippedRow(item: s, date: date),
        ],
      ],
    );
  }
}

class _MarkTile extends ConsumerWidget {
  const _MarkTile({
    required this.date,
    required this.block,
    required this.plan,
  });

  final DateTime date;
  final TimetableBlock block;
  final DayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = plan.commitments.any((c) => c.id == block.id);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.work_outline, color: AppTheme.textDim),
        title: Text('${block.title} this ${DateFormat('EEEE').format(date)}'),
        subtitle: Text(
          '${formatHhmm(block.start)}–${formatHhmm(block.end)}'
          '${block.note == null ? '' : ' · ${block.note}'}',
        ),
        value: on,
        onChanged: (v) => setMarked(ref, date, block.id, v),
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  const _FreeRow({required this.start, required this.end});

  final int start;
  final int end;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 2, 0, 10),
      child: Row(
        children: [
          const Icon(Icons.more_vert, size: 16, color: AppTheme.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free ${formatHhmm(start)}–${formatHhmm(end)} · '
              '${plannerLength(end - start)}',
              style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

/// One stretch: its times on the left, then a card for what he has to be at
/// (tap to see or change it), or a quiet line for travel and meals.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.date, required this.today});

  final PlanItem item;
  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final i = item;
    final quiet = i.kind == PlanKind.travel || i.kind == PlanKind.meal;
    final colour = plannerColour(i.kind);

    final times = SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatHhmm(i.start),
            style: AppTheme.numeric(
              quiet ? 14 : 17,
              color: quiet ? AppTheme.textFaint : AppTheme.text,
            ),
          ),
          if (!quiet)
            Text(
              formatHhmm(i.end),
              style: AppTheme.numeric(13, color: AppTheme.textFaint),
            ),
        ],
      ),
    );

    if (quiet) {
      final detail = i.kind == PlanKind.meal
          ? [
              i.title,
              if (i.packed) 'packed, at work',
              if (i.takeAlong) 'take it with you',
              if (i.quick) 'quick',
              if (i.sessionFuel) 'fuel for the session',
            ].join(' · ')
          : '${i.title} · ${plannerLength(i.minutes)}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            times,
            const SizedBox(width: 8),
            Icon(
              plannerIcon(i),
              size: 16,
              color: i.sessionFuel ? AppTheme.crimson : AppTheme.textFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail,
                style: t.bodySmall!.copyWith(color: AppTheme.textDim),
              ),
            ),
          ],
        ),
      );
    }

    final sub = [
      plannerKindLabel(i),
      ?i.room,
      ?i.who,
      if (i.moved) 'moved',
      plannerLength(i.minutes),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          times,
          const SizedBox(width: 8),
          Expanded(
            child: AppCard(
              accent: i.kind == PlanKind.session ? AppTheme.crimson : null,
              onTap: () => showItemSheet(context, ref, item: i, date: date),
              semanticLabel: '${i.title}, ${plannerSpan(i)}',
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      border: i.optional
                          ? Border.all(color: AppTheme.outline)
                          : null,
                    ),
                    child: Icon(plannerIcon(i), color: colour, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title, style: t.titleSmall),
                        Text(
                          sub,
                          style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedRow extends ConsumerWidget {
  const _SkippedRow({required this.item, required this.date});

  final PlanItem item;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              formatHhmm(item.start),
              style: AppTheme.numeric(14, color: AppTheme.textFaint),
            ),
          ),
          const SizedBox(width: 8),
          Icon(plannerIcon(item), size: 18, color: AppTheme.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              style: t.bodyMedium!.copyWith(
                color: AppTheme.textFaint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setSkipped(ref, date, item.id, false),
            child: const Text('Bring back'),
          ),
        ],
      ),
    );
  }
}
