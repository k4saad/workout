import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_camera.dart';
import '../data/db/database.dart';
import '../data/db/tables.dart';
import '../data/media_repository.dart';
import '../data/photo_processing.dart';
import '../data/preferences_service.dart';
import '../domain/calendar/adherence.dart';
import '../domain/calendar/programme_calendar.dart';
import '../domain/progress/checkpoint_review.dart';
import 'calendar_providers.dart';
import 'providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

final mediaRepositoryProvider = FutureProvider<MediaRepository>((ref) async {
  final repo = MediaRepository(db: ref.watch(databaseProvider));
  await repo.ensurePosesSeeded();
  // A shoot is created with its first kept photo, so an empty one is a
  // leftover — from a crash, or from v2, which made one on opening the
  // camera.
  await repo.tidyEmptyShoots();
  return repo;
});

/// Every shoot, newest first, live: keep a photo and the timeline has it.
final shootsProvider = StreamProvider<List<PhotoShoot>>((ref) async* {
  await ref.watch(mediaRepositoryProvider.future);
  final db = ref.watch(databaseProvider);
  yield* (db.select(
    db.photoShoots,
  )..orderBy([(s) => OrderingTerm.desc(s.shotOn)])).watch();
});

/// Every photo, oldest first, live.
final allPhotosProvider = StreamProvider<List<ProgressPhoto>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.progressPhotos,
  )..orderBy([(p) => OrderingTerm.asc(p.takenAt)])).watch();
});

/// Where the photos live. Resolved once, so image widgets can build a path
/// without waiting.
final mediaRootProvider = FutureProvider<Directory>(
  (ref) async => (await ref.watch(mediaRepositoryProvider.future)).root(),
);

final posesProvider = FutureProvider<List<PhotoPose>>((ref) async {
  await ref.watch(mediaRepositoryProvider.future);
  return ref.watch(databaseProvider).enabledPoses();
});

final shootPhotosProvider = Provider.family<List<ProgressPhoto>, String>(
  (ref, shootId) => [
    for (final p in ref.watch(allPhotosProvider).asData?.value ?? const [])
      if (p.shootId == shootId) p,
  ],
);

/// Every photo of one pose, oldest first. The time-lapse.
final posePhotosProvider = Provider.family<List<ProgressPhoto>, String>(
  (ref, poseId) => [
    for (final p in ref.watch(allPhotosProvider).asData?.value ?? const [])
      if (p.poseId == poseId) p,
  ],
);

/// Every tape-measure reading, oldest first, live.
final allMeasurementsProvider = StreamProvider<List<Measurement>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.measurements,
  )..orderBy([(m) => OrderingTerm.asc(m.measuredOn)])).watch();
});

final measurementsProvider =
    Provider.family<List<Measurement>, MeasurementSite>(
      (ref, site) => [
        for (final m
            in ref.watch(allMeasurementsProvider).asData?.value ?? const [])
          if (m.site == site) m,
      ],
    );

/// Every weigh-in, oldest first, live.
final bodyweightRowsProvider = StreamProvider<List<Bodyweight>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.bodyweights,
  )..orderBy([(b) => OrderingTerm.asc(b.measuredOn)])).watch();
});

final mediaStatsProvider = FutureProvider<MediaStats>((ref) async {
  ref.watch(allPhotosProvider);
  final repo = await ref.watch(mediaRepositoryProvider.future);
  return repo.stats();
});

// ------------------------------------------------------------------ capture

typedef PhotoProcessor = Future<ProcessedPhoto> Function(Uint8List raw);

/// Decode, turn upright, resize, strip and thumbnail — in a background
/// isolate, so the screen does not freeze on a 12-megapixel frame.
final photoProcessorProvider = Provider<PhotoProcessor>(
  (ref) =>
      (raw) => Isolate.run(() => PhotoProcessing.process(raw)),
);

/// Makes the camera. A factory, not an instance: the capture screen owns
/// the camera it opens, and closes it when it goes.
final captureCameraProvider = Provider<CaptureCamera Function()>(
  (ref) => PluginCaptureCamera.new,
);

/// Makes the self-timer's pips and buzz, owned the same way.
final captureCueProvider = Provider<CaptureCue Function()>(
  (ref) => AudioCaptureCue.new,
);

// -------------------------------------------------------------- checkpoints

/// A checkpoint's lines, with the ones the app can check already checked.
///
/// Null for a week with no checkpoint. Live: keep the last photo of a shoot
/// and the line ticks.
final checkpointReviewProvider = FutureProvider.autoDispose
    .family<List<CheckItem>?, int>((ref, week) async {
      final bundle = await ref.watch(bundleProvider.future);
      final checkpoint = bundle.programme.checkpointForWeek(week);
      if (checkpoint == null) return null;

      final shoots = await ref.watch(shootsProvider.future);
      final photos = await ref.watch(allPhotosProvider.future);
      final measured = await ref.watch(allMeasurementsProvider.future);
      final weighs = await ref.watch(bodyweightRowsProvider.future);
      final records = await ref.watch(allRecordsProvider.future);
      final poses = await ref.watch(posesProvider.future);
      final today = ref.watch(todayProvider);
      Preferences prefs;
      try {
        prefs = await ref.watch(preferencesProvider.future);
      } on Object {
        prefs = const Preferences();
      }

      final calendar = bundle.calendar;
      final sessions = SessionTally.of(
        CalendarMerge(calendar).entriesFor(
          calendar.startOfWeek(1),
          ProgrammeCalendar.addDays(calendar.startOfWeek(week), 6),
          records,
        ),
        today,
      );
      final posesByShoot = <String, Set<String>>{};
      for (final p in photos) {
        (posesByShoot[p.shootId] ??= {}).add(p.poseId);
      }

      return CheckpointReview.review(
        checkpoint: checkpoint,
        calendar: calendar,
        evidence: CheckpointEvidence(
          shoots: [
            for (final s in shoots)
              (on: s.shotOn, poses: posesByShoot[s.id] ?? const {}),
          ],
          measurements: [
            for (final m in measured) (on: m.measuredOn, site: m.site.name),
          ],
          weighIns: [for (final w in weighs) w.measuredOn],
          sessions: sessions,
        ),
        poses: {for (final p in poses) p.id},
        sites: bundle.programme.measurementSites,
        ticked: prefs.ticksFor(week),
      );
    });
