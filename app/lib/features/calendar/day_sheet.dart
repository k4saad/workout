import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/calendar/adherence.dart';
import '../common/widgets.dart';

/// What you get when you tap a day.
///
/// The behaviour depends entirely on what the day IS, because "today,
/// planned" and "three weeks ago, missed" want completely different things
/// from you.
Future<void> showDaySheet(
  BuildContext context,
  WidgetRef ref,
  CalendarEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _DaySheet(entry: entry),
  );
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final day = entry.planned.day;
    final week = entry.planned.weekNo;
    final record = entry.record;

    final isToday =
        entry.date.year == today.year &&
        entry.date.month == today.month &&
        entry.date.day == today.day;
    final isPast = entry.date.isBefore(
      DateTime(today.year, today.month, today.day),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE d MMMM').format(entry.date),
              style: t.headlineSmall,
            ),
            if (week != null)
              Text(
                'Week $week'
                '${entry.planned.block != null ? ' · ${entry.planned.block!.name}' : ''}',
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            Gap.m,

            if (day == null) ...[
              Text(
                week == null ? 'Outside the programme.' : 'Nothing scheduled.',
                style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    AppTheme.glyphForKind(day.kind),
                    style: TextStyle(color: AppTheme.forKind(day.kind)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(day.title, style: t.titleLarge)),
                ],
              ),
              Gap.s,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (day.estMinutes > 0)
                    InfoChip(label: '${day.estMinutes} min'),
                  if (day.totalWorkingSets > 0)
                    InfoChip(label: '${day.totalWorkingSets} sets'),
                  if (day.optional) const InfoChip(label: 'optional'),
                  if (record != null) InfoChip(label: record.status.name),
                  if (record?.loggedRetroactively ?? false)
                    const InfoChip(label: 'from memory'),
                  if (record?.wasMoved ?? false)
                    InfoChip(
                      label:
                          'moved from '
                          '${DateFormat('d MMM').format(record!.plannedDate)}',
                    ),
                ],
              ),

              if (entry.missed(today)) ...[
                Gap.m,
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warn.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppTheme.warn.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'This one never got logged. Log it from memory rather '
                    'than leaving a hole — the progression engine reads '
                    'this history, and a gap makes it suggest stale loads.',
                    style: t.bodyMedium,
                  ),
                ),
              ],

              Gap.l,

              // ---- the actions, by what the day actually is ----------------
              if (day.isTrainingDay) ...[
                if (isToday && record == null)
                  _Action(
                    icon: Icons.play_arrow_rounded,
                    label: 'Start session',
                    primary: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/run/$week/${day.id}');
                    },
                  )
                else if (record?.status == RecordStatus.inProgress)
                  _Action(
                    icon: Icons.play_arrow_rounded,
                    label: 'Resume session',
                    primary: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/run/$week/${day.id}');
                    },
                  )
                else if (isPast && record == null) ...[
                  _Action(
                    icon: Icons.edit_note,
                    label: 'Log it from memory',
                    primary: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(
                        '/run/$week/${day.id}'
                        '?date=${_iso(entry.date)}',
                      );
                    },
                  ),
                  Gap.s,
                  _Action(
                    icon: Icons.block,
                    label: 'Mark as skipped',
                    onTap: () async {
                      await _markSkipped(ref, entry);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ] else if (record != null) ...[
                  _Action(
                    icon: Icons.list_alt,
                    label: 'See what you did',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/history');
                    },
                  ),
                  Gap.s,
                  _Action(
                    icon: Icons.edit,
                    label: 'Correct it',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(
                        '/run/$week/${day.id}?date=${_iso(entry.date)}',
                      );
                    },
                  ),
                ] else ...[
                  // Future.
                  _Action(
                    icon: Icons.visibility_outlined,
                    label: 'Preview the session',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/week/$week/day/${day.id}');
                    },
                  ),
                ],
              ] else ...[
                Text(
                  day.note ?? 'Rest day.',
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ],

              if (record != null) ...[
                Gap.s,
                _Action(
                  icon: Icons.event_repeat,
                  label: 'Move to another date',
                  onTap: () async {
                    final to = await showDatePicker(
                      context: context,
                      initialDate: entry.date,
                      firstDate: DateTime(entry.date.year - 1),
                      lastDate: DateTime(entry.date.year + 1),
                    );
                    if (to == null) return;
                    await _move(ref, entry, to);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _markSkipped(WidgetRef ref, CalendarEntry entry) async {
    final bundle = await ref.read(bundleProvider.future);
    final day = entry.planned.day;
    final block = entry.planned.block;
    if (day == null || block == null) return;

    final service = ref.read(sessionServiceProvider);
    final session = await service.start(
      programmeId: bundle.programme.id,
      blockId: block.id,
      day: day,
      weekNo: entry.planned.weekNo!,
      date: entry.date,
      retroactive: true,
    );
    await service.markSkipped(session.id);
    ref.invalidate(allRecordsProvider);
    ref.invalidate(historyProvider);
  }

  Future<void> _move(WidgetRef ref, CalendarEntry entry, DateTime to) async {
    final db = ref.read(databaseProvider);
    final existing = await db.sessionForDay(
      entry.planned.day!.id,
      entry.record!.plannedDate,
    );
    if (existing == null) return;
    await ref.read(sessionServiceProvider).reschedule(existing.id, to);
    ref.invalidate(allRecordsProvider);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
