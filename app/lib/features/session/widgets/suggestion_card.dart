import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/progression/progression_engine.dart';

/// What to put on the bar, and why.
///
/// The number on its own is not enough. Standing in front of a pile of plates,
/// what you want is "27 kg = bar 9 + (5 + 2.5 + 1.25) per side" — and then a
/// sentence explaining why it went up, stayed put, or came down, so the
/// decision is never a black box.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.unit = RepUnit.reps,
  });

  final LoadSuggestion suggestion;

  /// What the targets count: a run's are minutes, never "1500 reps".
  final RepUnit unit;

  Color get _accent {
    if (suggestion.isStalled) return AppTheme.warn;
    if (suggestion.isRepCreep) return AppTheme.dusk;
    return AppTheme.good;
  }

  IconData get _icon {
    if (suggestion.isStalled) return Icons.replay;
    if (suggestion.isRepCreep) return Icons.trending_flat;
    return Icons.trending_up;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = suggestion;
    final plates = s.plates;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        border: Border.all(color: _accent.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.suggestedKg != null)
                      Text(
                        '${_fmt(s.suggestedKg!)} kg  ·  '
                        '${unit.rangeLabel(s.repTargetMin, s.repTargetMax)}',
                        style: t.titleLarge?.copyWith(color: _accent),
                      )
                    else
                      Text(
                        unit.rangeLabel(s.repTargetMin, s.repTargetMax),
                        style: t.titleLarge?.copyWith(color: _accent),
                      ),
                    Gap.xs,
                    Text(s.reason, style: t.bodyMedium),
                  ],
                ),
              ),
            ],
          ),

          // How to actually build it.
          if (plates != null && plates.perSide.isNotEmpty) ...[
            Gap.s,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                plates.breakdown,
                style: t.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],

          if (plates?.warning != null) ...[
            Gap.s,
            _Note(text: plates!.warning!, color: AppTheme.warn),
          ],

          if (plates?.microplateHint != null) ...[
            Gap.s,
            _Note(text: plates!.microplateHint!, color: AppTheme.textDim),
          ],

          if (plates?.nextUpKg != null) ...[
            Gap.s,
            Text(
              'Next weight up is ${_fmt(plates!.nextUpKg!)} kg.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The warm-up ramp, shown before the first working set.
class RampStrip extends StatelessWidget {
  const RampStrip({super.key, required this.sets, required this.onLogRamp});

  final List<({double loadKg, int reps})> sets;
  final void Function(double loadKg, int reps) onLogRamp;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RAMP FIRST',
          style: t.labelLarge?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 1.2,
          ),
        ),
        Gap.s,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in sets)
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => onLogRamp(s.loadKg, s.reps),
                  child: Text('${SuggestionCard._fmt(s.loadKg)} × ${s.reps}'),
                ),
              ),
          ],
        ),
        Gap.xs,
        Text(
          'Absolute weights, not percentages — every one is loadable.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }
}
