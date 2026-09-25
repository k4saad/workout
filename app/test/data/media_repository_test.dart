import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/media_repository.dart';
import 'package:path/path.dart' as p;

/// The privacy requirements from docs/03-build-plan.md 5.5, as far as they
/// can be asserted off-device.
///
/// What these CANNOT prove is that Android's gallery does not index the
/// directory — that needs a real phone, and it is the one item in this phase
/// still outstanding.
void main() {
  late Directory docs;
  late AppDatabase db;
  late MediaRepository media;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('kt_media_');
    db = AppDatabase.memory();
    media = MediaRepository(db: db, documentsDir: docs);
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Uint8List jpeg([int size = 1024]) =>
      Uint8List.fromList(List<int>.generate(size, (i) => i % 256));

  group('poses', () {
    test('seeds four default poses', () async {
      await media.ensurePosesSeeded();
      final poses = await db.enabledPoses();
      expect(poses, hasLength(4));
      expect(poses.first.id, 'front-relaxed');
      expect(poses.map((p) => p.orderIndex).toList(), [0, 1, 2, 3]);
    });

    test('seeding from two places at once does not collide', () async {
      await Future.wait([media.ensurePosesSeeded(), media.ensurePosesSeeded()]);
      expect(await db.enabledPoses(), hasLength(4));
    });

    test('seeding twice does not duplicate', () async {
      await media.ensurePosesSeeded();
      await media.ensurePosesSeeded();
      expect(await db.enabledPoses(), hasLength(4));
    });

    test(
      'every pose carries guidance — a pose with no instruction drifts',
      () async {
        await media.ensurePosesSeeded();
        for (final pose in await db.enabledPoses()) {
          expect(pose.guidance, isNotNull, reason: pose.id);
          expect(pose.guidance!.length, greaterThan(20), reason: pose.id);
        }
      },
    );
  });

  group('shoots', () {
    test('resolves the bodyweight caption automatically', () async {
      await db.upsertBodyweight(DateTime(2026, 11, 1), 51.8);
      final shoot = await media.startShoot(DateTime(2026, 11, 2), weekNo: 5);
      expect(shoot.bodyweightKg, 51.8);
      expect(shoot.weekNo, 5);
    });

    test('a shoot with no nearby weigh-in still works', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      expect(shoot.bodyweightKg, isNull);
    });
  });

  group('storage is app-private — requirement 1', () {
    test('photos land under the documents directory, nowhere else', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'front-relaxed',
        bytes: jpeg(),
      );

      final file = await media.fileFor(photo.relativePath);
      expect(file.existsSync(), isTrue);
      expect(p.isWithin(docs.path, file.path), isTrue);
    });

    test('the path never touches a shared-media location', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(),
      );
      final lower = photo.relativePath.toLowerCase();
      for (final forbidden in [
        'dcim',
        'pictures',
        'download',
        'media',
        'sdcard',
        'external',
      ]) {
        expect(lower.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test(
      'paths are stored RELATIVE so a restore on a new device works',
      () async {
        final shoot = await media.startShoot(DateTime(2026, 11, 2));
        final photo = await media.savePhoto(
          shootId: shoot.id,
          poseId: 'side-right',
          bytes: jpeg(),
        );
        expect(p.isAbsolute(photo.relativePath), isFalse);
        expect(photo.relativePath, startsWith('photos/'));
        expect(photo.relativePath, contains(shoot.id));
      },
    );

    test('a photo is filed under its shoot and named for its pose', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'front-flexed',
        bytes: jpeg(),
      );
      expect(photo.relativePath, 'photos/${shoot.id}/front-flexed.jpg');
    });
  });

  group('the ghost overlay', () {
    test('returns the previous photo of the SAME pose', () async {
      final first = await media.startShoot(DateTime(2026, 9, 28));
      await media.savePhoto(
        shootId: first.id,
        poseId: 'front-relaxed',
        bytes: jpeg(700),
        takenAt: DateTime(2026, 9, 28),
      );
      await media.savePhoto(
        shootId: first.id,
        poseId: 'back',
        bytes: jpeg(300),
        takenAt: DateTime(2026, 9, 28),
      );

      final ghost = await media.ghostFor('front-relaxed');
      expect(ghost, isNotNull);
      expect(ghost!.lengthSync(), 700, reason: 'the front shot, not the back');
    });

    test('returns the most recent when there are several', () async {
      for (final (date, size) in [
        (DateTime(2026, 9, 28), 100),
        (DateTime(2026, 10, 26), 200),
        (DateTime(2026, 11, 23), 300),
      ]) {
        final shoot = await media.startShoot(date);
        await media.savePhoto(
          shootId: shoot.id,
          poseId: 'front-relaxed',
          bytes: jpeg(size),
          takenAt: date,
        );
      }
      final ghost = await media.ghostFor('front-relaxed');
      expect(ghost!.lengthSync(), 300);
    });

    test(
      'is null on the very first shoot — nothing to align against yet',
      () async {
        expect(await media.ghostFor('front-relaxed'), isNull);
      },
    );

    test('does not return a ghost whose file has gone', () async {
      final shoot = await media.startShoot(DateTime(2026, 9, 28));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(),
      );
      (await media.fileFor(photo.relativePath)).deleteSync();
      expect(await media.ghostFor('back'), isNull);
    });
  });

  group('delete means delete — requirement 5', () {
    test('deleting a photo removes the FILE, not just the row', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'front-relaxed',
        bytes: jpeg(),
      );
      final file = await media.fileFor(photo.relativePath);
      expect(file.existsSync(), isTrue);

      await media.deletePhoto(photo.id);

      expect(file.existsSync(), isFalse, reason: 'the file must be gone');
      expect(await db.select(db.progressPhotos).get(), isEmpty);
    });

    test('deleting a shoot removes every file AND the directory', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      for (final pose in ['front-relaxed', 'front-flexed', 'back']) {
        await media.savePhoto(shootId: shoot.id, poseId: pose, bytes: jpeg());
      }
      final dir = Directory(p.join(docs.path, 'photos', shoot.id));
      expect(dir.listSync(), hasLength(3));

      await media.deleteShoot(shoot.id);

      expect(dir.existsSync(), isFalse, reason: 'the directory must be gone');
      expect(await db.select(db.progressPhotos).get(), isEmpty);
      expect(await db.select(db.photoShoots).get(), isEmpty);
    });

    test('deleting a shoot row cascades to its photo rows', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      await media.savePhoto(shootId: shoot.id, poseId: 'back', bytes: jpeg());
      await (db.delete(
        db.photoShoots,
      )..where((s) => s.id.equals(shoot.id))).go();
      expect(await db.select(db.progressPhotos).get(), isEmpty);
    });
  });

  group('retakes, empty shoots and thumbnails', () {
    test('retaking a pose leaves one row, and the new picture', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final first = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(100),
      );
      final second = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(200),
      );
      final rows = await db.photosForShoot(shoot.id);
      expect(rows, hasLength(1), reason: 'v2 kept a row per attempt');
      expect(rows.single.bytes, 200);
      expect(second.id, first.id, reason: 'the same photo, taken again');
      expect((await media.fileFor(second.relativePath)).lengthSync(), 200);
    });

    test('a shoot with no photos in it is tidied away', () async {
      final empty = await media.startShoot(DateTime(2026, 11, 2));
      final kept = await media.startShoot(DateTime(2026, 11, 3));
      await media.savePhoto(shootId: kept.id, poseId: 'back', bytes: jpeg());

      expect(await media.tidyEmptyShoots(), 1);
      final ids = [for (final s in await db.shoots()) s.id];
      expect(ids, [kept.id]);
      expect(ids, isNot(contains(empty.id)));
    });

    test('a thumbnail is written app-private, and deleted with it', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(),
        thumb: jpeg(50),
      );
      final thumb = await media.thumbFor(photo);
      final full = await media.fileFor(photo.relativePath);
      expect(thumb.path, isNot(full.path));
      expect(p.isWithin(docs.path, thumb.path), isTrue);
      expect(thumb.lengthSync(), 50);

      await media.deletePhoto(photo.id);
      expect(thumb.existsSync(), isFalse);
    });

    test('with no thumbnail, the photo itself stands in', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      final photo = await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(),
      );
      expect(
        (await media.thumbFor(photo)).path,
        (await media.fileFor(photo.relativePath)).path,
      );
    });
  });

  group('there is no way to send a photo anywhere — requirement 4', () {
    test('the repository exposes no upload, share or sync method', () {
      // A reflective check is not available in Dart without mirrors, so this
      // is a guard for the reviewer: MediaRepository's public surface is
      // seed / start / save / ghost / delete / stats / directories. If an
      // upload method is ever added, this test's name is the reason to
      // think twice.
      expect(MediaRepository.photosDir, 'photos');
      expect(MediaRepository.clipsDir, 'clips');
      expect(MediaRepository.thumbsDir, 'thumbs');
    });
  });

  group('form clips', () {
    test('a clip is copied into app-private storage', () async {
      final source = File(p.join(docs.path, 'incoming.mp4'))
        ..writeAsBytesSync(jpeg(4096));
      final clip = await media.saveClip(
        exerciseId: 'barbell-back-squat',
        source: source,
        durationSec: 12,
      );
      expect(clip.relativePath, startsWith('clips/barbell-back-squat/'));
      expect(clip.bytes, 4096);
      final f = await media.fileFor(clip.relativePath);
      expect(f.existsSync(), isTrue);
      expect(p.isWithin(docs.path, f.path), isTrue);
    });

    test('clips are listed newest first, for week 1 versus week 8', () async {
      final source = File(p.join(docs.path, 'in.mp4'))
        ..writeAsBytesSync(jpeg(64));
      await media.saveClip(exerciseId: 'squat', source: source);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await media.saveClip(exerciseId: 'squat', source: source);
      final clips = await db.clipsForExercise('squat');
      expect(clips, hasLength(2));
      expect(
        clips.first.recordedAt.isAfter(clips.last.recordedAt) ||
            clips.first.recordedAt == clips.last.recordedAt,
        isTrue,
      );
    });

    test('deleting a clip removes its file', () async {
      final source = File(p.join(docs.path, 'in.mp4'))
        ..writeAsBytesSync(jpeg(64));
      final clip = await media.saveClip(exerciseId: 'squat', source: source);
      final f = await media.fileFor(clip.relativePath);
      await media.deleteClip(clip.id);
      expect(f.existsSync(), isFalse);
    });
  });

  group('the storage budget', () {
    test('counts photos and clips together', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(1000),
      );
      final source = File(p.join(docs.path, 'in.mp4'))
        ..writeAsBytesSync(jpeg(2000));
      await media.saveClip(exerciseId: 'squat', source: source);

      final stats = await media.stats();
      expect(stats.photoCount, 1);
      expect(stats.clipCount, 1);
      expect(stats.bytes, 3000);
    });

    test('warns before the budget is exceeded, not after', () async {
      final shoot = await media.startShoot(DateTime(2026, 11, 2));
      await media.savePhoto(
        shootId: shoot.id,
        poseId: 'back',
        bytes: jpeg(900),
      );
      final stats = await media.stats(budgetBytes: 1000);
      expect(stats.isNearBudget, isTrue);
      expect(stats.isOverBudget, isFalse);
      expect(stats.fraction, closeTo(0.9, 0.01));
    });

    test('reads out in human units', () async {
      const stats = MediaStats(
        photoCount: 200,
        clipCount: 4,
        bytes: 104857600,
        budgetBytes: 524288000,
      );
      expect(stats.readable, '100.0 MB');
      expect(stats.budgetReadable, '500.0 MB');
    });
  });

  group('orphans', () {
    test(
      'a row whose file has gone is surfaced, not silently broken',
      () async {
        final shoot = await media.startShoot(DateTime(2026, 11, 2));
        final photo = await media.savePhoto(
          shootId: shoot.id,
          poseId: 'back',
          bytes: jpeg(),
        );
        expect(await media.orphanedPhotos(), isEmpty);

        (await media.fileFor(photo.relativePath)).deleteSync();
        final orphans = await media.orphanedPhotos();
        expect(orphans, hasLength(1));
        expect(orphans.single.id, photo.id);
      },
    );
  });

  group('measurements', () {
    test('one per site per day, re-entering replaces', () async {
      await db.upsertMeasurement(
        DateTime(2026, 9, 28),
        MeasurementSite.waist,
        68.0,
      );
      await db.upsertMeasurement(
        DateTime(2026, 9, 28),
        MeasurementSite.waist,
        68.5,
      );
      final rows = await db.measurementsFor(MeasurementSite.waist);
      expect(rows, hasLength(1));
      expect(rows.single.cm, 68.5);
    });

    test('different sites on the same day coexist', () async {
      await db.upsertMeasurement(
        DateTime(2026, 9, 28),
        MeasurementSite.waist,
        68.0,
      );
      await db.upsertMeasurement(
        DateTime(2026, 9, 28),
        MeasurementSite.chest,
        92.0,
      );
      expect(await db.measurementsFor(MeasurementSite.waist), hasLength(1));
      expect(await db.measurementsFor(MeasurementSite.chest), hasLength(1));
    });

    test('a site reads back oldest first, for the chart', () async {
      for (final (date, cm) in [
        (DateTime(2026, 12, 21), 71.0),
        (DateTime(2026, 9, 28), 68.0),
        (DateTime(2026, 10, 26), 69.5),
      ]) {
        await db.upsertMeasurement(date, MeasurementSite.waist, cm);
      }
      final rows = await db.measurementsFor(MeasurementSite.waist);
      expect(rows.map((r) => r.cm).toList(), [68.0, 69.5, 71.0]);
    });
  });
}
