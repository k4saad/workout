import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/exercise.dart';
import '../domain/models/inventory.dart';
import '../domain/models/programme.dart';

/// Loads the programme, the exercise library and the plate inventory.
///
/// The shipped asset is the pristine Keller Twelve. On first launch it is
/// copied into the app documents directory, and every later read prefers that
/// copy. The asset is **never** mutated, so "reset to original" is always one
/// delete away and a bad edit in the in-app editor can never brick the app.
class ProgrammeRepository {
  ProgrammeRepository({Directory? documentsDir}) : _overrideDir = documentsDir;

  static const assetProgramme = 'assets/programmes/keller-twelve.json';
  static const assetSchema = 'assets/programmes/schema.json';
  static const assetExercises = 'assets/exercises/exercises.json';
  static const assetInventory = 'assets/programmes/inventory.json';

  static const _programmeFile = 'programme.json';
  static const _inventoryFile = 'inventory.json';

  final Directory? _overrideDir;

  Directory? _cachedDir;
  Programme? _programme;
  ExerciseLibrary? _library;
  Inventory? _inventory;

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

  /// Copies the shipped asset into the documents directory if no user copy
  /// exists yet. Safe to call on every launch.
  Future<void> ensureSeeded() async {
    final prog = await _file(_programmeFile);
    if (!prog.existsSync()) {
      await prog.writeAsString(await rootBundle.loadString(assetProgramme));
    }
    final inv = await _file(_inventoryFile);
    if (!inv.existsSync()) {
      await inv.writeAsString(await rootBundle.loadString(assetInventory));
    }
  }

  /// The active programme: the user copy if present, otherwise the asset.
  Future<Programme> loadProgramme({bool force = false}) async {
    if (_programme != null && !force) return _programme!;
    await ensureSeeded();
    final f = await _file(_programmeFile);
    final raw = f.existsSync()
        ? await f.readAsString()
        : await rootBundle.loadString(assetProgramme);
    return _programme = Programme.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// The exercise library. Always the asset — it is reference data, not
  /// something the athlete edits per-programme.
  Future<ExerciseLibrary> loadLibrary({bool force = false}) async {
    if (_library != null && !force) return _library!;
    final raw = await rootBundle.loadString(assetExercises);
    return _library = ExerciseLibrary.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Bar weights and plate counts. Editable — this is the calibration output,
  /// and every suggested load in the app depends on it being right.
  Future<Inventory> loadInventory({bool force = false}) async {
    if (_inventory != null && !force) return _inventory!;
    await ensureSeeded();
    final f = await _file(_inventoryFile);
    final raw = f.existsSync()
        ? await f.readAsString()
        : await rootBundle.loadString(assetInventory);
    return _inventory = Inventory.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Persists an edited programme, bumping `revision`.
  ///
  /// Writes to the user copy only. The asset stays pristine.
  Future<Programme> saveProgramme(Programme programme) async {
    final next = programme.copyWith(revision: programme.revision + 1);
    final f = await _file(_programmeFile);
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(next.toJson()),
    );
    return _programme = next;
  }

  Future<Inventory> saveInventory(Inventory inventory) async {
    final f = await _file(_inventoryFile);
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(inventory.toJson()),
    );
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

  /// True when the user has edited away from the shipped programme.
  Future<bool> get isModified async {
    final f = await _file(_programmeFile);
    if (!f.existsSync()) return false;
    final shipped = jsonDecode(
      await rootBundle.loadString(assetProgramme),
    ) as Map<String, dynamic>;
    final current = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return current['revision'] != shipped['revision'];
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
}
