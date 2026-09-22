import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../data/media_repository.dart';
import 'session_providers.dart';

final mediaRepositoryProvider = FutureProvider<MediaRepository>((ref) async {
  final repo = MediaRepository(db: ref.watch(databaseProvider));
  await repo.ensurePosesSeeded();
  return repo;
});

/// Every shoot, newest first. A SHOOT is the unit you compare, not a photo.
final shootsProvider = FutureProvider<List<PhotoShoot>>((ref) async {
  await ref.watch(mediaRepositoryProvider.future);
  return ref.watch(databaseProvider).shoots();
});

final posesProvider = FutureProvider<List<PhotoPose>>((ref) async {
  await ref.watch(mediaRepositoryProvider.future);
  return ref.watch(databaseProvider).enabledPoses();
});

final shootPhotosProvider = FutureProvider.family<List<ProgressPhoto>, String>(
  (ref, shootId) => ref.watch(databaseProvider).photosForShoot(shootId),
);

/// Every photo of one pose, oldest first. This is the flipbook.
final posePhotosProvider = FutureProvider.family<List<ProgressPhoto>, String>(
  (ref, poseId) => ref.watch(databaseProvider).photosForPose(poseId),
);

final measurementsProvider =
    FutureProvider.family<List<Measurement>, MeasurementSite>(
      (ref, site) => ref.watch(databaseProvider).measurementsFor(site),
    );

final mediaStatsProvider = FutureProvider<MediaStats>((ref) async {
  final repo = await ref.watch(mediaRepositoryProvider.future);
  return repo.stats();
});
