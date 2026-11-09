import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/planner_providers.dart';
import '../../app/providers.dart';
import '../../app/timetable_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/enums.dart';
import '../../domain/planner/planner.dart';
import '../common/widgets.dart';
import '../editor/widgets/problem_strip.dart';
import 'planner_sheets.dart' show TimeStepper;
import 'planner_style.dart';

const _dayNames = {
  Weekday.mon: 'Monday',
  Weekday.tue: 'Tuesday',
  Weekday.wed: 'Wednesday',
  Weekday.thu: 'Thursday',
  Weekday.fri: 'Friday',
  Weekday.sat: 'Saturday',
  Weekday.sun: 'Sunday',
};

const _dayShort = {
  Weekday.mon: 'Mon',
  Weekday.tue: 'Tue',
  Weekday.wed: 'Wed',
  Weekday.thu: 'Thu',
  Weekday.fri: 'Fri',
  Weekday.sat: 'Sat',
  Weekday.sun: 'Sun',
};

/// "Every day", "Weekdays", "Tue, Fri".
String daysLabel(List<Weekday> days) {
  final sat = days.contains(Weekday.sat), sun = days.contains(Weekday.sun);
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && !sat && !sun) return 'Weekdays';
  if (days.length == 2 && sat && sun) return 'Weekends';
  return [for (final d in days) _dayShort[d]].join(', ');
}

String _dateRange(DateTime from, DateTime to) =>
    '${DateFormat('d MMM y').format(from)} – ${DateFormat('d MMM y').format(to)}';

/// His week, his to change (docs/13-your-week-plan.md): every class, shift,
/// prayer and hour of study, day by day, and the semester around them. The
/// planner, Fuel and the reminders read what is here, so a change of
/// timetable is a few taps on the phone, not a new build.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key, this.openBlock});

  /// A block to open straight away: the planner's "Change it every week".
  final String? openBlock;

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(timetableProvider);
    final problems = ref.watch(timetableProblemsProvider).asData?.value ?? [];
    final edited = ref.watch(timetableEditedProvider).asData?.value ?? false;
    final week = async.asData?.value;

    if (week != null && !_opened) {
      _opened = true;
      final open = widget.openBlock == null
          ? null
          : week.block(widget.openBlock!);
      if (open != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showBlockEditor(context, week: week, existing: open);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your week')),
      floatingActionButton: week == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showBlockEditor(context, week: week),
              icon: const Icon(Icons.add),
              label: const Text('Add to the week'),
            ),
      body: async.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (week) => ListView(
          padding: Gap.pagePadding.copyWith(bottom: 96),
          children: [
            if (problems.isNotEmpty) ...[
              ProblemStrip(problems: problems),
              Gap.m,
            ],
            Text(week.name, style: t.titleLarge),
            Gap.xs,
            Text(
              'The planner, Fuel and your reminders read this week. Tap '
              'anything to change it.',
              style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
            ),
            for (final day in Weekday.values) ...[
              SectionHeader(_dayNames[day]!),
              if (week.on(day).isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Nothing every week.',
                    style: t.bodyMedium!.copyWith(color: AppTheme.textFaint),
                  ),
                )
              else
                for (final b in week.on(day)) _BlockRow(block: b, week: week),
            ],
            const SectionHeader('The semester'),
            NavTile(
              icon: Icons.drive_file_rename_outline,
              title: 'Name',
              subtitle: week.name,
              onTap: () => _rename(context, week),
            ),
            NavTile(
              icon: Icons.school_outlined,
              title: 'Lectures',
              subtitle: _dateRange(week.lecturesFrom, week.lecturesTo),
              onTap: () => _lectures(context, week),
            ),
            for (final (i, b) in week.breaks.indexed)
              NavTile(
                icon: Icons.beach_access_outlined,
                title: b.name,
                subtitle: '${_dateRange(b.from, b.to)} · no lectures',
                onTap: () => _showBreakSheet(context, week, index: i),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => _showBreakSheet(context, week),
                icon: const Icon(Icons.add),
                label: const Text('Add a break'),
              ),
            ),
            NavTile(
              icon: Icons.directions_bike,
              title: 'Travel',
              subtitle:
                  '${plannerLength(week.travelMinutes)} between two places, '
                  'and home',
              onTap: () => _travel(context, week),
            ),
            const SectionHeader('Places'),
            for (final e in week.places.entries)
              NavTile(
                icon: Icons.place_outlined,
                title: e.value,
                subtitle: switch (week.usesOf(e.key).length) {
                  0 => 'Nothing here yet',
                  1 => '1 block',
                  final n => '$n blocks',
                },
                onTap: () => _showPlaceSheet(context, week, id: e.key),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => _showPlaceSheet(context, week),
                icon: const Icon(Icons.add),
                label: const Text('Add a place'),
              ),
            ),
            Gap.xl,
            if (edited) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _reset(context),
                  icon: const Icon(Icons.restore),
                  label: const Text('Back to the shipped week'),
                ),
              ),
              Gap.s,
            ],
            Text(
              'Your week is saved on the phone and goes into every backup. '
              'The shipped one is never touched, so going back to it always '
              'works.',
              style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  TimetableEditController get _edit =>
      ref.read(timetableEditControllerProvider.notifier);

  Future<void> _rename(BuildContext context, Timetable week) async {
    final edit = _edit;
    final name = await _showTextSheet(
      context,
      title: 'The semester',
      label: 'Name',
      initial: week.name,
    );
    if (name == null || name.isEmpty || name == week.name) return;
    await edit.apply((w) => w.copyWith(name: name));
  }

  Future<void> _lectures(BuildContext context, Timetable week) async {
    final edit = _edit;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(week.lecturesFrom.year - 2),
      lastDate: DateTime(week.lecturesTo.year + 3, 12, 31),
      initialDateRange: DateTimeRange(
        start: week.lecturesFrom,
        end: week.lecturesTo,
      ),
      helpText: 'Lectures from — to',
    );
    if (range == null) return;
    await edit.apply(
      (w) => w.copyWith(lecturesFrom: range.start, lecturesTo: range.end),
    );
  }

  Future<void> _travel(BuildContext context, Timetable week) async {
    final edit = _edit;
    final minutes = await showAppSheet<int>(
      context,
      builder: (_) => _TravelSheet(initial: week.travelMinutes),
    );
    if (minutes == null || minutes == week.travelMinutes) return;
    await edit.apply((w) => w.copyWith(travelMinutes: minutes));
  }

  Future<void> _reset(BuildContext context) async {
    final edit = _edit;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Back to the shipped week?'),
        content: const Text(
          'Every change you made to your week goes, and the week the app '
          'came with is back. Skips and things of your own in the planner '
          'stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep mine'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
    if (ok == true) await edit.reset();
  }
}

