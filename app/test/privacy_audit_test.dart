import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy guarantees, enforced by the build rather than by memory.
///
/// docs/00-audit.md calls photo leakage the single most likely privacy
/// mistake in this app, and it happens BY DEFAULT — leave `allowBackup` alone
/// and Android uploads app-private storage, progress photos included, to
/// Google Drive.
///
/// Every check here guards something that is currently right and would be
/// silently wrong after one careless edit. They are cheap; they run forever.
void main() {
  String read(String relative) =>
      File(relative).readAsStringSync().replaceAll('\r\n', '\n');

  /// These files EXPLAIN what they refuse to do, at length. Scanning the raw
  /// text would flag the comment that says "never MediaStore" as though it
  /// were a call to MediaStore, so comments come out first.
  String stripXmlComments(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  String stripDartComments(String dart) => dart
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('manifest', () {
    late String manifest;

    setUpAll(
      () => manifest = stripXmlComments(
        read('android/app/src/main/AndroidManifest.xml'),
      ),
    );

    test('backups are off', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest.contains('android:allowBackup="true"'),
        isFalse,
        reason: 'this uploads every progress photo to Google Drive',
      );
    });

    test('both backup rule files are wired in', () {
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    test('the app cannot reach the network', () {
      expect(
        manifest.contains('android.permission.INTERNET'),
        isFalse,
        reason:
            'This app holds a year of training data and a gallery of private '
            'photos. Adding INTERNET is a decision to discuss, not a fix.',
      );
      expect(manifest.contains('ACCESS_NETWORK_STATE'), isFalse);
    });

    test('no location permission — this is not a running app', () {
      expect(manifest.contains('ACCESS_FINE_LOCATION'), isFalse);
      expect(manifest.contains('ACCESS_COARSE_LOCATION'), isFalse);
    });

    test('no external storage permission', () {
      expect(
        manifest.contains('WRITE_EXTERNAL_STORAGE'),
        isFalse,
        reason: 'app-private storage only; never a path the gallery can see',
      );
      expect(manifest.contains('MANAGE_EXTERNAL_STORAGE'), isFalse);
      expect(manifest.contains('READ_MEDIA_IMAGES'), isFalse);
    });

    test(
      'the exact-alarm permissions the rest timer depends on are present',
      () {
        expect(manifest, contains('android.permission.USE_EXACT_ALARM'));
        expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
      },
    );
  });

  group('backup rules exclude the private media', () {
    test('cloud backup excludes photos, clips and the database', () {
      final rules = read('android/app/src/main/res/xml/backup_rules.xml');
      for (final path in ['photos/', 'clips/', 'keller_twelve.sqlite']) {
        expect(rules, contains(path));
      }
    });

    test('Android 12+ extraction rules exclude them too', () {
      final rules = read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      expect(rules, contains('<cloud-backup>'));
      expect(rules, contains('photos/'));
      expect(rules, contains('clips/'));
    });
  });

  group('no code path uploads anything', () {
    late List<({String path, String source})> dartFiles;

    setUpAll(() {
      dartFiles = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            (
              path: f.path.replaceAll(r'\', '/'),
              source: stripDartComments(f.readAsStringSync()),
            ),
      ];
      expect(dartFiles, isNotEmpty);
    });

    test('nothing imports an HTTP client', () {
      for (final f in dartFiles) {
        for (final banned in [
          "import 'dart:io'"
              ' as http',
          "package:http/",
          "package:dio/",
          'HttpClient(',
          'package:firebase',
        ]) {
          expect(
            f.source.contains(banned),
            isFalse,
            reason: '${f.path} reaches for the network',
          );
        }
      }
    });

    test('nothing writes to a public media directory', () {
      for (final f in dartFiles) {
        for (final banned in [
          'MediaStore',
          '/sdcard/',
          'getExternalStorageDirectory',
          'DCIM',
        ]) {
          expect(
            f.source.contains(banned),
            isFalse,
            reason: '${f.path} would put photos where the gallery can see them',
          );
        }
      }
    });

    test('no analytics or crash reporting', () {
      final pubspec = read('pubspec.yaml');
      for (final banned in [
        'firebase',
        'sentry',
        'analytics',
        'crashlytics',
        'mixpanel',
        'posthog',
      ]) {
        expect(
          pubspec.toLowerCase().contains(banned),
          isFalse,
          reason: 'pubspec.yaml pulls in $banned',
        );
      }
    });

    test('the only outbound call is url_launcher', () {
      final pubspec = read('pubspec.yaml');
      expect(pubspec, contains('url_launcher'));
    });
  });

  group('release signing', () {
    test('the release build never falls back to the debug key', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(
        gradle.contains('signingConfigs.getByName("debug")'),
        isFalse,
        reason:
            'changing the signing key later forces an uninstall, which '
            'deletes the database and every progress photo',
      );
      expect(gradle, contains('signingConfigs.getByName("release")'));
    });

    test('minification is on, with rules for the reflective plugins', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('proguard-rules.pro'));

      final rules = read('android/app/proguard-rules.pro');
      // These two are referenced as strings in the manifest. If R8 strips
      // them the rest timer stops firing with the screen off.
      expect(rules, contains('ScheduledNotificationReceiver'));
      expect(rules, contains('ScheduledNotificationBootReceiver'));
      expect(rules, contains('io.flutter.plugins.camera'));
    });

    test('secrets are not in the repository', () {
      expect(File('android/key.properties').existsSync(), isTrue);
      final ignore = read('../.gitignore');
      expect(ignore, contains('key.properties'));
      expect(ignore.contains('.jks') || ignore.contains('*.jks'), isTrue);
    });
  });
}
