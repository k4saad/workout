import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/fuel_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/fuel_service.dart';
import '../../domain/fuel/fuel_plan.dart';
import '../common/widgets.dart';
import 'widgets/meal_card.dart';
import 'widgets/swap_sheet.dart';

/// The Fuel tab: what to eat today, and whether it got eaten.
///
/// Laid out as the day runs, not as a list of food groups. The session is the
/// fixed point everything else is placed around — that is how the plan is
/// actually lived, and it is why the two meals nearest training say so.
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final async = ref.watch(fuelDayProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel'),
        actions: [
          IconButton(
            tooltip: 'Shopping and guide',
            icon: const Icon(Icons.local_grocery_store_outlined),
            onPressed: () => _openGroceries(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (day) => _Body(day: day, date: today),
      ),
    );
  }

  Future<void> _openGroceries(BuildContext context, WidgetRef ref) async {
    final plan = await ref.read(fuelPlanProvider.future);
    final today = ref.read(todayProvider);
    final day = await ref.read(fuelDayProvider(today).future);
    if (!context.mounted) return;

    // A week of the day he is on: five training days, two rest.
    final week = [
      for (var i = 0; i < 7; i++)
        plan.forDay(
          weekNo: day.weekNo,
          isTrainingDay: i < 5,
          extraKcal: day.extraKcal,
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _GrocerySheet(lines: plan.groceries(week), plan: plan),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.day, required this.date});

  final FuelDay day;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final eaten = ref.watch(eatenTodayProvider(date)).asData?.value;
    final target = day.totals;

    return ListView(
      padding: Gap.pagePadding,
      children: [
        _Rings(target: target, eaten: eaten),
        Gap.m,
        Text(
          day.isTrainingDay
              ? 'Training day. The two meals either side of the session are '
                    'timed, not optional.'
              : 'Rest day. Same calories — the muscle is built today.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),

        if (day.extraKcal != 0) ...[
          Gap.m,
          ToneBanner(
            tone: Tone.good,
            icon: Icons.trending_up,
            title:
                '${day.extraKcal > 0 ? '+' : ''}${day.extraKcal} kcal applied',
            body:
                'On top of the phase target, and it stays on until you take '
                'it off in Body → adjustments.',
          ),
        ],

        Gap.l,
        const SectionHeader('The day'),
        for (final slot in day.slots)
          MealCard(
            slot: slot,
            date: date,
            isAroundSession:
                slot.slot.id == 'pre_training' ||
                slot.slot.id == 'post_training',
            onSwap: () => _swap(context, ref, slot),
          ),

        if (day.module != null) ...[
          Gap.l,
          _ModuleCard(module: day.module!, plan: day.plan),
        ],

        Gap.l,
        _Water(date: date),
        Gap.l,
        _Supplements(date: date, plan: day.plan),
        Gap.xl,
      ],
    );
  }

  Future<void> _swap(
    BuildContext context,
    WidgetRef ref,
    PlannedMeal slot,
  ) async {
    final picked = await showModalBottomSheet<Meal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => SwapSheet(slot: slot, plan: day.plan),
    );
    if (picked == null) return;
    await ref
        .read(mealLogControllerProvider)
        .swap(day: date, slot: slot, to: picked);
  }
}

/// Calories and protein, as rings. Two numbers, because those are the two
/// that decide whether this works.
class _Rings extends StatelessWidget {
  const _Rings({required this.target, this.eaten});

  final Macros target;
  final EatenMacros? eaten;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kcal = eaten?.kcal ?? 0;
    final protein = eaten?.proteinG ?? 0;