/// One block on one day: its times, its glyph, what it is and where.
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.week});

  final TimetableBlock block;
  final Timetable week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = block;
    final sub = [
      b.optional
          ? '${blockKindLabel(b.kind)} · optional'
          : blockKindLabel(b.kind),
      b.place == null ? 'Anywhere' : week.places[b.place] ?? b.place!,
      ?b.room,
      ?b.who,
      if (b.days.length > 1) daysLabel(b.days),
      if (b.onlyWhenMarked) 'only when switched on',
      if (b.offInBreaks) 'not in breaks',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => showBlockEditor(context, week: week, existing: b),
        semanticLabel:
            '${b.title}, ${formatHhmm(b.start)} to ${formatHhmm(b.end)}',
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatHhmm(b.start), style: AppTheme.numeric(17)),
                  Text(
                    formatHhmm(b.end),
                    style: AppTheme.numeric(13, color: AppTheme.textFaint),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: b.optional || b.onlyWhenMarked
                    ? Border.all(color: AppTheme.outline)
                    : null,
              ),
              child: Icon(
                blockKindIcon(b.kind, away: b.place != null),
                color: plannerColour(b.kind),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: t.titleSmall),
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
    );
  }
}

/// Adds a block to [week], or changes [existing].
Future<void> showBlockEditor(
  BuildContext context, {
  required Timetable week,
  TimetableBlock? existing,
}) => showAppSheet<void>(
  context,
  builder: (_) => _BlockEditor(week: week, existing: existing),
);

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({required this.week, this.existing});

  final Timetable week;
  final TimetableBlock? existing;

  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late PlanKind _kind = widget.existing?.kind ?? PlanKind.lecture;
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _room = TextEditingController(text: widget.existing?.room);
  late final _who = TextEditingController(text: widget.existing?.who);
  late final _note = TextEditingController(text: widget.existing?.note);
  late final Set<Weekday> _days = {
    ...?widget.existing?.days,
    if (widget.existing == null) Weekday.fromDateTime(ref.read(todayProvider)),
  };
  late int _start = widget.existing?.start ?? 10 * 60;
  late int _end = widget.existing?.end ?? 11 * 60 + 30;
  late String? _place = widget.existing == null
      ? widget.week.places.keys.firstOrNull
      : widget.existing!.place;
  late bool _optional = widget.existing?.optional ?? false;
  late bool _onlyWhenMarked = widget.existing?.onlyWhenMarked ?? false;
  late bool _offInBreaks = widget.existing?.offInBreaks ?? false;

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _who.dispose();
    _note.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  String get _titleOrKind => _text(_title) ?? blockKindLabel(_kind);

  /// The block as it would be saved, under [id].
  TimetableBlock _block(String id) => TimetableBlock(
    id: id,
    days: _days,
    start: _start,
    end: _end,
    kind: _kind,
    title: _titleOrKind,
    place: _place,
    room: _text(_room),
    who: _kind == PlanKind.lecture ? _text(_who) : null,
    optional: _optional,
    onlyWhenMarked: _onlyWhenMarked,
    offInBreaks: _kind != PlanKind.lecture && _offInBreaks,
    note: _text(_note),
  );

  void _save() {
    final edit = ref.read(timetableEditControllerProvider.notifier);
    final id = widget.existing?.id;
    // Everything read now: the sheet is gone by the time the save lands.
    final draft = _block(id ?? '');
    Navigator.of(context).pop();
    unawaited(
      edit.apply(
        (w) => w.withBlock(
          id == null ? draft.withId(w.newBlockId(draft.title)) : draft,
        ),
      ),
    );
  }

  void _delete() {
    final edit = ref.read(timetableEditControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final gone = widget.existing!;
    Navigator.of(context).pop();
    unawaited(
      edit.apply((w) => w.withoutBlock(gone.id)).then((_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${gone.title} is off your week.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(edit.apply((w) => w.withBlock(gone))),
            ),
          ),
        );
      }),
    );
  }

  /// Moving the start moves the whole block: its length stays.
  void _moveStart(int start) {
    final length = _end - _start;
    setState(() {
      _start = start;
      _end = (start + length).clamp(start + 5, 24 * 60 - 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final existing = widget.existing;
    final clashes = _days.isEmpty || _end <= _start
        ? const <String>[]
        : timetableValidator.clashes(
            widget.week,
            _block(existing?.id ?? '\u0000new'),
          );
    final canSave = _days.isNotEmpty && _end > _start;

    Widget chip(
      String label,
      bool selected,
      VoidCallback onTap, {
      IconData? icon,
    }) => ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.text : AppTheme.textDim,
            ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) => onTap(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existing == null ? 'Add to the week' : 'Change it every week',
            style: t.headlineSmall,
          ),
          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in PlanKind.blockKinds)
                chip(
                  blockKindLabel(k),
                  _kind == k,
                  () => setState(() => _kind = k),
                  icon: blockKindIcon(k),
                ),
            ],
          ),
          Gap.m,
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What',
              hintText: blockKindLabel(_kind),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Gap.l,
          Row(
            children: [
              Expanded(child: Text('DAYS', style: AppTheme.overline)),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => setState(() {
                  if (_days.length == 7) {
                    _days.clear();
                  } else {
                    _days.addAll(Weekday.values);
                  }
                }),
                child: Text(_days.length == 7 ? 'None' : 'Every day'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in Weekday.values)
                FilterChip(
                  label: Text(_dayShort[d]!),
                  selected: _days.contains(d),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (on) => setState(() {
                    if (on) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
          Gap.l,
          Text('STARTS AT', style: AppTheme.overline),
          Gap.s,
          TimeStepper(
            minutes: _start,
            min: 0,
            max: 24 * 60 - 10,
            step: 5,
            bigStep: 60,
            onChanged: _moveStart,
          ),
          Gap.m,
          Text('ENDS AT', style: AppTheme.overline),
          Gap.s,
          TimeStepper(
            minutes: _end,
            min: _start + 5,
            max: 24 * 60 - 5,
            step: 5,
            bigStep: 60,
            onChanged: (m) => setState(() => _end = m),
          ),
          Gap.l,
          Text('WHERE', style: AppTheme.overline),
          Gap.s,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                'Anywhere',
                _place == null,
                () => setState(() => _place = null),
                icon: Icons.all_inclusive,
              ),
              for (final e in widget.week.places.entries)
                chip(
                  e.value,
                  _place == e.key,
                  () => setState(() => _place = e.key),
                  icon: Icons.place_outlined,
                ),
            ],
          ),
          Gap.xs,
          Text(
            _place == null
                ? 'No travel: it can be done wherever you are.'
                : '${plannerLength(widget.week.travelMinutes)} to get '
                      'there from anywhere else.',
            style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
          ),
          Gap.m,
          TextField(
            controller: _room,
            decoration: const InputDecoration(labelText: 'Room (optional)'),
          ),
          if (_kind == PlanKind.lecture) ...[
            Gap.s,
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Lecturer (optional)',
              ),
            ),
          ],
          Gap.m,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Optional'),
            subtitle: const Text('On the day, and skippable with a tap.'),
            value: _optional,
            onChanged: (v) => setState(() => _optional = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only on days I switch it on'),
            subtitle: const Text(
              'Off unless you turn it on for a date in the planner — like '
              'a shift every fifth week.',
            ),
            value: _onlyWhenMarked,
            onChanged: (v) => setState(() => _onlyWhenMarked = v),
          ),
          if (_kind != PlanKind.lecture)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Not in breaks'),
              subtitle: const Text(
                'Off over the winter break, on again after. Lectures always '
                'are.',
              ),
              value: _offInBreaks,
              onChanged: (v) => setState(() => _offInBreaks = v),
            ),
          Gap.s,
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          for (final c in clashes) ...[
            Gap.s,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.warn,
                ),
                Gap.s,
                Expanded(child: Text(c, style: t.bodySmall)),
              ],
            ),
          ],
          Gap.l,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: canSave ? _save : null,
              child: Text(
                !canSave
                    ? 'Pick a day'
                    : '${existing == null ? 'Add' : 'Save'} · '
                          '${daysLabel(Weekday.values.where(_days.contains).toList())} '
                          '${formatHhmm(_start)}–${formatHhmm(_end)}',
              ),
            ),
          ),
          if (existing != null) ...[
            Gap.s,
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete from the week'),
                onPressed: _delete,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A line of text on a sheet, saved with a button. Null when closed.
Future<String?> _showTextSheet(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
}) => showAppSheet<String>(
  context,
  builder: (_) => _TextSheet(title: title, label: label, initial: initial),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.title, required this.label, this.initial});

  final String title;
  final String label;
  final String? initial;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
        Gap.m,
        TextField(
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        Gap.l,
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => Navigator.pop(context, _text.text.trim()),
            child: const Text('Save'),
          ),
        ),
      ],
    ),
  );
}

