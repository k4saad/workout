import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/fuel_providers.dart';
import '../../../app/providers.dart';
import '../../../core/ui/ui.dart';
import '../../../data/db/tables.dart';
import '../../../domain/fuel/fuel_plan.dart';

/// One slot: the time, the meal, what it weighs, and the three buttons that
/// close it out.
///
/// Grams are shown, always. "Chicken and rice" is a serving suggestion; 95 g
/// of rice and 80 g of chicken is a meal that hits a number.
class MealCard extends ConsumerWidget {
  const MealCard({
    super.key,
    required this.slot,
    required this.date,
    required this.onSwap,
    this.isAroundSession = false,
  });

  final PlannedMeal slot;
  final DateTime date;
  final VoidCallback onSwap;

  /// The two meals either side of training. Marked because their TIMING is
  /// the point, not just their contents.
  final bool isAroundSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final plan = ref.watch(fuelPlanProvider).asData?.value;
    final meals = ref.watch(mealStatusProvider(date)).asData?.value ?? {};
    final status = meals[slot.slot.id];

    final done = status == MealStatus.eaten;
    final half = status == MealStatus.partial;
    final skipped = status == MealStatus.skipped;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    slot.time,
                    style: t.titleMedium?.copyWith(
                      color: isAroundSession
                          ? AppTheme.crimson
                          : AppTheme.textDim,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.slot.name,
                        style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                      ),
                      Text(slot.chosen.name, style: t.titleMedium),
                    ],
                  ),
                ),
                // Colour alone never carries state.
                if (done)
                  const Icon(Icons.check_circle, color: AppTheme.good)
                else if (half)
                  const Icon(Icons.adjust, color: AppTheme.warn)
                else if (skipped)
                  const Icon(Icons.cancel_outlined, color: AppTheme.textDim),
                if (slot.choices.length > 1)
                  IconButton(
                    tooltip: '${slot.choices.length - 1} other meals',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: onSwap,
                  ),
              ],
            ),

            // Where the day put it: a shift with no gap, a short one.
            if (slot.timing case final timing?
                when timing.packed || timing.quick || isAroundSession) ...[
              Gap.s,
              Row(
                children: [
                  Icon(
                    timing.packed
                        ? Icons.work_outline
                        : isAroundSession
                        ? Icons.bolt
                        : Icons.timer_outlined,
                    size: 16,
                    color: isAroundSession
                        ? AppTheme.crimson
                        : AppTheme.textDim,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (timing.packed) 'Packed — eat it at work',
                        if (timing.quick) 'Quick — a short gap',
                        if (isAroundSession) 'Fuel for the session',
                      ].join(' · '),
                      style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
            ],
            Gap.s,
            Text(
              '${slot.chosen.kcal} kcal  ·  ${slot.chosen.proteinG.round()} g protein',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),

            Gap.s,
            if (plan != null)
              Text(
                slot.chosen.items
                    .map(
                      (i) =>
                          '${plan.food(i.foodId)?.name ?? i.foodId} '
                          '${i.grams.round()} g',
                    )
                    .join('  ·  '),
                style: t.bodyMedium,
              ),

            if (slot.chosen.note != null) ...[
              Gap.s,
              Text(
                slot.chosen.note!,
                style: t.bodySmall?.copyWith(
                  color: AppTheme.textDim,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            Gap.m,
            // Three equal thirds. Icons and labels together overflowed 400 px
            // once the swap button shared the row; the swap moved into the
            // header and these carry the label alone.
            Row(
              children: [
                Expanded(
                  child: _Action(
                    label: 'Eaten',
                    selected: done,
                    onTap: () => _log(ref, MealStatus.eaten),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action(
                    label: 'Half',
                    selected: half,
                    onTap: () => _log(ref, MealStatus.partial),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action(
                    label: 'Skip',
                    selected: skipped,
                    onTap: () => _log(ref, MealStatus.skipped),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _log(WidgetRef ref, MealStatus status) => ref
      .read(mealLogControllerProvider)
      .log(day: date, slot: slot, status: status);
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, 46);
    const pad = EdgeInsets.symmetric(horizontal: 4);
    // Selected carries a tick as well as the fill: colour is never the only
    // thing that says which one took.
    return selected
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(minimumSize: size, padding: pad),
            icon: const Icon(Icons.check, size: 18),
            label: Text(label),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(minimumSize: size, padding: pad),
            child: Text(label),
          );
  }
}
