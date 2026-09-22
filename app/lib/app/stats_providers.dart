import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/stats_service.dart';
import '../domain/metrics/plate_gap.dart';
import '../domain/metrics/session_stats.dart';
import '../domain/metrics/volume_metrics.dart';
import 'providers.dart';
import 'session_providers.dart';

final statsServiceProvider = FutureProvider<StatsService>((ref) async {
  final bundle = await ref.watch(bundleProvider.future);
  return StatsService(
    db: ref.watch(databaseProvider),
    library: bundle.library,
    inventory: bundle.inventory,
  );
});

final liftSummariesProvider = FutureProvider<List<LiftSummary>>((ref) async {
  final stats = await ref.watch(statsServiceProvider.future);
  return stats.allSummaries();
});

final liftSummaryProvider = FutureProvider.family<LiftSummary, String>((
  ref,
  exerciseId,
) async {
  final stats = await ref.watch(statsServiceProvider.future);
  return stats.summaryFor(exerciseId);
});

final weeklyVolumeProvider = FutureProvider.family<List<MuscleVolume>, int>((
  ref,
  weekNo,
) async {
  final stats = await ref.watch(statsServiceProvider.future);
  return stats.weeklyMuscleVolume(weekNo);
});

final plateGapProvider = FutureProvider<PlateGapReport>((ref) async {
  final stats = await ref.watch(statsServiceProvider.future);
  final bundle = await ref.watch(bundleProvider.future);
  return stats.plateGaps(bundle.programme);
});

final sessionStatsProvider = FutureProvider<SessionStats>((ref) async {
  final stats = await ref.watch(statsServiceProvider.future);
  final bundle = await ref.watch(bundleProvider.future);
  return stats.sessionDurations(bundle.programme);
});

final nigglesProvider = FutureProvider<List<Niggle>>((ref) async {
  final stats = await ref.watch(statsServiceProvider.future);
  return stats.niggles();
});

/// Working sets logged per exercise in one programme week.
final weekSetsProvider = FutureProvider.family<Map<String, int>, int>((
  ref,
  weekNo,
) async {
  final stats = await ref.watch(statsServiceProvider.future);
  return stats.setsInWeek(weekNo);
});
