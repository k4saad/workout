import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../app/run_providers.dart';
import '../../app/session_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../domain/calendar/adherence.dart';
import '../../domain/run/run.dart';
import '../common/widgets.dart';
import '../history/history_screen.dart';
import 'calendar_screen.dart';

/// Everything that happened on a date, and what can be done about it.
///
/// The actions depend on what the day IS, because "today, planned" and
/// "three weeks ago, missed" want completely different things from you.
Future<void> showDaySheet(
  BuildContext context,
  WidgetRef ref,
  CalendarEntry entry,
) => showAppSheet<void>(context, builder: (_) => _DaySheet(entry: entry));

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final programme = ref.watch(bundleProvider).asData?.value.programme;
    final day = entry.planned.day;
    final week = entry.planned.weekNo;
    final block = entry.planned.block;
    final state = entry.state(today);
    final sessions =
        ref.watch(sessionsOnProvider(entry.date)).asData?.value ??
        const <Session>[];

    final midnight = DateTime(today.year, today.month, today.day);
    final isToday = _sameDay(entry.date, today);
    final isPast = entry.date.isBefore(midnight);
    final checkpoint = week == null ? null : programme?.checkpointForWeek(week);

    // This date's own session has not been dealt with, here or elsewhere.
    final open =
        day != null &&
        day.isTrainingDay &&
        entry.movedAway.isEmpty &&
        !entry.records.any((r) => _sameDay(r.plannedDate, entry.date));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE d MMMM').format(entry.date),
          style: t.headlineSmall,
        ),
        if (week != null)
          Text(
            'Week $week${block == null ? '' : ' · ${block.name}'}',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
        if (checkpoint != null) ...[
          Gap.s,
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showCheckpointSheet(context, checkpoint),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: AppTheme.crimson,
                  ),
                  Gap.s,
                  Expanded(
                    child: Text(
                      'Checkpoint week: photos and measurements',
                      style: t.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textDim),
                ],
              ),
            ),
          ),
        ],
        Gap.m,

        if (day == null)
          Text(
            week == null ? 'Outside the programme.' : 'Nothing scheduled.',
            style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
          )
        else ...[
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
          if (day.isTrainingDay) ...[
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (day.estMinutes > 0)
                  InfoChip(label: '${day.estMinutes} min'),
                if (day.totalWorkingSets > 0)
                  InfoChip(label: setsLabel(day.totalWorkingSets)),
                if (day.optional) const InfoChip(label: 'optional'),
              ],
            ),
          ],
          _OwnSessionState(entry: entry, state: state),
          Gap.m,

          if (open) ...[
            Gap.s,
            if (isToday)
              _Action(
                icon: Icons.play_arrow_rounded,
                label: 'Start session',
                primary: true,
                onTap: () => _go(context, '/run/$week/${day.id}'),
              )
            else if (isPast) ...[
              _Action(
                icon: Icons.edit_note,
                label: 'Log it from memory',
                primary: true,
                onTap: () => _go(
                  context,
                  '/run/$week/${day.id}?date=${_iso(entry.date)}',
                ),
              ),
              Gap.s,
              _Action(
                icon: Icons.do_not_disturb_on_outlined,
                label: 'Mark as skipped',
                onTap: () async {
                  await _markSkipped(ref, entry);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
            if (isToday || isPast) Gap.s,
            _Action(
              icon: Icons.visibility_outlined,
              label: 'See the session',
              onTap: () => _go(context, '/week/$week/day/${day.id}'),
            ),
          ] else if (!day.isTrainingDay)
            Text(
              day.note ?? 'Rest day.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
        ],

        if (sessions.isNotEmpty) ...[
          SectionHeader(
            sessions.length == 1 ? 'Logged here' : 'Logged here: two sessions',
          ),
          for (final s in sessions) ...[
            _LoggedSession(session: s, date: entry.date, today: today),
            Gap.m,
          ],
        ],

        _DayExtras(date: entry.date, future: !isPast && !isToday),
      ],
    );
  }

  /// Closes the sheet, then navigates. The router is taken first: after the
  /// pop this sheet's context is on its way out.
  static void _go(BuildContext context, String location) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(location);
  }

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
    ref.invalidate(historyProvider);
  }
}

/// What became of this date's own session, in a glyph and a word.
class _OwnSessionState extends StatelessWidget {
  const _OwnSessionState({required this.entry, required this.state});

