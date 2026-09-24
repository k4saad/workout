import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fuel_providers.dart';
import '../../../app/providers.dart';
import '../../../core/ui/ui.dart';
import '../../../data/db/tables.dart';

/// The next thing to eat, on the screen he already has open.
///
/// A plan he has to go and look for is a plan he stops following in week
/// three. This is the whole Fuel tab reduced to the one decision in front of
/// him: eat this, now.
class NextMealCard extends ConsumerWidget {
  const NextMealCard({super.key, required this.now});

  /// Injected rather than read from the clock, so the card is testable and so
  /// the debug date picker moves it too.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final day = ref.watch(fuelDayProvider(today)).asData?.value;
    if (day == null) return const SizedBox.shrink();

    final clock =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final next = day.nextAfter(clock);
    final eaten = ref.watch(eatenTodayProvider(today)).asData?.value;

    // Everything eaten, or the day is over: say so rather than pointing at
    // yesterday's breakfast.
    if (next == null) {
      return AppCard(
        onTap: () => context.go('/fuel'),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.good),
            Gap.m,
            Expanded(
              child: Text(
                'That is the day’s food done. '
                '${(eaten?.kcal ?? 0).round()} kcal logged.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.go('/fuel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                next.slot.time,
                style: t.titleMedium?.copyWith(color: AppTheme.crimson),
              ),
              Gap.s,
              Expanded(
                child: Text(
                  next.slot.name,
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ),
              Text(
                '${next.chosen.kcal} kcal',
                style: t.bodySmall?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
          Gap.xs,
          Text(next.chosen.name, style: t.titleLarge),
          Gap.s,
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => ref
                      .read(mealLogControllerProvider)
                      .log(day: today, slot: next, status: MealStatus.eaten),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  child: const Text('Eaten'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => context.go('/fuel'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('The day'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
