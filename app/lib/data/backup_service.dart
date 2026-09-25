import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db/database.dart';

/// What a backup contains, for the confirmation screen before a restore.
class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.sessionCount,
    required this.setCount,
    required this.bodyweightCount,
    required this.photoCount,
    required this.programmeRevision,
  });

  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final int sessionCount;
  final int setCount;
  final int bodyweightCount;
  final int photoCount;
  final int programmeRevision;

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'sessionCount': sessionCount,
    'setCount': setCount,
    'bodyweightCount': bodyweightCount,
    'photoCount': photoCount,
    'programmeRevision': programmeRevision,
  };

  factory BackupManifest.fromJson(Map<String, dynamic> j) => BackupManifest(
    createdAt: DateTime.parse(j['createdAt'] as String),
    appVersion: j['appVersion'] as String? ?? 'unknown',
    schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 0,
    sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
    setCount: (j['setCount'] as num?)?.toInt() ?? 0,
    bodyweightCount: (j['bodyweightCount'] as num?)?.toInt() ?? 0,
    photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
    programmeRevision: (j['programmeRevision'] as num?)?.toInt() ?? 0,
  );

  String get summary =>
      '$sessionCount sessions, $setCount sets, $bodyweightCount weigh-ins'
      '${photoCount > 0 ? ', $photoCount photos' : ''}';
}

/// Exports and restores everything the app holds.
///
/// This ships in Phase 2 rather than Phase 8 for one reason: without it you
/// would carry nine weeks of logs and seven weeks of photos with no way off
/// the device, and a dropped phone or a failed migration would end the
/// project (docs/00-audit.md A5).
///
/// The zip is written where you choose and is never auto-shared. Progress
/// photos are private; an export is an explicit, manual act.
class BackupService {
  BackupService({
    required this.db,
    required this.appVersion,
    Directory? documentsDir,
  }) : _docsOverride = documentsDir;

  final AppDatabase db;
  final String appVersion;
  final Directory? _docsOverride;

  /// Rows as JSON rather than a copy of the sqlite file.
  ///
  /// Copying the file assumes the database lives at a known path, which is
  /// false for an in-memory database and brittle if the location ever moves.
  /// A row dump is portable, inspectable in a text editor, and survives a
  /// sqlite version change.
  static const dataEntry = 'data.json';
  static const manifestEntry = 'manifest.json';
  static const programmeEntry = 'programmes/programme.json';
  static const inventoryEntry = 'programmes/inventory.json';
  static const preferencesEntry = 'preferences.json';
  static const photosPrefix = 'photos/';
  static const clipsPrefix = 'clips/';

  Future<Directory> _docs() async =>
      _docsOverride ?? await getApplicationDocumentsDirectory();

  Future<BackupManifest> buildManifest() async {
    final sessions = await db.select(db.sessions).get();
    final sets = await db.select(db.setLogs).get();
    final weights = await db.select(db.bodyweights).get();

    final docs = await _docs();
    final photoDir = Directory(p.join(docs.path, 'photos'));
    final photos = photoDir.existsSync()
        ? photoDir.listSync(recursive: true).whereType<File>().length
        : 0;

    var revision = 0;
    final progFile = File(p.join(docs.path, 'programmes', 'programme.json'));
    if (progFile.existsSync()) {
      try {
        final j =
            jsonDecode(await progFile.readAsString()) as Map<String, dynamic>;
        revision = (j['revision'] as num?)?.toInt() ?? 0;
      } catch (_) {
        // A corrupt programme file must not stop a backup of the logs.
      }
    }

    return BackupManifest(
      createdAt: DateTime.now(),
      appVersion: appVersion,
      schemaVersion: db.schemaVersion,
      sessionCount: sessions.length,
      setCount: sets.length,
      bodyweightCount: weights.length,
      photoCount: photos,
      programmeRevision: revision,
    );
  }

  /// Writes a zip of the database, the programme files, the photos and the
  /// clips to [destination].
  ///
  /// Returns the file written.
  Future<File> export(File destination, {bool includeMedia = true}) async {
    final docs = await _docs();
    final archive = Archive();

    final manifest = await buildManifest();
    archive.addFile(
      _stringFile(
        manifestEntry,
        const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
      ),
    );

    archive.addFile(_stringFile(dataEntry, jsonEncode(await _dumpRows())));

    for (final (path, entry) in [
      (p.join(docs.path, 'programmes', 'programme.json'), programmeEntry),
      (p.join(docs.path, 'programmes', 'inventory.json'), inventoryEntry),
      (p.join(docs.path, 'preferences.json'), preferencesEntry),
    ]) {
      final f = File(path);
      if (f.existsSync()) {
        archive.addFile(_binaryFile(entry, await f.readAsBytes()));
      }
    }

    if (includeMedia) {
      await _addTree(
        archive,
        Directory(p.join(docs.path, 'photos')),
        photosPrefix,
        docs,
      );
      await _addTree(
        archive,
        Directory(p.join(docs.path, 'clips')),
        clipsPrefix,
        docs,
      );
    }

    final bytes = ZipEncoder().encode(archive);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return destination;
  }

