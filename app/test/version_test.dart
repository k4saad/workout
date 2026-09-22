import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/session_providers.dart';

/// The version ritual, enforced.
///
/// `appVersion` is stamped into every backup manifest and `pubspec.yaml`
/// drives `versionName`/`versionCode` in the APK. They drifted apart once
/// already — 0.1.0+1 in the pubspec against 0.2.0+2 in the code — which meant
/// every backup zip named a build that never existed.
void main() {
  test('pubspec and appVersion agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');
    expect(
      match!.group(1),
      appVersion,
      reason:
          'bump BOTH: pubspec.yaml version: and appVersion in '
          'lib/app/session_providers.dart',
    );
  });

  test('the version code rises with the name', () {
    final parts = appVersion.split('+');
    expect(parts, hasLength(2), reason: 'version must be name+code');
    expect(int.tryParse(parts[1]), isNotNull);
    expect(
      int.parse(parts[1]),
      greaterThan(0),
      reason: 'Android refuses an install whose versionCode did not increase',
    );
  });
}
