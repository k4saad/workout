import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/exercise.dart';
import '../domain/fuel/fuel_plan.dart';
import '../domain/motion/motion.dart';
import '../domain/models/inventory.dart';
import '../domain/models/programme.dart';

/// Reads a bundled asset as a string. [rootBundle] on a phone; a disk read or
/// a patched copy in tests.
typedef AssetLoader = Future<String> Function(String key);

/// What the last shipped-revision upgrade (or rescue of an unreadable file)
/// replaced, kept until the athlete has seen it.
///
/// Nothing is ever deleted: every replaced file is renamed into a backup next
/// to its replacement, and [programmeBackup] / [inventoryBackup] name it.
class ProgrammeUpgrade {
  const ProgrammeUpgrade({
    required this.at,
    this.programmeFrom,
    this.programmeTo,
    this.programmeBackup,
    this.programmeUnreadable = false,
    this.programmeWasEdited = false,
    this.keptStartDate,
    this.inventoryFrom,
    this.inventoryTo,
    this.inventoryBackup,
    this.inventoryUnreadable = false,
  });

  final DateTime at;

  /// The shipped revision the old copy came from, and the one now in place.
  final int? programmeFrom;
  final int? programmeTo;

  /// File name of the old programme, inside the programmes directory.
  final String? programmeBackup;

  /// The old programme could not be read at all.
  final bool programmeUnreadable;

  /// The old copy had been saved since it was seeded — the editor, a moved
  /// start date or an import — so the backup holds work of the athlete's own.
  final bool programmeWasEdited;

  /// The start date carried over from the old copy.
  final DateTime? keptStartDate;

  final int? inventoryFrom;
  final int? inventoryTo;
  final String? inventoryBackup;
  final bool inventoryUnreadable;

  bool get replacedProgramme => programmeBackup != null;
  bool get replacedInventory => inventoryBackup != null;

  factory ProgrammeUpgrade.fromJson(Map<String, dynamic> j) => ProgrammeUpgrade(
    at: DateTime.parse(j['at'] as String),
    programmeFrom: (j['programmeFrom'] as num?)?.toInt(),
    programmeTo: (j['programmeTo'] as num?)?.toInt(),
    programmeBackup: j['programmeBackup'] as String?,
    programmeUnreadable: j['programmeUnreadable'] as bool? ?? false,
    programmeWasEdited: j['programmeWasEdited'] as bool? ?? false,
    keptStartDate: j['keptStartDate'] == null
        ? null
        : DateTime.parse(j['keptStartDate'] as String),
    inventoryFrom: (j['inventoryFrom'] as num?)?.toInt(),
    inventoryTo: (j['inventoryTo'] as num?)?.toInt(),
    inventoryBackup: j['inventoryBackup'] as String?,
    inventoryUnreadable: j['inventoryUnreadable'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'programmeFrom': programmeFrom,
    'programmeTo': programmeTo,
    'programmeBackup': programmeBackup,
    'programmeUnreadable': programmeUnreadable,
    'programmeWasEdited': programmeWasEdited,
    'keptStartDate': keptStartDate?.toIso8601String(),
    'inventoryFrom': inventoryFrom,
    'inventoryTo': inventoryTo,
    'inventoryBackup': inventoryBackup,
    'inventoryUnreadable': inventoryUnreadable,
  };
}

/// Which shipped revisions the phone's copies descend from.
///
/// A sidecar, not a field inside programme.json: `Programme.toJson` drops
/// keys it does not know, and the programme's own `revision` is bumped by
/// every save, so it cannot say which RELEASE a copy came from.
class _SeedRecord {
  const _SeedRecord({
    required this.programmeRevision,
    required this.programmeHash,
    required this.inventoryRevision,
    this.notice,
  });

  /// The shipped programme revision the copy was seeded or upgraded from.
  final int programmeRevision;

  /// Hash of programme.json exactly as it was written then. A different hash
  /// now means the athlete has saved over it.
  final String? programmeHash;

  final int inventoryRevision;

