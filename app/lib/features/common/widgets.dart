import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/day.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/prescription.dart';

/// A safety banner shown before the first set.
///
/// The deadlift bar-height note and the ceiling-clearance note live here —
/// they matter before your first rep, not buried in a cue list.
class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.warning});

  final DayWarning warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warn,
            size: 24,
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppTheme.warn),
                ),
                Gap.xs,
                Text(
                  warning.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The coloured rail that encodes `day.kind`.
///
/// Solid for required, dashed for optional. Always accompanied by a glyph
/// somewhere in the same row — colour alone is never the carrier.
class KindRail extends StatelessWidget {
  const KindRail({
    super.key,
    required this.kind,
    this.optional = false,
    this.height = 3,
  });

  final DayKind kind;
  final bool optional;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.forKind(kind);
    if (!optional) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          const dash = 6.0, gap = 4.0;
          final n = (c.maxWidth / (dash + gap)).floor().clamp(1, 200);
          return Row(
            children: List.generate(
              n,
              (i) => Container(
                width: dash,
                height: height,
                margin: EdgeInsets.only(right: i == n - 1 ? 0 : gap),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "1 set", "18 sets".
String setsLabel(int n) => n == 1 ? '1 set' : '$n sets';

/// A small labelled pill, used for sets/reps/rest/load.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasis = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis
            ? AppTheme.oxblood.withValues(alpha: 0.18)
            : AppTheme.surfaceHigh,
        border: Border.all(
          color: emphasis ? AppTheme.oxblood : AppTheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppTheme.textDim),
            const SizedBox(width: 5),
          ],
          // Flexible, not a bare Text: inside a Wrap the chip is handed the
          // full row width, and a long label on a 400 px phone would
          // otherwise overflow its own pill.
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: emphasis ? AppTheme.text : AppTheme.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders one prescription row inside a section card.
class PrescriptionRow extends StatelessWidget {
  const PrescriptionRow({
    super.key,
    required this.prescription,
    required this.exercise,
    this.supersetLabel,
    this.onTap,
  });

  final Prescription prescription;
  final Exercise exercise;

  /// e.g. "SS1" — shown when the movement is part of a superset.
  final String? supersetLabel;
  final VoidCallback? onTap;

  String get _loadLabel {
    final p = prescription;
    if (p.startLoadKg != null) {
      final kg = p.startLoadKg!;
      final s = kg == kg.roundToDouble()
          ? kg.toStringAsFixed(0)
          : kg.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
      return '$s kg';
    }
    return switch (p.loadMode) {
      LoadMode.bodyweight || LoadMode.bodyweightLoaded => 'bodyweight',
      LoadMode.banded => 'band',
      LoadMode.cable => 'cable',
      LoadMode.timed || LoadMode.distance => '—',
      _ => '—',
    };
  }

  String get _repsLabel {
    final p = prescription;
    final unit = p.unit.short;
    final range = p.repRangeLabel;
    final base = unit.isEmpty ? range : '$range $unit';
    return p.perSide ? '$base / side' : base;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (supersetLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.dusk.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      supersetLabel!,
                      style: t.labelLarge?.copyWith(
                        fontSize: 12,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    exercise.name,
                    style: t.titleMedium,
                    softWrap: true,
                  ),
                ),
                if (prescription.optional)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: AppTheme.textDim,
                    ),
                  ),
              ],
            ),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(
                  label: '${prescription.sets} × $_repsLabel',
                  emphasis: true,
                ),
                InfoChip(label: _loadLabel, icon: Icons.fitness_center),
                if (prescription.restSec > 0)
                  InfoChip(
                    label: '${prescription.restSec}s',
                    icon: Icons.timer_outlined,
                  ),
                if (prescription.targetRir != null)
                  InfoChip(label: 'RIR ${prescription.targetRir}'),
                if (prescription.warmupRamp)
                  const InfoChip(label: 'ramp', icon: Icons.stairs_outlined),
                if (prescription.tempo != null)
                  InfoChip(label: prescription.tempo!),
              ],
            ),
            if (prescription.coachNote != null) ...[
              Gap.s,
              Text(
                prescription.coachNote!,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full-width async guard so screens do not each reimplement
/// loading/error handling.
class AsyncScaffoldBody extends StatelessWidget {
  const AsyncScaffoldBody({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
  });

  final bool loading;
  final Object? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppTheme.warn),
            Gap.m,
            Text(
              'Could not load the programme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gap.s,
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      );
    }
    return child;
  }
}
