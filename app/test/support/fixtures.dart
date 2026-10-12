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

  /// The semester's week: assets/content/timetable.json.
  static Map<String, dynamic> get timetableJson =>
      _json('assets/content/timetable.json');

  /// The eating plan: assets/nutrition/fuel.json.
  static Map<String, dynamic> get fuelJson =>
      _json('assets/nutrition/fuel.json');

  static Programme get programme => Programme.fromJson(programmeJson);

  static ExerciseLibrary get library => ExerciseLibrary.fromJson(exercisesJson);

  /// The kit the app ships: what tests of the SHIPPED data use.
  static Inventory get inventory => Inventory.fromJson(inventoryJson);

  /// The v2 placeholder inventory, pinned as a literal: a 9 kg bar, a 6 kg EZ
  /// bar, 2 kg handles and 0.25 kg microplates, so a 0.5 kg barbell step.
  ///
  /// Tests of ENGINE behaviour (the plate solver, the ramp generator, the
  /// progression engine) were written against these numbers, straight from
  /// the worked examples in docs/02-data-model.md. They use this so they keep
  /// testing the algorithm, and do not change meaning every time the kit in
  /// data/inventory.json does. v3 replaced the shipped kit (10 kg bar, 1 kg
  /// plates); tests of what ships use [inventory].
  static Inventory get legacyInventory => Inventory.fromJson(
    jsonDecode(_legacyInventoryJson) as Map<String, dynamic>,
  );

  static const _legacyInventoryJson = '''
{
  "bars": [
    {"id": "barbell", "name": "Standard spinlock barbell", "weightKg": 9.0, "measured": false},
    {"id": "ezBar", "name": "EZ curl bar", "weightKg": 6.0, "measured": false},
    {"id": "dbHandle", "name": "Dumbbell handle", "weightKg": 2.0, "measured": false}
  ],
  "plates": [
    {"weightKg": 20.0, "count": 2, "bore": "standard"},
    {"weightKg": 10.0, "count": 4, "bore": "standard"},
    {"weightKg": 5.0, "count": 8, "bore": "standard"},
    {"weightKg": 2.5, "count": 8, "bore": "standard"},
    {"weightKg": 1.25, "count": 8, "bore": "standard"},
    {"weightKg": 0.5, "count": 8, "bore": "standard"},
    {"weightKg": 0.25, "count": 8, "bore": "standard"}
  ],
  "fixedDumbbells": [{"weightKg": 2.0, "count": 2}, {"weightKg": 3.0, "count": 2}],
  "kettlebells": [{"weightKg": 8.0}],
  "collarWeightKg": 0.0,
  "room": {
    "ceilingLiftingCm": null,
    "ceilingSkippingCm": null,
    "pullUpClearanceCm": null,
    "carryLengthM": null
  }
}
''';
}
