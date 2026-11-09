import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/planner_providers.dart';
import '../../app/providers.dart';
import '../../app/settings_providers.dart';
import '../../data/planner_repository.dart';
import '../../core/ui/ui.dart';
import '../../domain/planner/planner.dart';
import 'planner_style.dart';

/// Makes one change, then re-lays the reminders, so a skipped class does
/// not still ring and a moved session rings at its new time.
///
/// Everything is read from [ref] BEFORE the change: the change rebuilds the
/// planner, and the widget that asked may be gone by the time it lands.
Future<void> _change(
  WidgetRef ref,
  Future<void> Function(PlannerRepository repo) change,
) async {
  final repo = ref.read(plannerRepositoryProvider);
  final schedule = ref.read(preferencesProvider.notifier);
  await change(repo);
  await schedule.refreshSchedule();
}

Future<void> setSkipped(
  WidgetRef ref,
  DateTime date,
  String blockId,
  bool skipped,
) => _change(ref, (repo) => repo.setSkipped(date, blockId, skipped));

Future<void> setMarked(
  WidgetRef ref,
  DateTime date,
  String blockId,
  bool marked,
) => _change(ref, (repo) => repo.setMarked(date, blockId, marked));

/// What a tap on a stretch opens: the session to start or move, an entry
/// of his own to change, a class or a shift to look at or skip.
Future<void> showItemSheet(
  BuildContext context,
  WidgetRef ref, {
  required PlanItem item,
  required DateTime date,
}) => switch (item.kind) {
  PlanKind.session => showAppSheet<void>(
    context,
    builder: (_) => _SessionSheet(item: item, date: date),
  ),
  PlanKind.event => showEventSheet(context, ref, date: date, existing: item),
  _ => showAppSheet<void>(
    context,
    builder: (_) => _BlockSheet(item: item, date: date),
  ),
};

class _BlockSheet extends ConsumerWidget {
  const _BlockSheet({required this.item, required this.date});

