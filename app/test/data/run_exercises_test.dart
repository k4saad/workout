import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/exercise.dart';

/// Which movements get the map is the library's call, not the app's: the
/// runs the programme prescribes carry a `gps` tag in exercises.json.
void main() {
  final library = ExerciseLibrary.fromJson(
    jsonDecode(File('assets/exercises/exercises.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('the programme runs can be tracked on the map', () {
    for (final id in ['easy-run', 'run-intervals', 'five-k-time-trial']) {
      expect(library.resolve(id).gpsTracked, isTrue, reason: id);
    }
  });

  test('strides and the lifts are not', () {
    for (final id in [
      'running-strides',
      'barbell-back-squat',
      'rope-skipping',
    ]) {
      expect(library.resolve(id).gpsTracked, isFalse, reason: id);
    }
  });
}
