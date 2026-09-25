import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:intl/intl.dart' show DateFormat;

import '../../app/body_providers.dart';
import '../../app/progress_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../domain/metrics/bodyweight_trend.dart';
import '../../domain/models/programme.dart';
import '../common/widgets.dart';
import 'widgets/trend_chart.dart';

/// The scale and the tape.
///
/// At 167 cm and 50 kg this screen matters more than any lift. The programme
/// is the easy half; if the scale does not move, nothing else here works.
/// Food itself is logged on the Fuel tab.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightEntriesProvider);
    final advice = ref.watch(nutritionAdviceProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body'),
        actions: [
          IconButton(
            tooltip: 'Progress photos',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.push('/progress/photos'),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const SkeletonPage(cards: 2),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (entries) => ListView(
          padding: Gap.pagePadding,
          children: [
            _WeightCard(entries: entries),
            if (advice != null) ...[Gap.l, _AdviceCard(advice: advice)],
            Gap.l,
            const _TapeCard(),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    const trend = BodyweightTrend();
    final avg = trend.currentAverage(entries);
    final change = trend.weeklyChange(entries);
    final athlete = ref.watch(bundleProvider).asData?.value.programme.athlete;
    final target = athlete?.targetWeightKg;
    final today = ref.watch(todayProvider);
    final todays = entries.where((e) => _sameDay(e.date, today)).firstOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Bodyweight', style: t.titleLarge)),
              // An explicit minimum: the theme's filled button is
              // full-width, which in a Row is infinite.
              if (todays == null)
                FilledButton.icon(
                  onPressed: () => _weighIn(context, ref, athlete),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                  icon: const Icon(Icons.monitor_weight_outlined),
                  label: const Text('Weigh in'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _weighIn(context, ref, athlete),
                  icon: const Icon(Icons.check, color: AppTheme.good),
                  label: Text('${todays.kg.toStringAsFixed(1)} kg today'),
                ),
            ],
          ),
          Gap.m,
          if (avg == null)
            Text(
              'No weigh-ins yet. Morning, after the toilet, before food, '
              'most days — the rolling average is what decides anything, '
              'and it needs feeding.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(avg.toStringAsFixed(1), style: AppTheme.numeric(44)),
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
                        '${change >= 0 ? '▲ +' : '▼ −'}'
                        '${change.abs().toStringAsFixed(2)} kg/week',
                  ),
                if (target != null)
                  InfoChip(
                    label: '${(target - avg).toStringAsFixed(1)} kg to go',
                    icon: Icons.flag_outlined,
                  ),
                InfoChip(label: '${entries.length} weigh-ins'),
              ],
            ),
            Gap.m,
            SizedBox(
              height: 150,
              child: TrendChart(
                points: trend.points(entries),
                targetKg: target,
              ),
            ),
            Gap.s,
            Text(
              'The line is the rolling average. The dots are what the scale '
              'said — they bounce a kilo on water and food, which is why '
              'nothing is decided on one.',
              style: t.bodySmall?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _weighIn(
    BuildContext context,
    WidgetRef ref,
    Athlete? athlete,
  ) async {
    final today = ref.read(todayProvider);
    final todays = entries.where((e) => _sameDay(e.date, today)).firstOrNull;
    // Start from the last weigh-in: a morning is within a kilo of the one
    // before, a few taps away.
    final start =
        todays?.kg ?? entries.lastOrNull?.kg ?? athlete?.startWeightKg ?? 50.0;
    final kg = await showStepperSheet(
      context,
      title: todays == null ? 'This morning' : 'This morning, corrected',
      subtitle: 'After the toilet, before food.',
      initial: start,
      step: 0.1,
      bigStep: 1,
      min: 30,
      max: 150,
      decimals: 1,
      unit: 'kg',
      saveLabel: 'Save weigh-in',
    );
    if (kg == null) return;
    await ref.read(databaseProvider).upsertBodyweight(today, kg);
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final NutritionAdvice advice;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, word) = switch (advice.verdict) {
      NutritionVerdict.onTrack => (
        Tone.good,
        Icons.check_circle_outline,
        'On track',
      ),
      NutritionVerdict.flat => (Tone.warn, Icons.trending_flat, 'Flat'),
      NutritionVerdict.losing => (Tone.warn, Icons.trending_down, 'Losing'),
      NutritionVerdict.tooFast => (Tone.warn, Icons.trending_up, 'Too fast'),
      NutritionVerdict.tooEarly => (
        Tone.info,
        Icons.hourglass_empty,
        'Too early to tell',
      ),
    };
    return ToneBanner(
      tone: tone,
      icon: icon,
      title: advice.needsAction
          ? (advice.kcalDelta > 0
                ? 'Add ${advice.kcalDelta} kcal'
                : 'Cut ${advice.kcalDelta.abs()} kcal')
          : word,
      body: advice.message,
    );
  }
}

// --------------------------------------------------------------------- tape

String siteLabel(MeasurementSite s) => switch (s) {
  MeasurementSite.waist => 'Waist',
  MeasurementSite.chest => 'Chest',
  MeasurementSite.upperArm => 'Upper arm',
  MeasurementSite.thigh => 'Thigh',
  MeasurementSite.neck => 'Neck',
  MeasurementSite.hips => 'Hips',
  MeasurementSite.calf => 'Calf',
};

/// Where the stepper starts when a site has never been measured: close to
/// a slim young man's numbers, so the first reading is a few taps, not
/// forty. Only a starting point — nothing is saved until he saves.
double _firstGuess(MeasurementSite s) => switch (s) {
  MeasurementSite.waist => 68,
  MeasurementSite.chest => 82,
  MeasurementSite.upperArm => 25,
  MeasurementSite.thigh => 48,
  MeasurementSite.neck => 33,
  MeasurementSite.hips => 82,
  MeasurementSite.calf => 32,
};

/// The measurement sites, the programme's first, then the optional ones.
class _TapeCard extends ConsumerWidget {
  const _TapeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final programme = ref.watch(bundleProvider).asData?.value.programme;
    if (programme == null) return const SizedBox.shrink();
    final rules = programme.nutritionRules;
    final named = {for (final s in MeasurementSite.values) s.name: s};
    final core = [for (final n in programme.measurementSites) ?named[n]];
    final extra = [
      for (final s in MeasurementSite.values)
        if (!core.contains(s)) s,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tape measure', style: t.titleLarge),
          Gap.xs,
          Text(
            'Same time of day, same tension, relaxed and breathed out. Tap a '
            'site to measure it and see its history.',
            style: t.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
          Gap.s,
          for (final s in core)
            _SiteRow(site: s, waistLimitCm: rules.waistGrowthLimitCm),
          if (extra.isNotEmpty) ...[
            const Divider(height: 20),
            Text('OPTIONAL', style: AppTheme.overline),
            for (final s in extra)
              _SiteRow(site: s, waistLimitCm: rules.waistGrowthLimitCm),
          ],
          Gap.s,
          Text(
            'The waist may grow a little — you are gaining. More than '
            '${_cm(rules.waistGrowthLimitCm)} cm over the programme means '
            'the surplus is too big, and the advice above cuts '
            '${rules.kcalCutWhenWaistGrows} kcal.',
            style: t.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }
}

String _cm(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _SiteRow extends ConsumerWidget {
  const _SiteRow({required this.site, required this.waistLimitCm});

  final MeasurementSite site;
  final double waistLimitCm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final rows = ref.watch(measurementsProvider(site));
    final today = ref.watch(todayProvider);
    final latest = rows.lastOrNull;
    final delta = rows.length > 1 ? rows.last.cm - rows.first.cm : null;
    final over =
        site == MeasurementSite.waist && delta != null && delta > waistLimitCm;
    final measuredToday = latest != null && _sameDay(latest.measuredOn, today);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _measure(context, ref, rows),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(siteLabel(site), style: t.titleMedium),
                  Text(
                    latest == null
                        ? 'not measured'
                        : 'last ${DateFormat('d MMM').format(latest.measuredOn)}'
                              '${delta == null ? '' : ' · ${delta >= 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} since the first'}',
                    style: t.bodySmall?.copyWith(
                      color: over ? AppTheme.warn : AppTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (over) ...[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warn,
                size: 18,
                semanticLabel: 'over the waist limit',
              ),
              const SizedBox(width: 6),
            ],
            if (latest != null)
              Text(
                '${latest.cm.toStringAsFixed(1)} cm',
                style: AppTheme.numeric(20),
              ),
            const SizedBox(width: 6),
            Icon(
              measuredToday ? Icons.check_circle : Icons.add_circle_outline,
              color: measuredToday ? AppTheme.good : AppTheme.textDim,
              size: 22,
              semanticLabel: measuredToday ? 'measured today' : 'measure',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _measure(
    BuildContext context,
    WidgetRef ref,
    List<Measurement> rows,
  ) async {
    final t = Theme.of(context).textTheme;
    final today = ref.read(todayProvider);
    final history = rows.reversed.take(8).toList();
    final cm = await showStepperSheet(
      context,
      title: siteLabel(site),
      subtitle: rows.isEmpty
          ? 'The first reading. Later ones are compared with it.'
          : 'Measuring again today replaces today’s reading.',
      initial: rows.lastOrNull?.cm ?? _firstGuess(site),
      step: 0.1,
      bigStep: 1,
      min: 10,
      max: 200,
      decimals: 1,
      unit: 'cm',
      footer: history.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HISTORY', style: AppTheme.overline),
                Gap.xs,
                for (final (i, m) in history.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEE d MMM yyyy').format(m.measuredOn),
                            style: t.bodyMedium,
                          ),
                        ),
                        if (i + 1 < history.length)
                          Text(
                            _change(m.cm - history[i + 1].cm),
                            style: t.bodySmall?.copyWith(
                              color: AppTheme.textDim,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          m.cm.toStringAsFixed(1),
                          style: AppTheme.numeric(18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
    if (cm == null) return;
    await ref.read(databaseProvider).upsertMeasurement(today, site, cm);
  }

  static String _change(double d) => d.abs() < 0.05
      ? '='
      : '${d > 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(1)}';
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
