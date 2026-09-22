import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/session_service.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/prescription.dart';

/// What the athlete is about to log.
class PendingSet {
  const PendingSet({
    this.reps,
    this.loadKg,
    this.durationSec,
    this.distanceM,
    this.rir,
  });

  final int? reps;
  final double? loadKg;
  final int? durationSec;
  final int? distanceM;
  final int? rir;

  PendingSet copyWith({
    int? reps,
    double? loadKg,
    int? durationSec,
    int? distanceM,
    int? rir,
    bool clearRir = false,
  }) => PendingSet(
    reps: reps ?? this.reps,
    loadKg: loadKg ?? this.loadKg,
    durationSec: durationSec ?? this.durationSec,
    distanceM: distanceM ?? this.distanceM,
    rir: clearRir ? null : (rir ?? this.rir),
  );
}

/// The input block for one set.
///
/// Steppers and chips, not keyboards. You are using this with chalky hands,
/// between heavy sets, in bad light — every control is at least 48 dp and the
/// common case takes zero typing.
class SetInput extends StatelessWidget {
  const SetInput({
    super.key,
    required this.prescription,
    required this.value,
    required this.onChanged,
    required this.latticeStep,
  });

  final Prescription prescription;
  final PendingSet value;
  final ValueChanged<PendingSet> onChanged;

  /// The smallest loadable increment. Stepping by anything else would suggest
  /// a weight the plates cannot make.
  final double latticeStep;

  @override
  Widget build(BuildContext context) {
    final kind = SessionService.inputKindFor(prescription);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (kind) {
          SetInputKind.repsAndLoad => Column(
            children: [
              _RepsStepper(
                value: value.reps ?? prescription.repsMin,
                min: 0,
                max: 60,
                target: prescription.repRangeLabel,
                onChanged: (v) => onChanged(value.copyWith(reps: v)),
              ),
              Gap.m,
              _LoadStepper(
                value: value.loadKg ?? prescription.startLoadKg ?? 0,
                step: latticeStep,
                onChanged: (v) => onChanged(value.copyWith(loadKg: v)),
              ),
            ],
          ),
          SetInputKind.reps => _RepsStepper(
            value: value.reps ?? prescription.repsMin,
            min: 0,
            max: 100,
            target: prescription.repRangeLabel,
            onChanged: (v) => onChanged(value.copyWith(reps: v)),
          ),
          SetInputKind.duration => _RepsStepper(
            value: value.durationSec ?? prescription.repsMax,
            min: 0,
            max: 3600,
            step: 5,
            unit: 's',
            target: '${prescription.repRangeLabel} s',
            onChanged: (v) => onChanged(value.copyWith(durationSec: v)),
          ),
          SetInputKind.distance => _RepsStepper(
            value: value.distanceM ?? prescription.repsMax,
            min: 0,
            max: 50000,
            step: 100,
            unit: 'm',
            target: '${prescription.repRangeLabel} m',
            onChanged: (v) => onChanged(value.copyWith(distanceM: v)),
          ),
        },
        if (prescription.targetRir != null) ...[
          Gap.m,
          _RirChips(
            value: value.rir,
            target: prescription.targetRir!,
            onChanged: (v) => onChanged(
              v == null
                  ? value.copyWith(clearRir: true)
                  : value.copyWith(rir: v),
            ),
          ),
        ],
      ],
    );
  }
}

class _RepsStepper extends StatelessWidget {
  const _RepsStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.target,
    this.step = 1,
    this.unit = '',
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final String target;
  final ValueChanged<int> onChanged;

  void _bump(int by) {
    final next = (value + by).clamp(min, max);
    if (next != value) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unit == 's'
              ? 'SECONDS  ·  target $target'
              : unit == 'm'
              ? 'METRES  ·  target $target'
              : 'REPS  ·  target $target',
          style: t.labelLarge?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 1.1,
          ),
        ),
        Gap.s,
        Row(
          children: [
            _BigStepButton(icon: Icons.remove, onTap: () => _bump(-step)),
            Expanded(
              child: Center(
                child: Text(
                  '$value$unit',
                  style: t.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            _BigStepButton(icon: Icons.add, onTap: () => _bump(step)),
          ],
        ),
      ],
    );
  }
}

class _LoadStepper extends StatelessWidget {
  const _LoadStepper({
    required this.value,
    required this.step,
    required this.onChanged,
  });

  final double value;
  final double step;
  final ValueChanged<double> onChanged;

  String get _label {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _bump(double by) {
    final next = (value + by).clamp(0.0, 500.0);
    HapticFeedback.selectionClick();
    onChanged(double.parse(next.toStringAsFixed(3)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOAD  ·  steps of ${step == step.roundToDouble() ? step.toStringAsFixed(0) : step} kg',
          style: t.labelLarge?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 1.1,
          ),
        ),
        Gap.s,
        Row(
          children: [
            _BigStepButton(icon: Icons.remove, onTap: () => _bump(-step)),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _label,
                      style: t.displaySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'kg',
                      style: t.titleMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
            ),
            _BigStepButton(icon: Icons.add, onTap: () => _bump(step)),
          ],
        ),
      ],
    );
  }
}

class _BigStepButton extends StatelessWidget {
  const _BigStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: AppTheme.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, size: 30, color: AppTheme.text),
        ),
      ),
    );
  }
}

class _RirChips extends StatelessWidget {
  const _RirChips({
    required this.value,
    required this.target,
    required this.onChanged,
  });

  final int? value;
  final int target;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPS IN RESERVE  ·  target $target',
          style: t.labelLarge?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 1.1,
          ),
        ),
        Gap.s,
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i <= 4; i++)
              SizedBox(
                height: 48,
                width: 56,
                child: Material(
                  color: value == i
                      ? AppTheme.oxblood.withValues(alpha: 0.35)
                      : AppTheme.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: value == i ? AppTheme.oxblood : AppTheme.outline,
                      width: value == i ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(value == i ? null : i);
                    },
                    child: Center(
                      child: Text(
                        i == 4 ? '4+' : '$i',
                        style: t.titleLarge?.copyWith(
                          color: value == i ? AppTheme.text : AppTheme.textDim,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "last time: 8, 8, 7 @ 25 kg" — the most useful line on the screen.
class LastTimeLine extends StatelessWidget {
  const LastTimeLine({super.key, required this.sets, required this.unit});

  final List<({int? reps, double? loadKg, int? durationSec})> sets;
  final RepUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (sets.isEmpty) {
      return Text(
        'First time — start at the prescribed load and leave reps in '
        'the tank.',
        style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
      );
    }

    final values = unit == RepUnit.sec
        ? sets.map((s) => '${s.durationSec ?? 0}s').join(', ')
        : sets.map((s) => '${s.reps ?? 0}').join(', ');

    final loads = sets
        .map((s) => s.loadKg)
        .whereType<double>()
        .toSet()
        .toList();
    final loadLabel = loads.isEmpty
        ? ''
        : loads.length == 1
        ? ' @ ${_fmt(loads.first)} kg'
        : ' @ ${loads.map(_fmt).join('/')} kg';

    return Row(
      children: [
        const Icon(Icons.history, size: 16, color: AppTheme.textDim),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Last time: $values$loadLabel',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
