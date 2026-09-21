import 'dart:convert';
import 'dart:io';

import 'package:keller_twelve/domain/models/exercise.dart';
import 'package:keller_twelve/domain/models/inventory.dart';
import 'package:keller_twelve/domain/models/programme.dart';

/// Loads the shipped asset JSON straight off disk.
///
/// Unit tests do not go through `rootBundle` — these are pure-Dart tests that
/// run without a device, which is the whole point of keeping `lib/domain/`
/// free of Flutter imports.
class Fixtures {
  static Map<String, dynamic> _json(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  static Map<String, dynamic> get programmeJson =>
      _json('assets/programmes/keller-twelve.json');

  static Map<String, dynamic> get schemaJson =>
      _json('assets/programmes/schema.json');

  static Map<String, dynamic> get exercisesJson =>
      _json('assets/exercises/exercises.json');

  static Map<String, dynamic> get inventoryJson =>
      _json('assets/programmes/inventory.json');

  static Programme get programme => Programme.fromJson(programmeJson);

  static ExerciseLibrary get library => ExerciseLibrary.fromJson(exercisesJson);

  static Inventory get inventory => Inventory.fromJson(inventoryJson);
}
