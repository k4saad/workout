import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';

/// The four default poses.
///
/// Four is the right number: enough to see change from every angle, few
/// enough that a shoot takes ninety seconds rather than becoming a chore you
/// skip.
const defaultPoses = [
  (
    id: 'front-relaxed',
    name: 'Front relaxed',
    guidance:
        'Arms at your sides, shoulders down, completely relaxed. No flexing '
        'and no sucking in — this is the one that tells the truth.',
  ),
  (
    id: 'front-flexed',
    name: 'Front flexed',
    guidance: 'Same stance, same spot, everything braced.',
  ),
  (
    id: 'side-right',
    name: 'Side (right)',
    guidance:
        'Right shoulder to the camera, arms hanging naturally. Same foot '
        'position every time.',
  ),
  (id: 'back', name: 'Back', guidance: 'Arms at your sides, lats relaxed.'),
];

/// Where a photo or clip lives, and what it weighs.
class MediaStats {
  const MediaStats({
    required this.photoCount,
    required this.clipCount,
    required this.bytes,
    required this.budgetBytes,
  });

  final int photoCount;
  final int clipCount;
  final int bytes;
  final int budgetBytes;

  double get fraction =>
      budgetBytes == 0 ? 0 : (bytes / budgetBytes).clamp(0, 1);

  bool get isOverBudget => bytes > budgetBytes;
  bool get isNearBudget => fraction > 0.8;

  String get readable => _human(bytes);
  String get budgetReadable => _human(budgetBytes);

