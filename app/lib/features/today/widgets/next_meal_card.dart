import 'dart:async';

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
class NextMealCard extends ConsumerStatefulWidget {
  const NextMealCard({super.key, this.now});

  /// A fixed "now" for tests. Without it the card reads the clock, and moves
  /// on by itself every minute: Today stays alive behind the other tabs, and
  /// a card frozen at breakfast was still saying breakfast at two.
  final DateTime? now;

  @override
  ConsumerState<NextMealCard> createState() => _NextMealCardState();
}

class _NextMealCardState extends ConsumerState<NextMealCard> {
  Timer? _tick;

  DateTime get now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The header lives with the card, so neither shows without the other.
      const SectionHeader('Next to eat'),
      _card(context),
    ],
  );

  Widget _card(BuildContext context) {
    final today = ref.watch(todayProvider);
    final async = ref.watch(fuelDayProvider(today));
    if (async.hasError) return const SizedBox.shrink();
    final day = async.asData?.value;
    if (day == null) return const Skeleton(height: 112);

    final at = now;
    final clock =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final statuses = ref.watch(mealStatusProvider(today)).asData?.value;
    final next = day.nextToEat(
      now: clock,
      // A swap is a choice of meal, not a meal dealt with.
      logged: {
        for (final e in (statuses ?? const {}).entries)
          if (e.value != MealStatus.planned) e.key,
      },
    );
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
