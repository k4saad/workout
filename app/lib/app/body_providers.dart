import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_service.dart';
import '../data/db/database.dart';
import '../domain/metrics/bodyweight_trend.dart';
import 'providers.dart';
import 'session_providers.dart';

final bodyServiceProvider = Provider<BodyService>(
  (ref) => BodyService(ref.watch(databaseProvider)),
);

final weightEntriesProvider = FutureProvider<List<WeightEntry>>(
  (ref) => ref.watch(bodyServiceProvider).weightHistory(),
);

/// What the flat rule says to do about the food.
///
/// Reads the programme's own numbers — `flatWeeksBeforeBump`,
/// `kcalBumpWhenFlat`, `waistGrowthLimitCm` — rather than hardcoding any of
/// them, so changing the JSON changes the advice.
final nutritionAdviceProvider = FutureProvider<NutritionAdvice>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  final service = ref.watch(bodyServiceProvider);
  final entries = await service.weightHistory();
  final waist = await service.waistChangeCm();
  return const BodyweightTrend().advise(
    entries,
    bundle.programme.nutritionRules,
    waistChangeCm: waist,
  );
});

final todayFoodProvider = FutureProvider<FoodLog?>(
  (ref) => ref.watch(bodyServiceProvider).foodFor(ref.watch(todayProvider)),
);

final foodStreakProvider = FutureProvider<int>(
  (ref) => ref.watch(bodyServiceProvider).foodStreak(ref.watch(todayProvider)),
);

final cardioLogsProvider = FutureProvider<List<CardioLog>>(
  (ref) => ref.watch(bodyServiceProvider).recentCardio(),
);