  /// An upgrade the athlete has not dismissed yet.
  final ProgrammeUpgrade? notice;

  static _SeedRecord? tryParse(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return _SeedRecord(
        programmeRevision: (j['programmeRevision'] as num).toInt(),
        programmeHash: j['programmeHash'] as String?,
        inventoryRevision: (j['inventoryRevision'] as num?)?.toInt() ?? 1,
        notice: j['notice'] == null
            ? null
            : ProgrammeUpgrade.fromJson(j['notice'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'programmeRevision': programmeRevision,
    'programmeHash': programmeHash,
    'inventoryRevision': inventoryRevision,
    'notice': notice?.toJson(),
  };
}

/// Loads the programme, the exercise library and the plate inventory.
///
/// The shipped asset is the pristine Keller Twelve. On first launch it is
/// copied into the app documents directory, and every later read prefers that
/// copy. The asset is **never** mutated, so "reset to original" is always one
/// delete away and a bad edit in the in-app editor can never brick the app.
///
/// **Shipped-revision upgrades.** A copy made once and kept forever meant a
/// phone never saw a corrected programme. `seeded.json` records which shipped
/// revision each copy came from; when a newer one ships, the old copy is
/// renamed to `programme.rev<N>.<stamp>.json` (or `inventory.rev<N>…`), the
/// shipped file takes its place, and the athlete's start date is carried
/// over. Set logs live in the database and are never touched. A programme of
/// the athlete's own — a later cycle, with its own id — is never replaced.
/// No failure here ever stops the app opening: the worst case is that the
/// phone keeps the copy it had.
class ProgrammeRepository {
  ProgrammeRepository({
    Directory? documentsDir,
    AssetLoader? loadAsset,
    DateTime Function()? clock,
  }) : _overrideDir = documentsDir,
       _loadAsset = loadAsset ?? rootBundle.loadString,
       _clock = clock ?? DateTime.now;

  static const assetProgramme = 'assets/programmes/keller-twelve.json';
  static const assetSchema = 'assets/programmes/schema.json';
  static const assetExercises = 'assets/exercises/exercises.json';
  static const assetInventory = 'assets/programmes/inventory.json';
  static const assetFuel = 'assets/nutrition/fuel.json';
  static const assetMotions = 'assets/exercises/motions.json';

  static const _programmeFile = 'programme.json';
  static const _inventoryFile = 'inventory.json';
  static const _recordFile = 'seeded.json';

  /// v0.11 wrote no record. It shipped revision 1 of both files.
  static const _unrecordedRevision = 1;

  static const _pretty = JsonEncoder.withIndent('  ');

  final Directory? _overrideDir;
  final AssetLoader _loadAsset;
  final DateTime Function() _clock;

  Directory? _cachedDir;
  Programme? _programme;
  ExerciseLibrary? _library;
  FuelPlan? _fuel;
  MotionLibrary? _motions;
  Inventory? _inventory;

  ProgrammeUpgrade? _lastUpgrade;
  Future<void>? _seeding;

  /// The full check against the shipped revisions has run this launch.
  bool _checked = false;

  /// The upgrade the athlete has not acknowledged yet, if any. Filled in by
  /// [ensureSeeded]; null until that has run.
  ProgrammeUpgrade? get lastUpgrade => _lastUpgrade;

  Future<Directory> _dir() async {
    if (_overrideDir != null) return _overrideDir;
    _cachedDir ??= Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'programmes'),
    )..createSync(recursive: true);
    if (!_cachedDir!.existsSync()) _cachedDir!.createSync(recursive: true);
    return _cachedDir!;
  }

  Future<File> _file(String name) async =>
      File(p.join((await _dir()).path, name));

  /// Copies the shipped assets into the documents directory where no copy
  /// exists, upgrades copies an older release seeded, and rescues unreadable
  /// ones. Safe — and cheap — to call on every launch.
  ///
  /// The full check (which reads the asset bundle) runs once per launch.
  /// After that, a call only re-seeds a copy that has gone missing — a reset
  /// — so reloading after an edit costs two `existsSync`s, not two asset
  /// reads.
  ///
  /// Never throws. Concurrent callers share one run, so two providers loading
  /// at once cannot both back up the same file.
  Future<void> ensureSeeded() =>
      _seeding ??= _reconcileSafely().whenComplete(() => _seeding = null);

  Future<void> _reconcileSafely() async {
    try {
      await _reconcile();
    } catch (_) {
      // A missing bundle, a full disk, a permission error: the phone keeps
      // the copies it has, and the loaders fall back to the asset if there
      // are none. Opening the app matters more than upgrading it.
    }
  }

  Future<void> _reconcile() async {
    final dir = await _dir();
    if (_checked &&
        File(p.join(dir.path, _programmeFile)).existsSync() &&
        File(p.join(dir.path, _inventoryFile)).existsSync()) {
      return;
    }
    final recordFile = File(p.join(dir.path, _recordFile));
    final record = recordFile.existsSync()
        ? _SeedRecord.tryParse(await recordFile.readAsString())
        : null;
    _lastUpgrade = record?.notice;

    final shippedProgrammeRaw = await _loadAsset(assetProgramme);
    final shippedProgramme =
        jsonDecode(shippedProgrammeRaw) as Map<String, dynamic>;
    final shippedProgrammeRev = _revisionOf(shippedProgramme);
    final shippedInventoryRaw = await _loadAsset(assetInventory);
    final shippedInventoryRev = _revisionOf(
      jsonDecode(shippedInventoryRaw) as Map<String, dynamic>,
    );

    final stamp = _stamp(_clock());
    var programmeRev = record?.programmeRevision ?? _unrecordedRevision;
    var programmeHash = record?.programmeHash;
    var dirty = record == null;
    ProgrammeUpgrade? notice;

    // ---- programme.json ------------------------------------------------
    final prog = File(p.join(dir.path, _programmeFile));
    if (!prog.existsSync()) {
      await _write(prog, shippedProgrammeRaw);
      programmeRev = shippedProgrammeRev;
      programmeHash = _hash(shippedProgrammeRaw);
      dirty = true;
    } else {
      final raw = await prog.readAsString();
      final stored = _tryProgramme(raw);
      if (stored == null) {
        final backup = await _backup(prog, 'programme.unreadable.$stamp.json');
        await _write(prog, shippedProgrammeRaw);
        programmeRev = shippedProgrammeRev;
        programmeHash = _hash(shippedProgrammeRaw);
        dirty = true;
        notice = ProgrammeUpgrade(
          at: _clock(),
          programmeTo: shippedProgrammeRev,
          programmeBackup: backup,
          programmeUnreadable: true,
        );
      } else if (shippedProgrammeRev > programmeRev &&
          stored['id'] == shippedProgramme['id']) {
        final edited = programmeHash != null
            ? _hash(raw) != programmeHash
            // No record: v0.11 shipped revision 1, and every save bumps it.
            : _revisionOf(stored) != _unrecordedRevision;
        final backup = await _backup(
          prog,
          'programme.rev$programmeRev.$stamp.json',
        );
        // Copy the shipped JSON, not a model round-trip: toJson would drop
        // any field the running build's model does not know yet.
        final next = Map<String, dynamic>.of(shippedProgramme);
        final startDate = stored['startDate'];
        if (startDate is String && DateTime.tryParse(startDate) != null) {
          next['startDate'] = startDate;
        }
        final out = _pretty.convert(next);
        await _write(prog, out);
        notice = ProgrammeUpgrade(
          at: _clock(),
          programmeFrom: programmeRev,
          programmeTo: shippedProgrammeRev,
          programmeBackup: backup,
          programmeWasEdited: edited,
          keptStartDate: DateTime.tryParse('${next['startDate']}'),
        );
        programmeRev = shippedProgrammeRev;
        programmeHash = _hash(out);
        dirty = true;
      }
      // Otherwise: already current, or a programme of the athlete's own (a
      // later cycle has its own id). Left exactly as it is.
    }

    // ---- inventory.json ------------------------------------------------
    // The kit carries its own `revision`, which saving preserves, so the file
    // itself says which release it came from. v0.11 files have none: 1.
    var inventoryRev = shippedInventoryRev;
    final inv = File(p.join(dir.path, _inventoryFile));
    if (!inv.existsSync()) {
      await _write(inv, shippedInventoryRaw);
    } else {
      final raw = await inv.readAsString();
      final stored = _tryInventory(raw);
      if (stored == null) {
        final backup = await _backup(inv, 'inventory.unreadable.$stamp.json');
        await _write(inv, shippedInventoryRaw);
        notice = _withInventory(
          notice,
          to: shippedInventoryRev,
          backup: backup,
          unreadable: true,
        );
      } else if (shippedInventoryRev > stored.revision) {
        final backup = await _backup(
          inv,
          'inventory.rev${stored.revision}.$stamp.json',
        );
        await _write(inv, shippedInventoryRaw);
        notice = _withInventory(
          notice,
          from: stored.revision,
          to: shippedInventoryRev,
          backup: backup,
        );
      } else {
        inventoryRev = stored.revision;
      }
    }
    if (record?.inventoryRevision != inventoryRev) dirty = true;

    if (notice != null) {
      _lastUpgrade = notice;
      dirty = true;
    }
    _checked = true;
    if (dirty) {
      await _write(
        recordFile,
        _pretty.convert(
          _SeedRecord(
            programmeRevision: programmeRev,
            programmeHash: programmeHash,
            inventoryRevision: inventoryRev,
            notice: _lastUpgrade,
          ).toJson(),
        ),
      );
    }
  }

  ProgrammeUpgrade _withInventory(
    ProgrammeUpgrade? n, {
    int? from,
    required int to,
    required String backup,
    bool unreadable = false,
  }) => ProgrammeUpgrade(
    at: n?.at ?? _clock(),
    programmeFrom: n?.programmeFrom,
    programmeTo: n?.programmeTo,
    programmeBackup: n?.programmeBackup,
    programmeUnreadable: n?.programmeUnreadable ?? false,
    programmeWasEdited: n?.programmeWasEdited ?? false,
    keptStartDate: n?.keptStartDate,
    inventoryFrom: from,
    inventoryTo: to,
    inventoryBackup: backup,
    inventoryUnreadable: unreadable,
  );

  /// The athlete has seen the notice. Forget it, on disk too.
  Future<void> dismissUpgradeNotice() async {
    _lastUpgrade = null;
    try {
      final f = await _file(_recordFile);
      if (!f.existsSync()) return;
      final record = _SeedRecord.tryParse(await f.readAsString());
      if (record == null) return;
      await _write(
        f,
        _pretty.convert(
          _SeedRecord(
            programmeRevision: record.programmeRevision,
            programmeHash: record.programmeHash,
            inventoryRevision: record.inventoryRevision,
          ).toJson(),
        ),
      );
    } catch (_) {
      // Worst case the notice shows once more.
    }
  }

  /// The active programme: the user copy if present, otherwise the asset.
  Future<Programme> loadProgramme({bool force = false}) async {
    if (_programme != null && !force) return _programme!;
    await ensureSeeded();
    final f = await _file(_programmeFile);
    if (f.existsSync()) {
      final stored = _tryProgramme(await f.readAsString());
      if (stored != null) return _programme = Programme.fromJson(stored);
    }
    return _programme = Programme.fromJson(
      jsonDecode(await _loadAsset(assetProgramme)) as Map<String, dynamic>,
    );
  }

  /// The exercise library. Always the asset — it is reference data, not
  /// something the athlete edits per-programme.
  Future<ExerciseLibrary> loadLibrary({bool force = false}) async {
    if (_library != null && !force) return _library!;
    final raw = await _loadAsset(assetExercises);
    return _library = ExerciseLibrary.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// The eating plan. Always the asset: it is generated reference data, like
  /// the exercise library, not something edited per-cycle.
  Future<FuelPlan> loadFuel({bool force = false}) async {
    if (_fuel != null && !force) return _fuel!;
    final raw = await _loadAsset(assetFuel);
    return _fuel = FuelPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// The exercise demos. Always the asset: generated by tools/gen_motions.py
  /// and never edited per-programme.
  Future<MotionLibrary> loadMotions({bool force = false}) async {
    if (_motions != null && !force) return _motions!;
    final raw = await _loadAsset(assetMotions);
    return _motions = MotionLibrary.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Bar weights and plate counts: the kit every suggested load is built
  /// from. Editable in Settings → Your equipment.
  Future<Inventory> loadInventory({bool force = false}) async {
    if (_inventory != null && !force) return _inventory!;
    await ensureSeeded();
    final f = await _file(_inventoryFile);
    if (f.existsSync()) {
      final stored = _tryInventory(await f.readAsString());
      if (stored != null) return _inventory = stored;
    }
    return _inventory = Inventory.fromJson(
      jsonDecode(await _loadAsset(assetInventory)) as Map<String, dynamic>,
    );
  }

  /// Persists an edited programme, bumping `revision`.
  ///
  /// Writes to the user copy only. The asset stays pristine.
  Future<Programme> saveProgramme(Programme programme) async {
    final next = programme.copyWith(revision: programme.revision + 1);
    final f = await _file(_programmeFile);
    await f.writeAsString(_pretty.convert(next.toJson()));
    return _programme = next;
  }

  Future<Inventory> saveInventory(Inventory inventory) async {
    final f = await _file(_inventoryFile);
    await f.writeAsString(_pretty.convert(inventory.toJson()));
    return _inventory = inventory;
  }

  /// Throws away every local edit and re-copies the shipped programme.
  ///
  /// Trivial precisely because the asset was never touched.
  Future<Programme> resetToShipped() async {
    final f = await _file(_programmeFile);
    if (f.existsSync()) await f.delete();
    _programme = null;
    return loadProgramme(force: true);
  }

  /// True when the phone's programme differs from what was seeded: an edit,
  /// a moved start date, an import or a new cycle.
  Future<bool> get isModified async {
    final f = await _file(_programmeFile);
    if (!f.existsSync()) return false;
    final current = _hash(await f.readAsString());
    final record = await _file(_recordFile);
    final seeded = record.existsSync()
        ? _SeedRecord.tryParse(await record.readAsString())?.programmeHash
        : null;
    return current != (seeded ?? _hash(await _loadAsset(assetProgramme)));
  }

  /// Forget the cached programme only.
  ///
  /// After an edit, the exercise library and the plate inventory have not
  /// changed — re-reading seventy-six exercises out of the asset bundle to
  /// learn that a set count went from four to five is pure waste.
  void invalidateProgramme() => _programme = null;

  void invalidate() {
    _programme = null;
    _library = null;
    _inventory = null;
  }

  // ---- helpers ---------------------------------------------------------

  /// The decoded programme if [raw] is one the model can read, else null.
  static Map<String, dynamic>? _tryProgramme(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      Programme.fromJson(j);
      return j;
    } catch (_) {
      return null;
    }
  }

  static Inventory? _tryInventory(String raw) {
    try {
      return Inventory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static int _revisionOf(Map<String, dynamic> j) =>
      (j['revision'] as num?)?.toInt() ?? _unrecordedRevision;

  /// Renames [f] to [name] beside it and returns the name. A rename, not a
  /// copy: the bytes cannot be lost between two writes.
  static Future<String> _backup(File f, String name) async {
    var target = File(p.join(f.parent.path, name));
    for (var i = 2; target.existsSync(); i++) {
      target = File(
        p.join(f.parent.path, name.replaceFirst('.json', '-$i.json')),
      );
    }
    await f.rename(target.path);
    return p.basename(target.path);
  }

  /// Writes through a temp file and a rename, so a crash mid-write leaves
  /// the old file or the new one — never half of either.
  static Future<void> _write(File f, String contents) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(f.path);
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// FNV-1a, 32-bit, over the UTF-8 bytes. Enough to tell "the file we
  /// wrote" from "a file someone saved since"; not a security boundary.
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