    return AppCard(
      child: Row(
        children: [
          RingProgress(
            value: target.kcal == 0 ? 0 : kcal / target.kcal,
            size: 104,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${kcal.round()}', style: t.headlineSmall),
                Text(
                  'of ${target.kcal.round()}',
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          Gap.l,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('kcal today', style: t.titleMedium),
                Gap.s,
                _Bar(
                  label: 'Protein',
                  value: protein,
                  target: target.proteinG,
                  unit: 'g',
                ),
                Gap.s,
                _Bar(
                  label: 'Carbs',
                  value: eaten?.carbsG ?? 0,
                  target: target.carbsG,
                  unit: 'g',
                  colour: AppTheme.textDim,
                ),
                Gap.s,
                _Bar(
                  label: 'Fat',
                  value: eaten?.fatG ?? 0,
                  target: target.fatG,
                  unit: 'g',
                  colour: AppTheme.textDim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    this.colour = AppTheme.crimson,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: t.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: target == 0 ? 0 : (value / target).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Text(
            '${value.round()} / ${target.round()} $unit',
            textAlign: TextAlign.right,
            style: t.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.plan});

  final FuelModule module;
  final FuelPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppTheme.crimson),
              Gap.s,
              Expanded(child: Text(module.name, style: t.titleMedium)),
              Text('+${module.kcal} kcal', style: t.titleMedium),
            ],
          ),
          if (module.note != null) ...[
            Gap.xs,
            Text(
              module.note!,
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
          Gap.s,
          // Shown as food, not as a number to somehow acquire.
          Text(
            module.items
                .map(
                  (i) =>
                      '${plan.food(i.foodId)?.name ?? i.foodId} ${i.grams.round()} g',
                )
                .join('  ·  '),
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Water extends ConsumerWidget {
  const _Water({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final ml = ref.watch(waterTodayProvider(date)).asData?.value ?? 0;
    final plan = ref.watch(fuelPlanProvider).asData?.value;
    final target = plan?.hydrationMl ?? 3000;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: AppTheme.textDim),
              Gap.s,
              Expanded(child: Text('Water', style: t.titleMedium)),
              Text(
                '${(ml / 1000).toStringAsFixed(1)} of '
                '${(target / 1000).toStringAsFixed(1)} L',
                style: t.titleMedium,
              ),
            ],
          ),
          Gap.s,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ml / target).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4F8FC0)),
            ),
          ),
          Gap.m,
          // Expanded, not natural width: three buttons plus the undo want
          // 403 px of the 332 that a 400 px phone leaves inside the card.
          Row(
            children: [
              for (final add in [250, 500, 750]) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(mealLogControllerProvider).water(date, add),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text('+$add'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Undo 250',
                onPressed: () =>
                    ref.read(mealLogControllerProvider).water(date, -250),
                icon: const Icon(Icons.undo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Supplements extends ConsumerWidget {
  const _Supplements({required this.date, required this.plan});

  final DateTime date;
  final FuelPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = ref.watch(supplementsTodayProvider(date)).asData?.value ?? {};
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Supplements'),
        for (final s in plan.supplements)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: taken.contains(s.id),
            onChanged: (v) => ref
                .read(mealLogControllerProvider)
                .supplement(date, s.id, taken: v ?? false),
            title: Text('${s.name} — ${s.dose}', style: t.titleMedium),
            subtitle: Text(
              '${s.timing}. ${s.note}',
              style: t.bodySmall?.copyWith(color: AppTheme.textDim),
            ),
          ),
      ],
    );
  }
}

class _GrocerySheet extends StatelessWidget {
  const _GrocerySheet({required this.lines, required this.plan});

  final List<GroceryLine> lines;
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
            Text('A week of this', style: t.titleLarge),
            Gap.xs,
            Text(
              'Five training days and two rest days of the meals currently '
              'chosen, rounded up to whole packets.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(l.food.name, style: t.bodyLarge),
                          ),
                          Text(
                            '${l.packs} x ${l.food.packG} g',
                            style: t.bodyMedium?.copyWith(
                              color: AppTheme.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Gap.l,
                  Text('Buying it halal', style: t.titleLarge),
                  Gap.s,
                  for (final g in plan.buyingGuide)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.title, style: t.titleMedium),
                          Gap.xs,
                          Text(
                            g.body,
                            style: t.bodyMedium?.copyWith(
                              color: AppTheme.textDim,
                            ),
                          ),
                        ],
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