  /// Reads a backup's manifest without applying anything.
  ///
  /// Restore is destructive, so the UI shows this first and asks.
  Future<BackupManifest?> inspect(File zip) async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    for (final f in archive.files) {
      if (f.name == manifestEntry && f.isFile) {
        return BackupManifest.fromJson(
          jsonDecode(utf8.decode(f.content as List<int>))
              as Map<String, dynamic>,
        );
      }
    }
    return null;
  }

  /// Replaces the current data with the contents of [zip].
  ///
  /// The caller MUST have confirmed with the athlete first — this wipes the
  /// database and overwrites the programme file.
  Future<BackupManifest> restore(File zip) async {
    final manifest = await inspect(zip);
    if (manifest == null) {
      throw const FormatException(
        'Not a Keller Twelve backup: no manifest.json inside.',
      );
    }
    if (manifest.schemaVersion > db.schemaVersion) {
      throw StateError(
        'That backup was made by a newer version of the app '
        '(schema ${manifest.schemaVersion} vs ${db.schemaVersion}). '
        'Update the app before restoring, or you will lose data.',
      );
    }

    final docs = await _docs();
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());

    // The database first, all or nothing: if it fails, nothing on disk has
    // been touched either.
    final data = archive.files.where((f) => f.isFile && f.name == dataEntry);
    if (data.isNotEmpty) {
      await _importRows(
        jsonDecode(utf8.decode(data.first.content as List<int>))
            as Map<String, dynamic>,
      );
    }

    // Then the files — only the ones a backup is made of, and only inside
    // the app's own folder. A zip names its own paths, and `../` in one
    // would otherwise write wherever it pointed.
    for (final f in archive.files) {
      if (!f.isFile || f.name == manifestEntry || f.name == dataEntry) {
        continue;
      }
      final target = _safeTarget(docs, f.name);
      if (target == null) continue;
      await target.parent.create(recursive: true);
      await target.writeAsBytes(f.content as List<int>, flush: true);
    }

    return manifest;
  }

  /// Where [entry] may be restored to, or null when it is not part of a
  /// backup or would land outside [docs].
  static File? _safeTarget(Directory docs, String entry) {
    final name = entry.replaceAll(r'\', '/');
    final known =
        name == programmeEntry ||
        name == inventoryEntry ||
        name == preferencesEntry ||
        name.startsWith(photosPrefix) ||
        name.startsWith(clipsPrefix);
    if (!known || p.isAbsolute(name)) return null;
    final root = p.normalize(p.absolute(docs.path));
    final target = p.normalize(p.absolute(p.join(root, name)));
    if (!p.isWithin(root, target)) return null;
    return File(target);
  }

  /// Every row of every table, keyed by table name.
  Future<Map<String, List<Map<String, Object?>>>> _dumpRows() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in db.allTables) {
      final name = t.actualTableName;
      final rows = await db.customSelect('SELECT * FROM "$name"').get();
      out[name] = rows.map((r) => r.data).toList();
    }
    return out;
  }

  Future<void> _importRows(Map<String, dynamic> dump) async {
    // Foreign keys off for the duration: set_logs reference sessions, and
    // insert order across tables is not guaranteed. Cannot be toggled inside
    // a transaction, so it brackets one.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      // The wipe inside the same transaction as the inserts. v3 wiped first
      // and committed it, so an import that failed part way — a row this
      // schema cannot hold — left an empty database.
      await db.transaction(() async {
        for (final t in db.allTables) {
          await db.delete(t).go();
        }
        for (final t in db.allTables) {
          final name = t.actualTableName;
          final rows = (dump[name] as List?)?.cast<Map<String, dynamic>>();
          if (rows == null) continue;
          for (final row in rows) {
            if (row.isEmpty) continue;
            final cols = row.keys.map((k) => '"$k"').join(', ');
            final holes = List.filled(row.length, '?').join(', ');
            await db.customInsert(
              'INSERT INTO "$name" ($cols) VALUES ($holes)',
              // Variable's type bound is Object, but its VALUE is nullable —
              // Variable<Object>(null) is how a NULL column round-trips.
              variables: row.values.map((v) => Variable<Object>(v)).toList(),
            );
          }
        }
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _addTree(
    Archive archive,
    Directory dir,
    String prefix,
    Directory docs,
  ) async {
    if (!dir.existsSync()) return;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: docs.path).replaceAll(r'\', '/');
      archive.addFile(_binaryFile(rel, await e.readAsBytes()));
    }
  }

  static ArchiveFile _stringFile(String name, String content) =>
      ArchiveFile.bytes(name, Uint8List.fromList(utf8.encode(content)));

  static ArchiveFile _binaryFile(String name, List<int> bytes) =>
      ArchiveFile.bytes(name, Uint8List.fromList(bytes));

  /// A filename that sorts chronologically and says what it is.
  static String suggestedFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'keller-twelve-${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.zip';
  }
}
