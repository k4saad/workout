import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/inventory.dart';
import '../../domain/plates/lattice.dart';
import '../common/widgets.dart';

/// Bar weights and plate counts.
///
/// This screen is the most consequential configuration in the app. A bar
/// weight that is wrong by a kilo makes every suggested load wrong by a kilo,
/// and a plate count that is wrong makes the solver propose weights that
/// cannot be built. Until the bars have actually been on a bathroom scale,
/// every number the app shows is a guess and it says so.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  Inventory? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bundleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your gym'),
        actions: [
          if (_draft != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
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
        data: (b) {
          final inv = _draft ?? b.inventory;
          final lattice = Lattice(inv);
          return ListView(
            padding: Gap.pagePadding,
            children: [
              if (!inv.isCalibrated) const _NotMeasuredBanner(),
              Gap.l,
              _LatticePanel(lattice: lattice, inventory: inv),
              Gap.l,
              Text('Bars', style: Theme.of(context).textTheme.titleLarge),
              Gap.s,
              for (final bar in inv.bars)
                _BarRow(bar: bar, onChanged: (next) => _updateBar(inv, next)),
              Gap.l,
              Text('Plates', style: Theme.of(context).textTheme.titleLarge),
              Gap.xs,
              Text(
                'Count what you own. A plate that does not fit the bar is not '
                'inventory, however heavy it is.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textDim),
              ),
              Gap.s,
              for (final plate in inv.plates)
                _PlateRow(
                  plate: plate,
                  onChanged: (next) => _updatePlate(inv, next),
                ),
              Gap.l,
              const _MicroplateAdvice(),
              Gap.xl,
            ],
          );
        },
      ),
    );
  }

  void _updateBar(Inventory inv, Bar next) {
    setState(() {
      _draft = inv.copyWith(
        bars: [
          for (final b in inv.bars)
            if (b.id == next.id) next else b,
        ],
      );
    });
  }

  void _updatePlate(Inventory inv, PlateStock next) {
    setState(() {
      _draft = inv.copyWith(
        plates: [
          for (final p in inv.plates)
            if (p.weightKg == next.weightKg) next else p,
        ],
      );
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    await ref.read(programmeRepositoryProvider).saveInventory(draft);
    ref.invalidate(inventoryProvider);
    ref.invalidate(bundleProvider);
    if (!mounted) return;
    setState(() {
      _draft = null;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saved. Every suggested load now comes from your real numbers.',
        ),
      ),
    );
  }
}

class _NotMeasuredBanner extends StatelessWidget {
  const _NotMeasuredBanner();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.warn),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: AppTheme.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These are still placeholders',
                  style: t.titleMedium?.copyWith(color: AppTheme.warn),
                ),
              ),
            ],
          ),
          Gap.s,
          Text(
            'Stand on the bathroom scale, note the number, pick up the bar, '
            'note it again, subtract. Do it twice and average — scales are '
            'noisy at these weights.\n\n'
            'Weigh one plate of each size too: vinyl and cement plates are '
            'often 10 to 15% off their stamped value, and that error compounds '
            'across four plates.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Shows what the current numbers actually make loadable.
///
/// This is the feedback loop that makes calibration worth doing: change a bar
/// weight and watch the achievable weights move.
class _LatticePanel extends StatelessWidget {
  const _LatticePanel({required this.lattice, required this.inventory});

  final Lattice lattice;
  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final barbell = lattice.values(LoadMode.barbell);
    final step = lattice.nominalBarbellStep;
    final first = barbell.take(8).map(_fmt).join('  ');

    final coarse = step != null && step > 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What you can actually load', style: t.titleLarge),
            Gap.s,
            Text(
              'A barbell loads in pairs, so the weights that exist are the '
              'bar plus twice whatever goes on one side. Nothing between '
              'them is real.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$first  …',
                style: t.bodyLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Gap.m,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (step != null)
                  InfoChip(label: 'step ${_fmt(step)} kg', emphasis: coarse),
                InfoChip(
                  label: 'max ${_fmt(barbell.isEmpty ? 0 : barbell.last)} kg',
                ),
                if (inventory.smallestPlateKg != null)
                  InfoChip(
                    label:
                        'smallest plate '
                        '${_fmt(inventory.smallestPlateKg!)} kg',
                  ),
              ],
            ),
            if (coarse) ...[
              Gap.m,
              Text(
                'A ${_fmt(step)} kg step is 15% of a 17 kg bench press. That '
                'is far too big a jump for a beginner, so the app will hold '
                'the weight and add reps instead until you own finer plates.',
                style: t.bodyMedium?.copyWith(color: AppTheme.warn),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.bar, required this.onChanged});

  final Bar bar;
  final ValueChanged<Bar> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bar.name, style: t.titleMedium),
                Text(
                  bar.measured ? 'weighed' : 'estimate',
                  style: t.bodyMedium?.copyWith(
                    color: bar.measured ? AppTheme.good : AppTheme.warn,
                  ),
                ),
              ],
            ),
          ),
          _NumberStepper(
            value: bar.weightKg,
            step: 0.1,
            suffix: 'kg',
            onChanged: (v) =>
                onChanged(bar.copyWith(weightKg: v, measured: true)),
          ),
        ],
      ),
    );
  }
}

class _PlateRow extends StatelessWidget {
  const _PlateRow({required this.plate, required this.onChanged});

  final PlateStock plate;
  final ValueChanged<PlateStock> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_LatticePanel._fmt(plate.weightKg)} kg',
              style: t.titleMedium,
            ),
          ),
          _NumberStepper(
            value: plate.count.toDouble(),
            step: 1,
            suffix: '',
            onChanged: (v) => onChanged(plate.copyWith(count: v.round())),
          ),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.value,
    required this.step,
    required this.suffix,
    required this.onChanged,
  });

  final double value;
  final double step;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        _Tap(
          icon: Icons.remove,
          onTap: () => onChanged(
            double.parse((value - step).clamp(0.0, 999.0).toStringAsFixed(2)),
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            '${_LatticePanel._fmt(value)}${suffix.isEmpty ? '' : ' $suffix'}',
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _Tap(
          icon: Icons.add,
          onTap: () =>
              onChanged(double.parse((value + step).toStringAsFixed(2))),
        ),
      ],
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: AppTheme.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Icon(icon, size: 22, color: AppTheme.text),
        ),
      ),
    );
  }
}

class _MicroplateAdvice extends StatelessWidget {
  const _MicroplateAdvice();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The one purchase worth making', style: t.titleMedium),
            Gap.s,
            Text(
              'A pair of 0.5 kg and a pair of 0.25 kg standard-bore '
              'microplates costs about €20 and is worth more to this '
              'programme than anything else you could buy.\n\n'
              'With 1.25 kg as your smallest plate, the smallest jump on a '
              '17 kg bench is 15%. With 0.25 kg plates it is 3%. That is the '
              'difference between progressing every week and stalling.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
