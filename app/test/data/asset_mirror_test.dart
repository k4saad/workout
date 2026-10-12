import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app bundles copies of the reviewed files in `data/`. tools/gen.py
/// writes both, and this is what notices when someone edits one by hand.
///
/// Every Dart test reads the ASSET copy. A change made only in `data/` would
/// pass tools/validate.py, pass every test here, and never reach the phone.
void main() {
  const mirrors = {
    '../data/keller-twelve.json': 'assets/programmes/keller-twelve.json',
    '../data/inventory.json': 'assets/programmes/inventory.json',
    '../data/schema.json': 'assets/programmes/schema.json',
    '../data/exercises.json': 'assets/exercises/exercises.json',
    '../data/quotes.json': 'assets/content/quotes.json',
    '../data/fuel.json': 'assets/nutrition/fuel.json',
    '../data/motions.json': 'assets/exercises/motions.json',
    '../data/timetable.json': 'assets/content/timetable.json',
  };

  String norm(File f) => f.readAsStringSync().replaceAll('\r\n', '\n');

  for (final MapEntry(key: source, value: bundled) in mirrors.entries) {
    test('$bundled is identical to $source', () {
      final src = File(source);
      final dst = File(bundled);
      if (!src.existsSync() && !dst.existsSync()) {
        // Not authored yet. Both appear together, from gen.py.
        return;
      }
      expect(src.existsSync(), isTrue, reason: '$source is missing');
      expect(dst.existsSync(), isTrue, reason: '$bundled is missing');
      expect(
        norm(dst) == norm(src),
        isTrue,
        reason:
            '$bundled has drifted from $source. Edit data/, then run '
            'python tools/gen.py && python tools/validate.py',
      );
    });
  }
}
