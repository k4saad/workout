import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/editor_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/day.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/prescription.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import 'prescription_editor_sheet.dart';
import 'widgets/problem_strip.dart';

/// One day, editable: order, supersets, warnings, and what each movement is.
class DayEditorScreen extends ConsumerWidget {
  const DayEditorScreen({
    super.key,
    required this.blockId,
    required this.dayId,
  });

  final String blockId;
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleProvider);
    final problems = (ref.watch(programmeProblemsProvider).asData?.value ?? [])
        .where((p) => p.where.startsWith(dayId))
        .toList();

    return async.when(
      loading: () => const Scaffold(body: SkeletonPage()),
      error: (e, _) => Scaffold(
        body: AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
      ),
      data: (bundle) {
        final day = _dayOf(bundle.programme);
        if (day == null) {
          return const Scaffold(
            body: Center(
              child: Text('That day is no longer in the programme.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(day.title),
            actions: [
              IconButton(
                tooltip: 'Day settings',
                icon: const Icon(Icons.tune),
                onPressed: () => _editDay(context, ref, day),
              ),
            ],
          ),
          body: ListView(
            padding: Gap.pagePadding,
            children: [
              if (problems.isNotEmpty) ...[
                ProblemStrip(problems: problems),
                Gap.m,
              ],
              Row(
                children: [
                  InfoChip(label: day.weekday.name),
                  const SizedBox(width: 8),
                  InfoChip(label: day.kind.name),
                  const SizedBox(width: 8),
                  if (day.estMinutes > 0)
                    InfoChip(
                      label: '${day.estMinutes} min',
                      icon: Icons.schedule,
                    ),
                ],
              ),
              for (final w in day.warnings) ...[
                Gap.m,
                WarningBanner(warning: w),
              ],
              for (final section in day.sections) ...[
                Gap.l,
                _SectionBlock(
                  day: day,
                  section: section,
                  library: bundle.library,
                ),
              ],
              Gap.xl,
              Text(
                'Your logs are keyed to the movement, not to this slot. Swap '
                'an exercise and the old history stays with the old exercise; '
                'the new one starts from its own.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
        );
      },
    );
  }

  Day? _dayOf(Programme p) {
    for (final b in p.blocks) {
      for (final d in b.days) {
        if (d.id == dayId) return d;
      }
    }
    return null;
  }

  Future<void> _editDay(BuildContext context, WidgetRef ref, Day day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => DaySettingsSheet(day: day),
    );
  }
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.day,
    required this.section,
    required this.library,
  });

  final Day day;
  final Section section;
  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final groups = section.groups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: t.titleLarge),
        if (section.prescriptions.isEmpty && section.drills.isNotEmpty) ...[
          Gap.s,
          Text(
            '${section.drills.length} drills, ticked not logged. '
            'Edit these in the programme file.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
        ],
        for (var gi = 0; gi < groups.length; gi++) ...[
          Gap.s,
          _GroupCard(
            group: groups[gi],
            library: library,
            isFirst: gi == 0,
            isLast: gi == groups.length - 1,
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({
    required this.group,
    required this.library,
    required this.isFirst,
    required this.isLast,
  });

  final List<Prescription> group;
  final ExerciseLibrary library;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final isSuperset = group.length > 1;
    final controller = ref.read(programmeEditControllerProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperset)
            Row(
              children: [
                const Icon(Icons.repeat, size: 16, color: AppTheme.dusk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Superset — alternate, rest once at the end',
                    style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.apply(
                    (p) => programmeEditor.ungroupSuperset(
                      p,
                      group.first.groupId!,
                    ),
                  ),
                  child: const Text('Unpair'),
                ),
              ],
            ),
          for (final p in group)
            _MovementRow(
              prescription: p,
              exercise: library.resolve(p.exerciseId),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: isFirst
                    ? null
                    : () => controller.apply(
                        (p) => programmeEditor.movePrescription(
                          p,
                          group.first.id,
                          up: true,
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: isLast
                    ? null
                    : () => controller.apply(
                        (p) => programmeEditor.movePrescription(
                          p,
                          group.first.id,
                          up: false,
                        ),
                      ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends ConsumerWidget {
  const _MovementRow({required this.prescription, required this.exercise});

  final Prescription prescription;
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = prescription;

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        builder: (_) => PrescriptionEditorSheet(prescriptionId: p.id),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: t.titleMedium),
                  Gap.xs,
                  Text(
                    '${p.sets} x ${p.repRangeLabel}'
                    '${p.unit.short.isEmpty ? '' : ' ${p.unit.short}'}'
                    '${p.startLoadKg == null ? '' : ' @ ${_kg(p.startLoadKg!)}'}'
                    ' · ${p.restSec}s rest',
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textDim),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? '${v.toStringAsFixed(0)} kg' : '$v kg';
}

/// Weekday, kind, title and warnings.
class DaySettingsSheet extends ConsumerStatefulWidget {
  const DaySettingsSheet({super.key, required this.day});

  final Day day;

  @override
  ConsumerState<DaySettingsSheet> createState() => _DaySettingsSheetState();
}

class _DaySettingsSheetState extends ConsumerState<DaySettingsSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.day.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.day.note ?? '',
  );
  late Weekday _weekday = widget.day.weekday;
  late DayKind _kind = widget.day.kind;
  late bool _optional = widget.day.optional;
  late final List<DayWarning> _warnings = [...widget.day.warnings];

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Day settings', style: t.titleLarge),
              Gap.m,
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              Gap.m,
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Coach note',
                  helperText: 'Read before the first set.',
                ),
              ),
              Gap.m,
              Text('Weekday', style: t.labelLarge),
              Gap.s,
              Wrap(
                spacing: 8,
                children: [
                  for (final w in Weekday.values)
                    ChoiceChip(
                      label: Text(w.name),
                      selected: _weekday == w,
                      onSelected: (_) => setState(() => _weekday = w),
                    ),
                ],
              ),
              Gap.m,
              Text('Kind', style: t.labelLarge),
              Gap.s,
              Wrap(
                spacing: 8,
                children: [
                  for (final k in DayKind.values)
                    ChoiceChip(
                      label: Text(k.name),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              Gap.s,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _optional,
                onChanged: (v) => setState(() => _optional = v),
                title: const Text('Optional'),
                subtitle: const Text('Skipping it does not break the streak.'),
              ),
              Gap.m,
              Row(
                children: [
                  Expanded(child: Text('Warnings', style: t.labelLarge)),
                  TextButton.icon(
                    onPressed: _addWarning,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              for (var i = 0; i < _warnings.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_warnings[i].title),
                  subtitle: Text(
                    _warnings[i].body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _warnings.removeAt(i)),
                  ),
                ),
              Gap.l,
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
              Gap.s,
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: _removeDay,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove this day'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addWarning() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('New warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'What to watch'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && mounted && title.text.trim().isNotEmpty) {
      setState(
        () => _warnings.add(
          DayWarning(title: title.text.trim(), body: body.text.trim()),
        ),
      );
    }
    title.dispose();
    body.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ref
        .read(programmeEditControllerProvider.notifier)
        .apply(
          (p) => programmeEditor.updateDay(
            p,
            widget.day.id,
            (d) => d.copyWith(
              title: _title.text.trim().isEmpty ? d.title : _title.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              clearNote: _note.text.trim().isEmpty,
              weekday: _weekday,
              kind: _kind,
              optional: _optional,
              warnings: _warnings,
            ),
          ),
        );
    navigator.pop();
  }

  Future<void> _removeDay() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Remove ${widget.day.title}?'),
        content: const Text(
          'The day comes out of every week this block covers. Sessions you '
          'have already logged against it are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.oxblood),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(programmeEditControllerProvider.notifier)
        .apply((p) => programmeEditor.removeDay(p, widget.day.id));
    navigator
      ..pop()
      ..pop();
  }
}
