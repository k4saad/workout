import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/editor_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/progression/cycle_seeder.dart';
import '../common/widgets.dart';

/// Week 13: what happens next.
///
/// The Test block's numbers become the next cycle's opening loads. Shown as a
/// diff, because this overwrites the programme you just spent twelve weeks
/// on and "it changed my squat and I do not know why" is not acceptable.
class CycleSeedScreen extends ConsumerWidget {
  const CycleSeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cycleSeedProvider);
    final library = ref.watch(exerciseLibraryProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Next cycle')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (seed) => ListView(
          padding: Gap.pagePadding,
          children: [
            _Headline(seed: seed),
            Gap.m,
            if (seed.testedCount == 0) const _NoResultsNote(),
            for (final note in seed.notes) ...[_Note(text: note), Gap.s],
            Gap.m,
            Text(
              'Opening loads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gap.s,
            Text(
              'Every number below is snapped down to a weight your plates can '
              'actually build, and every e1RM is an estimate — Epley from a '
              'five-rep set, not a number you have lifted.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            for (final c in seed.movedLoads)
              _ChangeRow(
                change: c,
                name: library?.resolve(c.exerciseId).name ?? c.exerciseId,
              ),
            if (seed.movedLoads.isEmpty)
              Text(
                'Nothing moved. Log the test week first, then come back.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textDim),
              ),
            Gap.xl,
            _ApplyButton(seed: seed),
            Gap.xl,
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.seed});

  final CycleSeed seed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(seed.programme.name, style: t.headlineSmall),
            Gap.s,
            Text(
              '${seed.programme.totalWeeks} weeks, starting '
              '${DateFormat('EEEE d MMMM').format(seed.programme.startDate)}.',
              style: t.bodyLarge,
            ),
            Gap.xs,
            Text(
              seed.headline,
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsNote extends StatelessWidget {
  const _NoResultsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warn),
          Gap.m,
          Expanded(
            child: Text(
              'No test-week sets logged yet. Everything below carries over '
              'from your last logged loads, which is a fine fallback but not '
              'what the Test block is for.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3, right: 8),
          child: Icon(Icons.info_outline, size: 16, color: AppTheme.textDim),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.name});

  final LoadChange change;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final delta = change.deltaKg;
    final up = delta != null && delta > 0;
    final glyph = delta == null
        ? '·'
        : up
        ? '↑'
        : '↓';
    final colour = delta == null
        ? AppTheme.textDim
        : up
        ? AppTheme.good
        : AppTheme.warn;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(glyph, style: t.titleMedium?.copyWith(color: colour)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleMedium),
                Gap.xs,
                Text(
                  '${_kg(change.oldKg)} → ${_kg(change.newKg)}'
                  '${change.role == SeedRole.lead ? '  ·  lead lift' : ''}',
                  style: t.bodyMedium?.copyWith(color: colour),
                ),
                Text(
                  change.reason,
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _kg(double? v) {
    if (v == null) return 'none';
    return v == v.roundToDouble()
        ? '${v.toStringAsFixed(0)} kg'
        : '${v.toStringAsFixed(1)} kg';
  }
}

class _ApplyButton extends ConsumerStatefulWidget {
  const _ApplyButton({required this.seed});

  final CycleSeed seed;

  @override
  ConsumerState<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends ConsumerState<_ApplyButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _busy ? null : _apply,
        icon: const Icon(Icons.play_arrow),
        label: Text(_busy ? 'Starting…' : 'Start this cycle'),
      ),
    );
  }

  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Replace the programme?'),
        content: const Text(
          'The new cycle becomes your programme from here. Every set, photo '
          'and weigh-in you have logged is kept — they belong to you, not to '
          'the programme file.\n\n'
          'Export a backup first if you want the old one on the PC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start it'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final result = await ref
        .read(programmeEditControllerProvider.notifier)
        .applySeed(widget.seed);
    if (!mounted) return;
    setState(() => _busy = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isSound
              ? 'Cycle started. Week 1 begins Monday.'
              : 'Started, but ${result.errors.length} problem(s) need a look.',
        ),
      ),
    );
    // The cycle is already saved. Going home is a courtesy, not a step that
    // may fail the operation.
    GoRouter.maybeOf(context)?.go('/');
  }
}