  static String _human(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Owns progress photos and form clips on disk.
///
/// **Six hard requirements, not preferences** (docs/03-build-plan.md 5.5).
/// These are shirtless photos of one person, and the storage design is part
/// of the feature:
///
///  1. App-private storage ONLY. Never MediaStore, never /sdcard/Pictures,
///     never a path the gallery or Google Photos can see. Every write goes
///     through [_dir], which is rooted in the app documents directory.
///  2. Excluded from Android auto-backup — `allowBackup="false"` plus
///     `backup_rules.xml`, both in the manifest.
///  3. An optional biometric gate on the section.
///  4. No network code path touches these files. There is no upload method
///     on this class, and the app holds no INTERNET permission.
///  5. Delete means delete: the FILE goes, not just the row.
///  6. Thumbnails are app-private too.
class MediaRepository {
  MediaRepository({required this.db, Directory? documentsDir, Uuid? uuid})
    : _override = documentsDir,
      _uuid = uuid ?? const Uuid();

  final AppDatabase db;
  final Directory? _override;
  final Uuid _uuid;

  /// Default budget across photos and clips. Clips are the real consumer —
  /// 720p video is roughly 60 MB a minute.
  static const defaultBudgetBytes = 500 * 1024 * 1024;

  static const photosDir = 'photos';
  static const clipsDir = 'clips';
  static const thumbsDir = 'thumbs';

  Directory? _cached;

  Future<Directory> _root() async {
    if (_override != null) return _override;
    return _cached ??= await getApplicationDocumentsDirectory();
  }

  /// Resolves a stored relative path to a real file.
  ///
  /// Paths are stored RELATIVE so that restoring a backup onto a different
  /// device — where the sandbox path differs — still finds the file.
  Future<File> fileFor(String relativePath) async =>
      File(p.join((await _root()).path, relativePath));

  Future<Directory> _dir(String name) async {
    final d = Directory(p.join((await _root()).path, name));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  // ------------------------------------------------------------------ poses

  /// Seeds the four default poses if none exist. Safe on every launch.
  Future<void> ensurePosesSeeded() async {
    final existing = await db.select(db.photoPoses).get();
    if (existing.isNotEmpty) return;
    for (var i = 0; i < defaultPoses.length; i++) {
      final pose = defaultPoses[i];
      await db
          .into(db.photoPoses)
          .insert(
            PhotoPosesCompanion.insert(
              id: pose.id,
              name: pose.name,
              orderIndex: i,
              guidance: Value(pose.guidance),
            ),
          );
    }
  }

  // ----------------------------------------------------------------- shoots

  /// Starts a shoot on [date], resolving the bodyweight caption automatically.
  Future<PhotoShoot> startShoot(DateTime date, {int? weekNo}) async {
    final d = DateTime(date.year, date.month, date.day);
    final bw = await db.bodyweightNear(d);
    final id = _uuid.v4();
    await db
        .into(db.photoShoots)
        .insert(
          PhotoShootsCompanion.insert(
            id: id,
            shotOn: d,
            weekNo: Value(weekNo),
            bodyweightKg: Value(bw?.kg),
          ),
        );
    return (await (db.select(
      db.photoShoots,
    )..where((s) => s.id.equals(id))).getSingle());
  }

  /// Writes a captured photo into app-private storage.
  ///
  /// The path is `photos/<shootId>/<poseId>.jpg` under the app documents
  /// directory — invisible to the gallery, invisible to Google Photos, and
  /// excluded from Android's cloud backup.
  Future<ProgressPhoto> savePhoto({
    required String shootId,
    required String poseId,
    required Uint8List bytes,
    int width = 0,
    int height = 0,
    DateTime? takenAt,
  }) async {
    final dir = await _dir(p.join(photosDir, shootId));
    final file = File(p.join(dir.path, '$poseId.jpg'));
    await file.writeAsBytes(bytes, flush: true);

    final root = await _root();
    final rel = p.relative(file.path, from: root.path).replaceAll(r'\', '/');

    final id = _uuid.v4();
    await db
        .into(db.progressPhotos)
        .insert(
          ProgressPhotosCompanion.insert(
            id: id,
            shootId: shootId,
            poseId: poseId,
            relativePath: rel,
            width: Value(width),
            height: Value(height),
            bytes: Value(bytes.length),
            takenAt: takenAt ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );

    return (await (db.select(
      db.progressPhotos,
    )..where((x) => x.id.equals(id))).getSingle());
  }

  /// The photo the next shot of this pose should align against.
  ///
  /// This is the whole point of the ghost overlay: you line yourself up
  /// against your past self, so four months of photos prove something instead
  /// of being four months of slightly different angles.
  Future<File?> ghostFor(String poseId) async {
    final latest = await db.latestForPose(poseId);
    if (latest == null) return null;
    final f = await fileFor(latest.relativePath);
    return f.existsSync() ? f : null;
  }

  // --------------------------------------------------------------- deleting

  /// Deletes one photo — the FILE, not just the row.
  Future<void> deletePhoto(String photoId) async {
    final row = await (db.select(
      db.progressPhotos,
    )..where((p) => p.id.equals(photoId))).getSingleOrNull();
    if (row == null) return;

    final f = await fileFor(row.relativePath);
    if (f.existsSync()) await f.delete();

    final thumb = await _thumbFile(row.relativePath);
    if (thumb.existsSync()) await thumb.delete();

    await (db.delete(
      db.progressPhotos,
    )..where((p) => p.id.equals(photoId))).go();
  }

  /// Deletes a whole shoot: every photo file, the directory, and the rows.
  Future<void> deleteShoot(String shootId) async {
    final photos = await db.photosForShoot(shootId);
    for (final photo in photos) {
      final f = await fileFor(photo.relativePath);
      if (f.existsSync()) await f.delete();
      final thumb = await _thumbFile(photo.relativePath);
      if (thumb.existsSync()) await thumb.delete();
    }

    final dir = Directory(p.join((await _root()).path, photosDir, shootId));
    if (dir.existsSync()) await dir.delete(recursive: true);

    // Cascade removes the photo rows.
    await (db.delete(db.photoShoots)..where((s) => s.id.equals(shootId))).go();
  }

  Future<File> _thumbFile(String relativePath) async {
    final root = await _root();
    final name = relativePath.replaceAll('/', '_');
    return File(p.join(root.path, thumbsDir, name));
  }

  // ------------------------------------------------------------------ clips

  Future<FormClip> saveClip({
    required String exerciseId,
    required File source,
    int durationSec = 0,
    String? note,
  }) async {
    final dir = await _dir(p.join(clipsDir, exerciseId));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dest = File(p.join(dir.path, '$stamp.mp4'));
    await source.copy(dest.path);

    final root = await _root();
    final rel = p.relative(dest.path, from: root.path).replaceAll(r'\', '/');
    final id = _uuid.v4();

    await db
        .into(db.formClips)
        .insert(
          FormClipsCompanion.insert(
            id: id,
            exerciseId: exerciseId,
            relativePath: rel,
            recordedAt: DateTime.now(),
            durationSec: Value(durationSec),
            bytes: Value(await dest.length()),
            note: Value(note),
          ),
        );

    return (await (db.select(
      db.formClips,
    )..where((c) => c.id.equals(id))).getSingle());
  }

  Future<void> deleteClip(String clipId) async {
    final row = await (db.select(
      db.formClips,
    )..where((c) => c.id.equals(clipId))).getSingleOrNull();
    if (row == null) return;
    final f = await fileFor(row.relativePath);
    if (f.existsSync()) await f.delete();
    await (db.delete(db.formClips)..where((c) => c.id.equals(clipId))).go();
  }

  // ---------------------------------------------------------------- storage

  Future<MediaStats> stats({int budgetBytes = defaultBudgetBytes}) async {
    final photos = await db.select(db.progressPhotos).get();
    final clips = await db.select(db.formClips).get();
    return MediaStats(
      photoCount: photos.length,
      clipCount: clips.length,
      bytes:
          photos.fold<int>(0, (a, p) => a + p.bytes) +
          clips.fold<int>(0, (a, c) => a + c.bytes),
      budgetBytes: budgetBytes,
    );
  }

  /// Rows whose file has gone missing — after a partial restore, or a manual
  /// tidy-up. Surfaced rather than silently rendering broken thumbnails.
  Future<List<ProgressPhoto>> orphanedPhotos() async {
    final rows = await db.select(db.progressPhotos).get();
    final out = <ProgressPhoto>[];
    for (final r in rows) {
      final f = await fileFor(r.relativePath);
      if (!f.existsSync()) out.add(r);
    }
    return out;
  }

  /// Every directory this repository owns, for the backup to sweep up.
  Future<List<Directory>> mediaDirectories() async {
    final root = await _root();
    return [
      Directory(p.join(root.path, photosDir)),
      Directory(p.join(root.path, clipsDir)),
      Directory(p.join(root.path, thumbsDir)),
    ];
  }
}