class _TravelSheet extends StatefulWidget {
  const _TravelSheet({required this.initial});

  final int initial;

  @override
  State<_TravelSheet> createState() => _TravelSheetState();
}

class _TravelSheetState extends State<_TravelSheet> {
  late int _minutes = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Travel', style: t.headlineSmall),
          Gap.xs,
          Text(
            'From one place to another, and home. The planner draws the '
            'ride, and work rings when it is time to leave.',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          Gap.l,
          TimeStepper(
            minutes: _minutes,
            min: 0,
            max: 120,
            step: 5,
            asLength: true,
            onChanged: (m) => setState(() => _minutes = m),
          ),
          Gap.l,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.pop(context, _minutes),
              child: Text('Save · ${plannerLength(_minutes)}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds a break, or changes or deletes the one at [index].
Future<void> _showBreakSheet(
  BuildContext context,
  Timetable week, {
  int? index,
}) => showAppSheet<void>(
  context,
  builder: (_) => _BreakSheet(week: week, index: index),
);

class _BreakSheet extends ConsumerStatefulWidget {
  const _BreakSheet({required this.week, this.index});

  final Timetable week;
  final int? index;

  @override
  ConsumerState<_BreakSheet> createState() => _BreakSheetState();
}

class _BreakSheetState extends ConsumerState<_BreakSheet> {
  TimetableBreak? get _existing =>
      widget.index == null ? null : widget.week.breaks[widget.index!];

  late final _name = TextEditingController(text: _existing?.name);
  late DateTime _from = _existing?.from ?? widget.week.lecturesFrom;
  late DateTime _to =
      _existing?.to ??
      DateTime(
        widget.week.lecturesFrom.year,
        widget.week.lecturesFrom.month,
        widget.week.lecturesFrom.day + 6,
      );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(widget.week.lecturesFrom.year - 1),
      lastDate: DateTime(widget.week.lecturesTo.year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'No lectures from — to',
    );
    if (range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
    });
  }

  void _save({bool delete = false}) {
    final edit = ref.read(timetableEditControllerProvider.notifier);
    final index = widget.index;
    final name = _name.text.trim().isEmpty ? 'Break' : _name.text.trim();
    final b = TimetableBreak(name, _from, _to);
    Navigator.of(context).pop();
    unawaited(
      edit.apply((w) {
        final breaks = [...w.breaks];
        if (index == null) {
          breaks.add(b);
        } else if (delete) {
          breaks.removeAt(index);
        } else {
          breaks[index] = b;
        }
        return w.copyWith(breaks: breaks);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _existing == null ? 'Add a break' : 'A break',
            style: t.headlineSmall,
          ),
          Gap.xs,
          Text(
            'No lectures in it. Work, German and your own things go on; '
            'anything set to "Not in breaks" stops.',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Winter break',
            ),
          ),
          Gap.m,
          NavTile(
            icon: Icons.date_range_outlined,
            title: _dateRange(_from, _to),
            subtitle: 'Tap to change the dates',
            onTap: _pick,
          ),
          Gap.l,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _to.isBefore(_from) ? null : _save,
              child: Text(_existing == null ? 'Add' : 'Save'),
            ),
          ),
          if (_existing != null) ...[
            Gap.s,
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete the break'),
                onPressed: () => _save(delete: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Adds a place, or renames or deletes [id].
Future<void> _showPlaceSheet(
  BuildContext context,
  Timetable week, {
  String? id,
}) => showAppSheet<void>(
  context,
  builder: (_) => _PlaceSheet(week: week, id: id),
);

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet({required this.week, this.id});

  final Timetable week;
  final String? id;

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  late final _name = TextEditingController(
    text: widget.id == null ? null : widget.week.places[widget.id],
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final edit = ref.read(timetableEditControllerProvider.notifier);
    final name = _name.text.trim();
    final id = widget.id;
    Navigator.of(context).pop();
    unawaited(edit.apply((w) => w.withPlace(id ?? w.newPlaceId(name), name)));
  }

  void _delete() {
    final edit = ref.read(timetableEditControllerProvider.notifier);
    final id = widget.id!;
    Navigator.of(context).pop();
    unawaited(edit.apply((w) => w.withoutPlace(id)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final id = widget.id;
    final uses = id == null ? const <TimetableBlock>[] : widget.week.usesOf(id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(id == null ? 'Add a place' : 'A place', style: t.headlineSmall),
          Gap.xs,
          Text(
            'Somewhere a block of your week is. Getting from one place to '
            'another takes the travel time.',
            style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          TextField(
            controller: _name,
            autofocus: id == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Library',
            ),
            onChanged: (_) => setState(() {}),
          ),
          Gap.l,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(id == null ? 'Add' : 'Save'),
            ),
          ),
          if (id != null) ...[
            Gap.s,
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete the place'),
                onPressed: uses.isEmpty ? _delete : null,
              ),
            ),
            if (uses.isNotEmpty)
              Text(
                '${uses.first.title}${uses.length > 1 ? ' and ${uses.length - 1} more' : ''} '
                '${uses.length > 1 ? 'are' : 'is'} here. Move '
                '${uses.length > 1 ? 'them' : 'it'} first.',
                style: t.bodySmall!.copyWith(color: AppTheme.textFaint),
              ),
          ],
        ],
      ),
    );
  }
}
