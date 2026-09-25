import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;

import '../../app/editor_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/block.dart';
import '../../domain/models/day.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import 'day_editor_screen.dart';
import 'widgets/problem_strip.dart';

/// The programme, editable.
///
/// The point of this screen is that the programme is data, not code: when
/// Bulgarian split squats start wrecking your knee in week 6, you fix it in
/// the basement on the phone, not by editing JSON on a laptop upstairs.
class ProgrammeEditorScreen extends ConsumerWidget {
  const ProgrammeEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(programmeProvider);
    final problems = ref.watch(programmeProblemsProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit programme'),
        actions: [
          IconButton(
            tooltip: 'File',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => context.go('/more/settings/files'),
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
        data: (programme) => ListView(
          padding: Gap.pagePadding,
          children: [
            if (problems.isNotEmpty) ...[
              ProblemStrip(problems: problems),
              Gap.m,
            ],
            _RevisionLine(programme: programme),
            Gap.m,
            for (final block in programme.blocks) ...[
              _BlockCard(block: block, programme: programme),
              Gap.m,
            ],
            Gap.l,
            Text(
              'Edits are written to your own copy. The shipped programme is '
              'never touched, so "reset to shipped" always works.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionLine extends StatelessWidget {
  const _RevisionLine({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(programme.name, style: t.titleLarge)),
        InfoChip(label: 'rev ${programme.revision}'),
      ],
    );
  }
}

/// Adds an empty day on the first free weekday.
///
/// Empty rather than a copy of something: a new day is usually a new idea,
/// and the movements get added from the day editor.
Future<void> _addDay(BuildContext context, WidgetRef ref, Block block) async {
  final taken = {for (final d in block.days) d.weekday};
  final free = Weekday.values.firstWhereOrNull((w) => !taken.contains(w));
  if (free == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Every weekday already has a day.')),
    );
    return;
  }
  final id =
      '${block.id}-${free.name}-${DateTime.now().millisecondsSinceEpoch}';
  await ref
      .read(programmeEditControllerProvider.notifier)
      .apply(
        (p) => programmeEditor.addDay(
          p,
          block.id,
          Day(
            id: id,
            weekday: free,
            title: 'New day',
            kind: DayKind.lift,
            sections: const [Section(type: SectionType.main, title: 'Main')],
          ),
        ),
      );
}

class _BlockCard extends ConsumerWidget {
  const _BlockCard({required this.block, required this.programme});

  final Block block;
  final Programme programme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final weeks = block.weeks.isEmpty
        ? 'no weeks'
        : 'weeks ${block.firstWeek}–${block.lastWeek}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.name, style: t.titleMedium),
                    Gap.xs,
                    Text(
                      '$weeks · ${block.blockKind.name}',
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
              if (block.inherits)
                const Icon(Icons.link, size: 18, color: AppTheme.textDim),
            ],
          ),
          if (block.inherits) ...[
            Gap.s,
            _InheritedNote(block: block),
          ] else ...[
            for (final day in block.days) _DayRow(blockId: block.id, day: day),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addDay(context, ref, block),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add a day'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An inheriting block cannot be edited day by day — it has no days of its
/// own. Say that plainly and offer the way out.
class _InheritedNote extends ConsumerStatefulWidget {
  const _InheritedNote({required this.block});

  final Block block;

  @override
  ConsumerState<_InheritedNote> createState() => _InheritedNoteState();
}

class _InheritedNoteState extends ConsumerState<_InheritedNote> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = widget.block;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Runs the same days as "${b.inheritsDaysFrom}", '
          '${_multiplierLabel(b)}. Editing those days changes this block too.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
        Gap.s,
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _detach,
            icon: const Icon(Icons.call_split, size: 18),
            label: const Text('Detach and duplicate'),
          ),
        ),
      ],
    );
  }

  static String _multiplierLabel(Block b) {
    final parts = <String>[
      if (b.loadMultiplier != 1.0)
        'loads x${b.loadMultiplier.toStringAsFixed(2)}',
      if (b.setMultiplier != 1.0) 'sets x${b.setMultiplier.toStringAsFixed(2)}',
      if (!b.includeSupersets) 'supersets unwound',
      if (!b.includeFinishers) 'no finishers',
    ];
    return parts.isEmpty ? 'unchanged' : parts.join(', ');
  }

  Future<void> _detach() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Detach ${widget.block.name}?'),
        content: const Text(
          'This block gets its own copy of the resolved days, with the '
          'multipliers already applied. After that it stops following the '
          'block it inherited from, and you can edit the two separately.\n\n'
          'There is no undo, but nothing is lost: your logs are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Detach'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(programmeEditControllerProvider.notifier)
        .apply((p) => programmeEditor.detachAndDuplicate(p, widget.block.id));
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isSound
              ? '${widget.block.name} now has its own days.'
              : 'Detached, but ${result.errors.length} problem(s) to fix.',
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.blockId, required this.day});

  final String blockId;
  final Day day;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = day.loggedPrescriptions.length;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DayEditorScreen(blockId: blockId, dayId: day.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                day.weekday.name,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ),
            // A vertical tick in the day's colour, paired with the kind's
            // glyph below — colour is never the only carrier.
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.forKind(day.kind),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.title, style: t.titleMedium),
                  if (count > 0)
                    Text(
                      '$count movement${count == 1 ? '' : 's'}'
                      '${day.warnings.isEmpty ? '' : ' · ${day.warnings.length} warning'}',
                      style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textDim),
          ],
        ),
      ),
    );
  }
}
