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

    test('the network is there for open map data, and nothing else', () {
      // v3 added INTERNET for the run map's OpenStreetMap tiles — approved
      // by Saad on 2026-09-23 — and v4 the hike's elevation tiles, approved
      // 2026-10-04. What keeps that honest is the "no code path uploads
      // anything" group below: the open-data hosts are the only ones lib/
      // may name, and the one download is a GET.
      expect(manifest, contains('android.permission.INTERNET'));
      expect(
        manifest.contains('ACCESS_NETWORK_STATE'),
        isFalse,
        reason: 'nothing here decides what to send based on connectivity',
      );
    });

    test('location is foreground-only: never in the background', () {
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      // Screen-off tracking runs as a visible foreground service started
      // from a tap. It does not need background location, and without it the
      // app cannot see where you are at any other time.
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
      );
      expect(
        manifest.contains('ACCESS_BACKGROUND_LOCATION'),
        isFalse,
        reason: 'the tracker never needs location while the app is closed',
      );
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
    // Everything the app keeps is in path_provider's documents directory,
    // which on Android is <data dir>/app_flutter/: the "root" domain. The
    // v2 rules named the "file" and "database" domains — folders the app
    // never writes to — so they excluded nothing.
    final exclude = RegExp(r'<exclude\s+domain="(\w+)"\s+path="([^"]+)"');

    Set<String> excluded(String xml) => {
      for (final m in exclude.allMatches(xml)) '${m.group(1)}:${m.group(2)}',
    };

    test('cloud backup excludes everything the app keeps', () {
      final rules = read('android/app/src/main/res/xml/backup_rules.xml');
      expect(excluded(rules), contains('root:app_flutter/'));
    });

    test('Android 12+ cloud backup excludes it too', () {
      final rules = read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      final cloud = rules.substring(
        rules.indexOf('<cloud-backup>'),
        rules.indexOf('</cloud-backup>'),
      );
      expect(excluded(cloud), contains('root:app_flutter/'));
    });

    test('a phone-to-phone transfer carries no photo, thumbnail or clip', () {
      // allowBackup="false" does NOT stop this on Android 12+.
      final rules = read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      final transfer = rules.substring(
        rules.indexOf('<device-transfer>'),
        rules.indexOf('</device-transfer>'),
      );
      expect(
        excluded(transfer),
        containsAll([
          'root:app_flutter/photos/',
          'root:app_flutter/thumbs/',
          'root:app_flutter/clips/',
        ]),
      );
    });

    test('no rule points at a folder the app does not use', () {
      for (final f in ['backup_rules.xml', 'data_extraction_rules.xml']) {
        for (final rule in excluded(read('android/app/src/main/res/xml/$f'))) {
          expect(rule, startsWith('root:app_flutter/'), reason: '$f: $rule');
        }
      }
    });

    test('the media folders are the ones the repository writes to', () {
      final repo = read('lib/data/media_repository.dart');
      for (final dir in ['photos', 'clips', 'thumbs']) {
        expect(repo, contains("Dir = '$dir'"), reason: dir);
      }
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

    /// The one file that may open a connection: elevation tiles for the
    /// hike's 3D view.
    const downloader = 'lib/data/run_terrain.dart';

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
          if (banned == 'HttpClient(' && f.path.endsWith(downloader)) continue;
          expect(
            f.source.contains(banned),
            isFalse,
            reason: '${f.path} reaches for the network',
          );
        }
      }
    });

    test('the one download is a GET of open elevation tiles', () {
      final file = dartFiles.singleWhere((f) => f.path.endsWith(downloader));
      expect(file.source, contains('getUrl('));
      for (final banned in [
        'postUrl',
        'putUrl',
        'patchUrl',
        'deleteUrl',
        'openUrl',
        'request.add',
        'request.write',
        'headers.set',
        'headers.add',
        'package:geolocator/',
        'package:flutter_map/',
      ]) {
        expect(
          file.source.contains(banned),
          isFalse,
          reason: 'the terrain download reaches for $banned',
        );
      }
      final hosts = RegExp(r"https?://([a-zA-Z0-9.\-{}]+)")
          .allMatches(file.source)
          .map((m) => m.group(1))
          .toSet();
      expect(hosts, {'s3.amazonaws.com'});
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

    test('the only hosts named anywhere in lib/ are the allowed ones', () {
      // Every URL literal in the app. Tiles and the OSM copyright page for
      // the map, YouTube for demo links. Anything else is a new outbound
      // call, and that is a decision to discuss, not a fix.
      const allowed = {
        'tile.openstreetmap.org',
        's3.amazonaws.com',
        'www.openstreetmap.org',
        'www.youtube.com',
        'youtube.com',
        'youtu.be',
        'm.youtube.com',
      };
      final url = RegExp(r"https?://([a-zA-Z0-9.\-{}]+)");
      for (final f in dartFiles) {
        for (final m in url.allMatches(f.source)) {
          final host = m.group(1)!;
          expect(
            allowed.contains(host),
            isTrue,
            reason: '${f.path} names $host',
          );
          if (host == 's3.amazonaws.com') {
            expect(
              f.path.endsWith(downloader),
              isTrue,
              reason: 'elevation tiles are fetched in one place only',
            );
          }
        }
      }
    });

    test('photo and media code never touches a network package', () {
      // With INTERNET granted, THIS is the guard that matters most: the
      // files that hold progress photos cannot even import the map, the
      // location plugin or the link launcher.
      for (final f in dartFiles) {
        final media =
            f.path.contains('/features/progress/') ||
            f.path.endsWith('/data/media_repository.dart') ||
            f.path.endsWith('/data/backup_service.dart');
        if (!media) continue;
        for (final banned in [
          'package:flutter_map/',
          'package:geolocator/',
          'package:url_launcher/',
          'package:share_plus/',
          'run_terrain.dart',
        ]) {
          if (banned == 'package:share_plus/' &&
              f.path.endsWith('/data/backup_service.dart')) {
            // Export is manual and user-initiated: the share sheet IS the
            // export. It is the one sanctioned way photos leave the phone.
            continue;
          }
          expect(
            f.source.contains(banned),
            isFalse,
            reason: '${f.path} imports $banned',
          );
        }
      }
    });

    test('only the run feature may use location or draw the map', () {
      for (final f in dartFiles) {
        final runs =
            f.path.contains('/features/runs/') ||
            f.path.contains('/data/run') ||
            f.path.contains('/app/run');
        if (runs) continue;
        for (final banned in ['package:geolocator/', 'package:flutter_map/']) {
          expect(
            f.source.contains(banned),
            isFalse,
            reason: '${f.path} reaches for $banned outside the run feature',
          );
        }
      }
    });

    test('a shared run card carries a line, never a map or a place', () {
      // A GPS trail is a home address. The share card is the one way it
      // leaves the phone outside a backup: drawn as a line from the route
      // with its ends cut (privateRoute), never a map tile, never a
      // coordinate, never the location plugin.
      final card = dartFiles.singleWhere(
        (f) => f.path.endsWith('/features/runs/run_share_card.dart'),
      );
      for (final banned in [
        'package:flutter_map/',
        'package:geolocator/',
        'package:url_launcher/',
        'startLat',
        'startLng',
        'endLat',
        'endLng',
      ]) {
        expect(
          card.source.contains(banned),
          isFalse,
          reason: 'the share card reaches for $banned',
        );
      }
      expect(card.source, contains('privateRoute('));
    });

    test('url_launcher stays the way demo links open', () {
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

    test('core library desugaring stays enabled', () {
      // flutter_local_notifications uses java.time, which does not exist
      // below API 26 while minSdk is 24. Without desugaring the RELEASE build
      // fails at :app:checkReleaseAarMetadata — and it fails there only, so
      // every test on this machine passes while no APK can be produced.
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(gradle, contains('coreLibraryDesugaring('));
    });

    test('secrets are not in the repository', () {
      expect(File('android/key.properties').existsSync(), isTrue);
      final ignore = read('../.gitignore');
      expect(ignore, contains('key.properties'));
      expect(ignore.contains('.jks') || ignore.contains('*.jks'), isTrue);
    });
  });
}