  final CalendarEntry entry;
  final EntryState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget line(String glyph, String text, Color colour) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(glyph, style: TextStyle(color: colour, fontSize: 17)),
          ),
          Expanded(
            child: Text(text, style: t.titleMedium!.copyWith(color: colour)),
          ),
        ],
      ),
    );

    if (state == EntryState.missed) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: ToneBanner(
          tone: Tone.warn,
          icon: Icons.close_rounded,
          title: 'Missed',
          body:
              'This one never got logged. Log it from memory rather than '
              'leaving a hole — the progression engine reads this history, '
              'and a gap makes it suggest stale loads.',
        ),
      );
    }
    if (entry.movedAway.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in entry.movedAway)
            line(
              EntryState.movedAway.glyph,
              'Moved to ${DateFormat('EEE d MMM').format(r.scheduledDate)}'
              '${switch (r.status) {
                RecordStatus.completed || RecordStatus.partial => ', done there',
                RecordStatus.skipped => ', and skipped',
                _ => '',
              }}',
              AppTheme.text,
            ),
        ],
      );
    }
    final own = entry.own;
    if (own == null || !_sameDay(own.plannedDate, entry.date)) {
      return const SizedBox.shrink();
    }
    // Its own session is here, so the state is that session's.
    final word = stateWord(state);
    if (word.isEmpty) return const SizedBox.shrink();
    return line(
      state.glyph,
      '${word[0].toUpperCase()}${word.substring(1)}'
      '${own.loggedRetroactively ? ' · from memory' : ''}',
      stateColour(state),
    );
  }
}

/// A session stored on this date, with what can be done to it.
class _LoggedSession extends ConsumerWidget {
  const _LoggedSession({
    required this.session,
    required this.date,
    required this.today,
  });

  final Session session;
  final DateTime date;
  final DateTime today;

  /// Opens the session as what it is, not as this date's: see
  /// [sessionRunPath].
  String get _runPath => sessionRunPath(session, today: today);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final movedHere = !_sameDay(session.plannedDate, date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (movedHere)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${EntryState.movedHere.glyph}  Moved here from '
              '${DateFormat('EEE d MMM').format(session.plannedDate)}',
              style: t.titleSmall,
            ),
          ),
        SessionCard(session: session, showDate: false),
        Gap.s,
        if (session.status == SessionStatus.inProgress)
          _Action(
            icon: Icons.play_arrow_rounded,
            label: 'Resume session',
            primary: true,
            onTap: () => _DaySheet._go(context, _runPath),
          )
        else
          _Action(
            icon: Icons.edit_outlined,
            label: session.status == SessionStatus.skipped
                ? 'Log it after all'
                : 'Correct it',
            onTap: () => _DaySheet._go(context, _runPath),
          ),
        Gap.s,
        _Action(
          icon: Icons.event_repeat,
          label: 'Move to another date',
          onTap: () async {
            final to = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(date.year - 1),
              lastDate: DateTime(date.year + 1),
            );
            if (to == null) return;
            await ref.read(sessionServiceProvider).reschedule(session.id, to);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
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

/// The rest of the day: the weigh-in, the food, the photos, the runs.
class _DayExtras extends ConsumerWidget {
  const _DayExtras({required this.date, required this.future});

  final DateTime date;
  final bool future;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (future) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final d = ref.watch(dayDetailsProvider(date)).asData?.value;
    final runs =
        ref.watch(runsBetweenProvider((from: date, to: date))).asData?.value ??
        const [];

    Widget row(IconData icon, String text, {Color colour = AppTheme.textDim}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: colour),
              Gap.m,
              Expanded(child: Text(text, style: t.titleMedium)),
            ],
          ),
        );

    final rows = <Widget>[
      if (d?.weighInKg case final kg?)
        row(Icons.monitor_weight_outlined, '${kg.toStringAsFixed(1)} kg'),
      if (d != null && d.mealsPlanned > 0)
        row(
          Icons.restaurant_rounded,
          d.mealsEaten == 0
              ? 'No meals logged'
              : '${d.mealsEaten} of ${d.mealsPlanned} meals · '
                    '${d.kcalEaten.round()} of ${d.kcalPlanned.round()} kcal',
        ),
      if (d?.shoot ?? false)
        row(Icons.photo_camera_outlined, 'Progress photos taken'),
      for (final r in runs)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final router = GoRouter.of(context);
            Navigator.pop(context);
            router.go('/progress/runs/${r.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: AppTheme.crimson),
                Gap.m,
                Expanded(
                  child: Text(
                    '${formatKm(r.distanceM)} km · '
                    '${formatClock(r.movingMs)}'
                    '${r.exerciseId == null ? ' · free run' : ''}',
                    style: t.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SectionHeader('The rest of the day'), ...rows],
    );
  }
}
