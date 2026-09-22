import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/editor_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/prescription.dart';
import '../../domain/models/programme.dart';
import '../../domain/plates/lattice.dart';

/// Edit one prescription: sets, reps, rest, RIR, increment, opening load.
///
/// Steppers and chips throughout. Between heavy sets with chalky hands a
/// keyboard is the wrong input device, and the load stepper walks the
/// lattice — it can only ever produce a weight the plates can build.
class PrescriptionEditorSheet extends ConsumerStatefulWidget {
  const PrescriptionEditorSheet({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  ConsumerState<PrescriptionEditorSheet> createState() =>
      _PrescriptionEditorSheetState();
}

class _PrescriptionEditorSheetState
    extends ConsumerState<PrescriptionEditorSheet> {
  Prescription? _draft;
  TextEditingController? _note;

  @override
  void dispose() {
    _note?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(bundleProvider).asData?.value;
    if (bundle == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final current = _find(bundle.programme, widget.prescriptionId);
    if (current == null) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('That movement is no longer here.')),
      );
    }
    final p = _draft ??= current;
    _note ??= TextEditingController(text: p.coachNote ?? '');
    final exercise = bundle.library.resolve(p.exerciseId);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(exercise.name, style: t.titleLarge)),
                  TextButton.icon(
                    onPressed: () => _swap(bundle.library),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Swap'),
                  ),
                ],
              ),
              Gap.s,

              _Stepper(
                label: 'Sets',
                value: '${p.sets}',
                onDown: p.sets > 1
                    ? () => _edit((x) => x.copyWith(sets: x.sets - 1))
                    : null,
                onUp: () => _edit((x) => x.copyWith(sets: x.sets + 1)),
              ),
              _Stepper(
                label: 'Reps, low',
                value: '${p.repsMin}',
                onDown: p.repsMin > 1
                    ? () => _edit((x) => x.copyWith(repsMin: x.repsMin - 1))
                    : null,
                onUp: p.repsMin < p.repsMax
                    ? () => _edit((x) => x.copyWith(repsMin: x.repsMin + 1))
                    : null,
              ),
              _Stepper(
                label: 'Reps, high',
                value: '${p.repsMax}',
                onDown: p.repsMax > p.repsMin
                    ? () => _edit((x) => x.copyWith(repsMax: x.repsMax - 1))
                    : null,
                onUp: () => _edit((x) => x.copyWith(repsMax: x.repsMax + 1)),
              ),
              _Stepper(
                label: 'Rest',
                value: '${p.restSec}s',
                onDown: p.restSec >= 15
                    ? () => _edit((x) => x.copyWith(restSec: x.restSec - 15))
                    : null,
                onUp: () => _edit((x) => x.copyWith(restSec: x.restSec + 15)),
              ),

              Gap.m,
              Text('Reps in reserve', style: t.labelLarge),
              Gap.s,
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('block default'),
                    selected: p.targetRir == null,
                    onSelected: (_) =>
                        _edit((x) => x.copyWith(clearTargetRir: true)),
                  ),
                  for (final rir in [0, 1, 2, 3])
                    ChoiceChip(
                      label: Text('$rir'),
                      selected: p.targetRir == rir,
                      onSelected: (_) =>
                          _edit((x) => x.copyWith(targetRir: rir)),
                    ),
                ],
              ),

              if (p.loadMode.isPlateLoaded) ...[
                Gap.m,
                _LoadRow(
                  prescription: p,
                  lattice: bundle.lattice,
                  onChange: (kg) => _edit((x) => x.copyWith(startLoadKg: kg)),
                ),
                Gap.s,
                _Stepper(
                  label: 'Increment',
                  value: '${p.progression.incrementKg} kg',
                  onDown: p.progression.incrementKg > 0.5
                      ? () => _edit(
                          (x) => x.copyWith(
                            progression: x.progression.copyWith(
                              incrementKg: x.progression.incrementKg - 0.5,
                            ),
                          ),
                        )
                      : null,
                  onUp: () => _edit(
                    (x) => x.copyWith(
                      progression: x.progression.copyWith(
                        incrementKg: x.progression.incrementKg + 0.5,
                      ),
                    ),
                  ),
                ),
              ],

              Gap.s,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: p.optional,
                onChanged: (v) => _edit((x) => x.copyWith(optional: v)),
                title: const Text('Droppable when short on time'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: p.warmupRamp,
                onChanged: (v) => _edit((x) => x.copyWith(warmupRamp: v)),
                title: const Text('Generate warm-up ramp'),
              ),

              Gap.m,
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Coach note',
                  helperText: 'Shown on the card while you are lifting.',
                ),
              ),

              Gap.m,
              _Problems(draft: p),

              Gap.m,
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _remove,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Prescription? _find(Programme p, String id) {
    for (final b in p.blocks) {
      for (final d in b.days) {
        for (final s in d.sections) {
          for (final pre in s.prescriptions) {
            if (pre.id == id) return pre;
          }
        }
      }
    }
    return null;
  }

  void _edit(Prescription Function(Prescription) f) =>
      setState(() => _draft = f(_draft!));

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final text = _note!.text.trim();
    final draft = _draft!.copyWith(
      coachNote: text.isEmpty ? null : text,
      clearCoachNote: text.isEmpty,
    );
    await ref
        .read(programmeEditControllerProvider.notifier)
        .apply(
          (p) => programmeEditor.updatePrescription(
            p,
            widget.prescriptionId,
            (_) => draft,
          ),
        );
    navigator.pop();
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove this movement?'),
        content: const Text(
          'It comes out of the programme from now on. Sets you have already '
          'logged for it are kept — they belong to the exercise, not to this '
          'slot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(programmeEditControllerProvider.notifier)
        .apply(
          (p) => programmeEditor.removePrescription(p, widget.prescriptionId),
        );
    navigator.pop();
  }

  Future<void> _swap(ExerciseLibrary library) async {
    final current = _draft!;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _SwapSheet(current: current, library: library),
    );
    if (picked == null || !mounted) return;

    final navigator = Navigator.of(context);
    await ref
        .read(programmeEditControllerProvider.notifier)
        .apply(
          (p) => programmeEditor.swapExercise(p, widget.prescriptionId, picked),
        );
    navigator.pop();
  }
}