  final PlanItem item;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final i = item;
    final day = DateFormat('EEEE d MMMM').format(date);
    final skipLabel = switch (i.kind) {
      PlanKind.job => 'Not working this time',
      PlanKind.prayer => 'Not this time',
      PlanKind.study => 'Not today',
      _ => 'Skip this one',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(plannerIcon(i), color: AppTheme.text),
              Gap.s,
              Text(plannerKindLabel(i).toUpperCase(), style: AppTheme.overline),
            ],
          ),
          Gap.s,
          Text(i.title, style: t.headlineSmall),
          Gap.xs,
          Text(
            '$day · ${plannerSpan(i)} · ${plannerLength(i.minutes)}',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          if (i.room != null || i.who != null) ...[
            Gap.m,
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppTheme.textDim,
                ),
                Gap.s,
                Expanded(
                  child: Text(
                    [?i.room, ?i.who].join(' · '),
                    style: t.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (i.note != null) ...[
            Gap.s,
            Text(
              i.note!,
              style: t.bodySmall!.copyWith(color: AppTheme.textDim),
            ),
          ],
          Gap.l,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(skipLabel),
              onPressed: () {
                final done = setSkipped(ref, date, i.blockId ?? i.id, true);
                Navigator.of(context).pop();
                unawaited(done);
              },
            ),
          ),
          Gap.xs,
          Text(
            'Off this day only: the week stays as it is, and its reminder '
            'goes.',
            style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
          ),
          if (i.blockId case final blockId?) ...[
            Gap.m,
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Change it every week'),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(
                    Uri(
                      path: '/week/planner/timetable',
                      queryParameters: {'block': blockId},
                    ).toString(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionSheet extends ConsumerStatefulWidget {
  const _SessionSheet({required this.item, required this.date});

  final PlanItem item;
  final DateTime date;

  @override
  ConsumerState<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<_SessionSheet> {
  late int _start = widget.item.start;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final i = widget.item;
    final today = ref.watch(todayProvider);
    final isToday =
        today.year == widget.date.year &&
        today.month == widget.date.month &&
        today.day == widget.date.day;
    final planned = ref
        .watch(bundleProvider)
        .asData
        ?.value
        .calendar
        .forDate(widget.date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, color: AppTheme.crimson),
              Gap.s,
              Text(plannerKindLabel(i).toUpperCase(), style: AppTheme.overline),
            ],
          ),
          Gap.s,
          Text(i.title, style: t.headlineSmall),
          Gap.xs,
          Text(
            '${DateFormat('EEEE d MMMM').format(widget.date)} · '
            '${plannerLength(i.minutes)}',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          if (isToday && planned?.day != null && planned?.weekNo != null) ...[
            Gap.l,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start session'),
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(
                    context.push('/run/${planned!.weekNo}/${planned.day!.id}'),
                  );
                },
              ),
            ),
          ],
          Gap.l,
          Text('STARTS AT', style: AppTheme.overline),
          Gap.s,
          TimeStepper(
            minutes: _start,
            onChanged: (m) => setState(() => _start = m),
          ),
          Gap.m,
          Row(
            children: [
              if (i.moved)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      final done = _change(
                        ref,
                        (repo) => repo.setSessionTime(widget.date, null),
                      );
                      Navigator.of(context).pop();
                      unawaited(done);
                    },
                    child: const Text('Back to its usual time'),
                  ),
                ),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _start == i.start
                      ? null
                      : () {
                          final done = _change(
                            ref,
                            (repo) => repo.setSessionTime(widget.date, _start),
                          );
                          Navigator.of(context).pop();
                          unawaited(done);
                        },
                  child: Text(
                    _start == i.start
                        ? 'Use − and + to move it'
                        : 'Move to ${formatHhmm(_start)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds one of his own to [date], or changes [existing].
Future<void> showEventSheet(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  PlanItem? existing,
}) => showAppSheet<void>(
  context,
  builder: (_) => _EventSheet(date: date, existing: existing),
);

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({required this.date, this.existing});

  final DateTime date;
  final PlanItem? existing;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  late String _category = widget.existing?.category ?? 'exam';
  late final _title = TextEditingController(text: widget.existing?.title);
  late int _start = widget.existing?.start ?? 10 * 60;
  late int _length = widget.existing?.minutes ?? 60;
  late bool _remind = widget.existing?.remind ?? true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _label =>
      plannerCategories.firstWhere((c) => c.$1 == _category).$2;

  void _save() {
    final title = _title.text.trim().isEmpty ? _label : _title.text.trim();
    final id = widget.existing?.entryId;
    final date = widget.date, start = _start, end = _start + _length;
    final remind = _remind, category = _category;
    final done = _change(ref, (repo) async {
      if (id == null) {
        await repo.addEvent(
          date: date,
          title: title,
          start: start,
          end: end,
          remind: remind,
          category: category,
        );
      } else {
        await repo.updateEvent(
          id,
          title: title,
          start: start,
          end: end,
          remind: remind,
          category: category,
        );
      }
    });
    Navigator.of(context).pop();
    unawaited(done);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final existing = widget.existing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existing == null ? 'Add to this day' : 'Change it',
            style: t.headlineSmall,
          ),
          Text(
            DateFormat('EEEE d MMMM').format(widget.date),
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label, icon) in plannerCategories)
                ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 18,
                    color: _category == id ? AppTheme.text : AppTheme.textDim,
                  ),
                  label: Text(label),
                  selected: _category == id,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _category = id),
                ),
            ],
          ),
          Gap.m,
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'What', hintText: _label),
          ),
          Gap.l,
          Text('STARTS AT', style: AppTheme.overline),
          Gap.s,
          TimeStepper(
            minutes: _start,
            onChanged: (m) => setState(() => _start = m),
          ),
          Gap.m,
          Text('HOW LONG', style: AppTheme.overline),
          Gap.s,
          TimeStepper(
            minutes: _length,
            min: 15,
            max: 12 * 60,
            asLength: true,
            onChanged: (m) => setState(() => _length = m),
          ),
          Gap.s,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me 15 minutes before'),
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
          ),
          Gap.m,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _save,
              child: Text(
                '${existing == null ? 'Add' : 'Save'} · '
                '${formatHhmm(_start)}–${formatHhmm(_start + _length)}',
              ),
            ),
          ),
          if (existing?.entryId case final id?) ...[
            Gap.s,
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                onPressed: () {
                  final done = _change(ref, (repo) => repo.delete(id));
                  Navigator.of(context).pop();
                  unawaited(done);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A time (or a length) on big buttons, fifteen minutes a tap, and held to
/// keep going: no keyboard, no clock face. With [bigStep], an hour either
/// side as well, so a timetable's 14:25 is a few taps from 10:00.
class TimeStepper extends StatefulWidget {
  const TimeStepper({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.min = 6 * 60,
    this.max = 23 * 60,
    this.step = 15,
    this.bigStep,
    this.asLength = false,
  });

  final int minutes;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final int? bigStep;

  /// Shown as a length ("1 h 30") rather than a time of day.
  final bool asLength;

  @override
  State<TimeStepper> createState() => _TimeStepperState();
}

class _TimeStepperState extends State<TimeStepper> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _bump(int delta) {
    final next = (widget.minutes + delta).clamp(widget.min, widget.max);
    if (next != widget.minutes) widget.onChanged(next);
  }

  void _hold(int delta) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _bump(delta),
    );
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final asLength = widget.asLength;
    Widget button(IconData icon, String tip, int delta) => GestureDetector(
      onLongPressStart: (_) => _hold(delta),
      onLongPressEnd: (_) => _release(),
      onLongPressCancel: _release,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton.filledTonal(
          tooltip: tip,
          onPressed: () => _bump(delta),
          icon: Icon(icon),
        ),
      ),
    );
    Widget hour(String label, String tip, int delta) => SizedBox(
      width: 52,
      height: 56,
      child: Tooltip(
        message: tip,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => _bump(delta),
          child: Text(
            label,
            style: AppTheme.numeric(15, color: AppTheme.textDim),
          ),
        ),
      ),
    );
    final big = widget.bigStep;
    final bigLabel = big == null
        ? ''
        : big % 60 == 0
        ? '${big ~/ 60} h'
        : '$big';
    return Row(
      children: [
        if (big != null) ...[
          hour(
            '−$bigLabel',
            asLength ? 'An hour shorter' : 'An hour earlier',
            -big,
          ),
          const SizedBox(width: 6),
        ],
        button(Icons.remove, asLength ? 'Shorter' : 'Earlier', -widget.step),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              asLength
                  ? plannerLength(widget.minutes)
                  : formatHhmm(widget.minutes),
              textAlign: TextAlign.center,
              style: AppTheme.numeric(32),
            ),
          ),
        ),
        button(Icons.add, asLength ? 'Longer' : 'Later', widget.step),
        if (big != null) ...[
          const SizedBox(width: 6),
          hour(
            '+$bigLabel',
            asLength ? 'An hour longer' : 'An hour later',
            big,
          ),
        ],
      ],
    );
  }
}
