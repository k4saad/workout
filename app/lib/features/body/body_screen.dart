import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/body_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/metrics/bodyweight_trend.dart';
import '../common/widgets.dart';
import 'widgets/trend_chart.dart';

/// Bodyweight and food.
///
/// At 167 cm and 50 kg this screen matters more than any lift. The programme
/// is the easy half; if the scale does not move, nothing else here works.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final entriesAsync = ref.watch(weightEntriesProvider);
    final adviceAsync = ref.watch(nutritionAdviceProvider);
    final bundle = ref.watch(bundleProvider).asData?.value;
    final week = ref.watch(currentWeekProvider);
    final phase = bundle?.programme.nutritionForWeek(week);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body'),
        actions: [
          IconButton(
            tooltip: 'Progress photos',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.go('/body/progress'),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (entries) {
          const trend = BodyweightTrend();
          final points = trend.points(entries);
          final advice = adviceAsync.asData?.value;

          return ListView(
            padding: Gap.pagePadding,
            children: [
              _WeightCard(entries: entries, points: points),
              Gap.l,

              if (advice != null) _AdviceCard(advice: advice),

              if (phase != null) ...[
                Gap.l,
                _FoodCard(
                  kcal: phase.kcal,
                  proteinG: phase.proteinG,
                  carbsG: phase.carbsG,
                  fatG: phase.fatG,
                  note: phase.note,
                  kcalDelta: advice?.kcalDelta ?? 0,
                ),
              ],

              Gap.l,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eating this much at 50 kg', style: t.titleMedium),
                      Gap.s,
                      Text(
                        'Two liquid meals a day solves the whole problem. '
                        'Milk, oats, peanut butter, banana, whey — 700 to '
                        '800 kcal in three minutes, and it does not fill you '
                        'up the way the same calories as chicken and rice '
                        'would.\n\n'
                        'Eat before training as well as after. Do not open a '
                        'meal with salad or soup. Add olive oil to rice you '
                        'are eating anyway.',
                        style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                      ),
                    ],
                  ),
                ),
              ),
              Gap.xl,
            ],
          );
        },
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.entries, required this.points});

  final List<WeightEntry> entries;
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    const trend = BodyweightTrend();
    final avg = trend.currentAverage(entries);
    final change = trend.weeklyChange(entries);
    final bundle = ref.watch(bundleProvider).asData?.value;
    final target = bundle?.programme.athlete.targetWeightKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Bodyweight', style: t.titleLarge)),
                FilledButton(
                  onPressed: () => _enter(context, ref),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(110, 48),
                  ),
                  child: const Text('Weigh in'),
                ),
              ],
            ),
            Gap.m,
            if (avg == null)
              Text(
                'No weigh-ins yet. Morning, after the toilet, before food, '
                'most days — the rolling average is what decides '
                'anything, and it needs feeding.',
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: t.displaySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kg',
                    style: t.titleMedium?.copyWith(color: AppTheme.textDim),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '7-day average',
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ),
              Gap.s,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (change != null)
                    InfoChip(
                      label:
                          '${change >= 0 ? '+' : ''}'
                          '${change.toStringAsFixed(2)} kg/week',
                      emphasis: change > 0.15,
                    ),
                  if (target != null)
                    InfoChip(
                      label: '${(target - avg).toStringAsFixed(1)} kg to go',
                    ),
                  InfoChip(label: '${entries.length} weigh-ins'),
                ],
              ),
              Gap.m,
              SizedBox(
                height: 150,
                child: TrendChart(points: points, targetKg: target),
              ),
              Gap.s,
              Text(
                'The line is the rolling average. The dots are what the scale '
                'actually said — they bounce a kilo on water and gut '
                'content, which is exactly why nothing is decided on one.',
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final kg = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('This morning'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (kg == null) return;
    await ref
        .read(databaseProvider)
        .upsertBodyweight(ref.read(todayProvider), kg);
    ref.invalidate(weightEntriesProvider);
    ref.invalidate(nutritionAdviceProvider);
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final NutritionAdvice advice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (colour, icon) = switch (advice.verdict) {
      NutritionVerdict.onTrack => (AppTheme.good, Icons.check_circle_outline),
      NutritionVerdict.flat => (AppTheme.warn, Icons.trending_flat),
      NutritionVerdict.losing => (AppTheme.warn, Icons.trending_down),
      NutritionVerdict.tooFast => (AppTheme.warn, Icons.trending_up),
      NutritionVerdict.tooEarly => (AppTheme.textDim, Icons.hourglass_empty),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        border: Border.all(color: colour.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (advice.needsAction)
                  Text(
                    advice.kcalDelta > 0
                        ? 'Add ${advice.kcalDelta} kcal'
                        : 'Cut ${advice.kcalDelta.abs()} kcal',
                    style: t.titleMedium?.copyWith(color: colour),
                  ),
                Text(advice.message, style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends ConsumerWidget {
  const _FoodCard({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.note,
    required this.kcalDelta,
  });

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String? note;
  final int kcalDelta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayFoodProvider).asData?.value;
    final streak = ref.watch(foodStreakProvider).asData?.value ?? 0;
    final effective = kcal + kcalDelta;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Today’s target', style: t.titleLarge)),
                if (streak > 0)
                  InfoChip(
                    label: '$streak day streak',
                    icon: Icons.local_fire_department_outlined,
                    emphasis: true,
                  ),
              ],
            ),
            Gap.m,
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$effective',
                  style: t.displaySmall?.copyWith(
                    color: kcalDelta != 0 ? AppTheme.warn : AppTheme.text,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'kcal',
                  style: t.titleMedium?.copyWith(color: AppTheme.textDim),
                ),
                if (kcalDelta != 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(was $kcal)',
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ],
            ),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(label: '$proteinG g protein', emphasis: true),
                InfoChip(label: '$carbsG g carbs'),
                InfoChip(label: '$fatG g fat'),
              ],
            ),
            if (note != null) ...[
              Gap.s,
              Text(
                note!,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
            const Divider(height: 28),
            Text('Did you hit it?', style: t.titleMedium),
            Gap.s,
            Row(
              children: [
                Expanded(
                  child: _TickButton(
                    label: 'Hit it',
                    selected: today?.hitTarget == true,
                    colour: AppTheme.good,
                    onTap: () => _tick(ref, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TickButton(
                    label: 'Fell short',
                    selected: today != null && today.hitTarget == false,
                    colour: AppTheme.warn,
                    onTap: () => _tick(ref, false),
                  ),
                ),
              ],
            ),
            Gap.s,
            Text(
              'That is the whole food log. No database, no barcodes — '
              'one tap, and a streak you will not want to break.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tick(WidgetRef ref, bool hit) async {
    await ref
        .read(bodyServiceProvider)
        .logFood(ref.read(todayProvider), hitTarget: hit);
    ref.invalidate(todayFoodProvider);
    ref.invalidate(foodStreakProvider);
  }
}

class _TickButton extends StatelessWidget {
  const _TickButton({
    required this.label,
    required this.selected,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: colour),
              child: Text(label),
            )
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

/// A compact bodyweight line for the dashboard.
class BodyweightSparkline extends ConsumerWidget {
  const BodyweightSparkline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightEntriesProvider).asData?.value ?? [];
    if (entries.length < 2) return const SizedBox.shrink();
    const trend = BodyweightTrend();
    return SizedBox(
      height: 54,
      child: TrendChart(points: trend.points(entries), compact: true),
    );
  }
}

/// Formats a date the way the rest of the app does.
String formatDay(DateTime d) => DateFormat('d MMM').format(d);