/// Live validation of the draft, before it is saved.
class _Problems extends ConsumerWidget {
  const _Problems({required this.draft});

  final Prescription draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).asData?.value;
    if (bundle == null) return const SizedBox.shrink();

    final messages = <String>[];
    if (draft.repsMin > draft.repsMax) {
      messages.add('The low rep target is above the high one.');
    }
    final kg = draft.startLoadKg;
    if (kg != null && !bundle.lattice.isValid(kg, draft.loadMode)) {
      messages.add('$kg kg is not a weight your plates can build.');
    }
    final creep = draft.repsCreepMax;
    if (creep != null && creep < draft.repsMax) {
      messages.add('Rep creep can never engage below the rep range.');
    }
    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in messages)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('! ', style: TextStyle(color: AppTheme.warn)),
                Expanded(
                  child: Text(m, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The opening load, stepped along the lattice so it is always loadable.
class _LoadRow extends StatelessWidget {
  const _LoadRow({
    required this.prescription,
    required this.lattice,
    required this.onChange,
  });

  final Prescription prescription;
  final Lattice lattice;
  final ValueChanged<double?> onChange;

  @override
  Widget build(BuildContext context) {
    final mode = prescription.loadMode;
    final values = lattice.values(mode);
    final kg = prescription.startLoadKg;
    final index = kg == null
        ? -1
        : values.indexWhere((v) => (v - kg).abs() < 1e-6);

    return _Stepper(
      label: 'Opening load',
      value: kg == null ? 'not set' : '$kg kg',
      onDown: index > 0 ? () => onChange(values[index - 1]) : null,
      onUp: values.isEmpty
          ? null
          : index < 0
          ? () => onChange(values.first)
          : index < values.length - 1
          ? () => onChange(values[index + 1])
          : null,
      hint: 'Only weights your plates can build',
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    this.onDown,
    this.onUp,
    this.hint,
  });

  final String label;
  final String value;
  final VoidCallback? onDown;
  final VoidCallback? onUp;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.titleMedium),
                if (hint != null)
                  Text(
                    hint!,
                    style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onDown,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 84,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
          ),
          IconButton.filledTonal(onPressed: onUp, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

/// Substitutes first — they were chosen for this slot — then the whole
/// library.
class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.current, required this.library});

  final Prescription current;
  final ExerciseLibrary library;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final subs = widget.current.substitutes
        .where(widget.library.contains)
        .map(widget.library.resolve)
        .toList();
    final query = _search.text.trim();
    final results = query.isEmpty
        ? const <Exercise>[]
        : widget.library.search(query).take(30).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Swap movement', style: t.titleLarge),
            Gap.xs,
            Text(
              'Your logged sets stay with the movement that earned them. The '
              'new one starts from its own history.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            if (subs.isNotEmpty) ...[
              Text('Suggested for this slot', style: t.labelLarge),
              Gap.s,
              for (final e in subs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: Text(
                    e.primaryMuscles.join(', '),
                    style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                  ),
                  onTap: () => Navigator.pop(context, e.id),
                ),
              Gap.m,
            ],
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search the library',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Gap.s,
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.name),
                      subtitle: Text(
                        e.equipment.join(', '),
                        style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                      ),
                      onTap: () => Navigator.pop(context, e.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
