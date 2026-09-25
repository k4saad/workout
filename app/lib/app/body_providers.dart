import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_service.dart';
import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../domain/metrics/bodyweight_trend.dart';
import 'progress_providers.dart';
import 'providers.dart';
import 'session_providers.dart';

final bodyServiceProvider = Provider<BodyService>(
  (ref) => BodyService(ref.watch(databaseProvider)),
);

/// Every weigh-in, oldest first. Live: a weigh-in saved anywhere redraws
/// the chart, with no invalidation to forget.
final weightEntriesProvider = FutureProvider<List<WeightEntry>>((ref) async {
  final rows = await ref.watch(bodyweightRowsProvider.future);
  return [for (final r in rows) WeightEntry(date: r.measuredOn, kg: r.kg)];
});

/// What the flat rule says to do about the food.
///
/// Reads the programme's own numbers — `flatWeeksBeforeBump`,
/// `kcalBumpWhenFlat`, `waistGrowthLimitCm` — rather than hardcoding any of
/// them, so changing the JSON changes the advice.
final nutritionAdviceProvider = FutureProvider<NutritionAdvice>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  final entries = await ref.watch(weightEntriesProvider.future);
  final waists = [
    for (final m in await ref.watch(allMeasurementsProvider.future))
      if (m.site == MeasurementSite.waist) m.cm,
  ];
  final waist = waists.length < 2 ? null : waists.last - waists.first;
  return const BodyweightTrend().advise(
    entries,
    bundle.programme.nutritionRules,
    waistChangeCm: waist,
  );
});

final cardioLogsProvider = FutureProvider<List<CardioLog>>(
  (ref) => ref.watch(bodyServiceProvider).recentCardio(),
);
