import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../domain/fuel/fuel_plan.dart';

/// The other meals that fit this slot.
///
/// Every option was solved to the same slot target, so swapping cannot take
/// the day off its number — which is the whole reason the plan is built this
/// way rather than as one fixed menu he will abandon in week two.
class SwapSheet extends StatelessWidget {
  const SwapSheet({super.key, required this.slot, required this.plan});

  final PlannedMeal slot;
  final FuelPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot.slot.name, style: t.titleLarge),
            Gap.xs,
            Text(
              'All of these hit ${slot.slot.kcal} kcal and '
              '${slot.slot.proteinG} g of protein. Pick whichever you can '
              'face.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in slot.choices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => Navigator.pop(context, m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.name, style: t.titleMedium),
                                ),
                                if (m.id == slot.chosen.id)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.crimson,
                                    size: 20,
                                  ),
                              ],
                            ),
                            Gap.xs,
                            Text(
                              '${m.kcal} kcal · ${m.proteinG.round()} g protein'
                              '${m.costEur > 0 ? ' · €${m.costEur.toStringAsFixed(2)}' : ''}',
                              style: t.bodySmall?.copyWith(
                                color: AppTheme.textDim,
                              ),
                            ),
                            Gap.xs,
                            Text(
                              m.items
                                  .map(
                                    (i) =>
                                        '${plan.food(i.foodId)?.name ?? i.foodId} '
                                        '${i.grams.round()} g',
                                  )
                                  .join('  ·  '),
                              style: t.bodyMedium,
                            ),
                          ],
                        ),
                      ),
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
