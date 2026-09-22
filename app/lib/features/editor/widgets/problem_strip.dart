import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/programme/programme_validator.dart';

/// Validation problems, shown in place rather than in a dialog on save.
///
/// A dialog you dismiss at 21:40 is a dialog you forget. This sits above the
/// thing that is wrong until it is fixed, and names the gate so it matches
/// what `tools/validate.py` would say on the PC.
class ProblemStrip extends StatelessWidget {
  const ProblemStrip({super.key, required this.problems, this.dense = false});

  final List<Problem> problems;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final errors = problems.where((p) => p.isError).toList();
    final warnings = problems.where((p) => !p.isError).toList();
    final worst = errors.isNotEmpty ? AppTheme.oxblood : AppTheme.warn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: worst.withValues(alpha: 0.12),
        border: Border.all(color: worst.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                errors.isNotEmpty
                    ? Icons.error_outline
                    : Icons.warning_amber_rounded,
                size: 20,
                color: worst,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errors.isEmpty
                      ? '${warnings.length} thing(s) to look at'
                      : '${errors.length} thing(s) the app cannot work with',
                  style: t.titleMedium?.copyWith(color: worst),
                ),
              ),
            ],
          ),
          if (!dense) ...[
            const SizedBox(height: 8),
            for (final p in [...errors, ...warnings].take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.isError ? '✗' : '!',
                      style: t.bodyMedium?.copyWith(
                        color: p.isError ? AppTheme.oxblood : AppTheme.warn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.gate} · ${p.where} — ${p.message}',
                        style: t.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (problems.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'and ${problems.length - 6} more',
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
