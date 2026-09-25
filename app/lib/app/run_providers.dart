import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/run_location.dart';
import '../data/run_repository.dart';
import '../data/run_tracker.dart';
import '../domain/run/run.dart';
import 'session_providers.dart';

/// GPS runs in the app-private database.
final runRepositoryProvider = Provider<RunRepository>(
  (ref) => RunRepository(ref.watch(databaseProvider)),
);

/// Where fixes come from. Tests override it with a scripted source.
final locationSourceProvider = Provider<LocationSource>(
  (ref) => const GeolocatorSource(),
);

/// Whether the map draws OpenStreetMap tiles. Widget tests turn it off: they
/// have no network, and the trail is drawn either way.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// Every finished run, newest first.
final finishedRunsProvider = StreamProvider<List<Run>>(
  (ref) => ref.watch(runRepositoryProvider).watchFinished(),
);

final runProvider = FutureProvider.family<Run?, int>(
  (ref, id) => ref.watch(runRepositoryProvider).byId(id),
);

/// A run's numbers and trail, replayed from its stored points.
final runTrackProvider = FutureProvider.family<RunTrack, int>(
  (ref, id) => ref.watch(runRepositoryProvider).track(id),
);

/// His own easy pace for this kind of run (null: free runs).
final paceBandProvider = FutureProvider.family<PaceBand?, String?>(
  (ref, exerciseId) async => PaceBand.fromHistory(
    await ref.watch(runRepositoryProvider).recentPaces(exerciseId),
  ),
);

/// A run left open when the app was closed or killed.
final openRunProvider = FutureProvider<Run?>((ref) async {
  final repo = ref.watch(runRepositoryProvider);
  // A Start that never got a fix, left behind when the app was killed, is
  // not a run to offer back.
  await repo.tidyEmptyRuns(olderThan: const Duration(minutes: 10));
  return repo.active();
});

/// Finished runs on each day of [range], for the calendar.
final runsBetweenProvider =
    FutureProvider.family<List<Run>, ({DateTime from, DateTime to})>((
      ref,
      range,
    ) {
      ref.watch(finishedRunsProvider);
      return ref
          .watch(runRepositoryProvider)
          .finishedBetween(range.from, range.to);
    });
