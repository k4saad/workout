import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_service.dart';
import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../domain/metrics/bodyweight_trend.dart';
import 'fuel_providers.dart';
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
///
/// Also what the v3 spec asked of it and v3 never wired: a plan not being
/// eaten is answered with "eat the plan", not more food; a change once made
/// gets its weeks on the scale; and the waist only argues for a cut with a
/// measurement taken since the last change.
final nutritionAdviceProvider = FutureProvider<NutritionAdvice>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  final entries = await ref.watch(weightEntriesProvider.future);
  final lastChange = await ref.watch(lastCalorieChangeProvider.future);
  final adherence = await ref.watch(fuelAdherenceProvider.future);
  final waists = [
    for (final m in await ref.watch(allMeasurementsProvider.future))
      if (m.site == MeasurementSite.waist) m,
  ];
  final freshWaist =
      waists.length >= 2 &&
      (lastChange == null || waists.last.measuredOn.isAfter(lastChange));
  return const BodyweightTrend().advise(
    entries,
    bundle.programme.nutritionRules,
    waistChangeCm: freshWaist ? waists.last.cm - waists.first.cm : null,
    adherence: adherence.planned == 0 ? null : adherence.rate,
    lastAdjustedOn: lastChange,
  );
});

final cardioLogsProvider = FutureProvider<List<CardioLog>>(
  (ref) => ref.watch(bodyServiceProvider).recentCardio(),
);
