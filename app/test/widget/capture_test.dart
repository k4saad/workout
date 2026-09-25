import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:keller_twelve/app/progress_providers.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/capture_camera.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/media_repository.dart';
import 'package:keller_twelve/data/photo_processing.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/features/progress/capture_screen.dart';

/// The shoot, with a stand-in camera: the plugin cannot run in a test, and
/// what matters here is what reaches the database and the disk.
void main() {
  late Directory tmp;
  late AppDatabase db;
  late _Camera camera;
  late _Cue cue;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kt_capture_');
    db = AppDatabase.memory();
    camera = _Camera();
    cue = _Cue();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  /// Lets real file writes finish between frames.
  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaRepositoryProvider.overrideWith((ref) async {
            final media = MediaRepository(db: db, documentsDir: tmp);
            await media.ensurePosesSeeded();
            return media;
          }),
          preferencesServiceProvider.overrideWithValue(
            PreferencesService(documentsDir: tmp),
          ),
          captureCameraProvider.overrideWithValue(() => camera),
          captureCueProvider.overrideWithValue(() => cue),
          photoProcessorProvider.overrideWithValue(
            (raw) async =>
                PhotoProcessing.process(raw, longEdge: 160, thumbEdge: 40),
          ),
          todayProvider.overrideWith(() => _Today(DateTime(2026, 10, 19))),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CaptureScreen(weekNo: 4),
                    ),
                  ),
                  child: const Text('camera'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('camera'));
    await settle(tester);
    if (find.text('The camera did not open').evaluate().isNotEmpty) {
      final texts = tester.widgetList<Text>(find.byType(Text));
      fail('boot failed: ${texts.map((t) => t.data).join(' | ')}');
    }
  }

  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.text('3 s'));
    await settle(tester, 2);
    await tester.tap(find.textContaining('Start the'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);
  }

  Future<List<PhotoShoot>> shoots(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.photoShoots).get()))!;

  testWidgets('nothing is written until a photo is kept', (tester) async {
    await open(tester);
    await shoot(tester);
    expect(find.text('Keep this one?'), findsOneWidget);
    expect(await shoots(tester), isEmpty);

    await tester.tap(find.text('Retake'));
    await settle(tester, 2);
    expect(find.textContaining('Start the'), findsOneWidget);
    expect(await shoots(tester), isEmpty, reason: 'a retake adds nothing');
  });

  testWidgets('a full pass is one shoot of four, each with a thumbnail', (
    tester,
  ) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await shoot(tester);
      await tester.tap(find.text('Keep'));
      await settle(tester);
    }
    await settle(tester);
    expect(find.byType(CaptureScreen), findsNothing, reason: 'done, and back');
    expect(find.text('Shoot saved: all 4 poses.'), findsOneWidget);

    final all = await shoots(tester);
    expect(all, hasLength(1));
    expect(all.single.weekNo, 4);
    final photos = (await tester.runAsync(
      () => db.photosForShoot(all.single.id),
    ))!;
    expect(photos, hasLength(4));
    expect({for (final p in photos) p.poseId}, hasLength(4));
    for (final p in photos) {
      expect(p.height, greaterThan(p.width), reason: 'upright');
      final thumb = File(
        '${tmp.path}/thumbs/${p.relativePath.replaceAll('/', '_')}',
      );
      expect(thumb.existsSync(), isTrue, reason: p.poseId);
    }
  });

  testWidgets('the timer pips every second and clicks at zero', (tester) async {
    await open(tester);
    await shoot(tester);
    expect(cue.ticks, [3, 2, 1]);
    expect(cue.shutters, 1);
  });

  testWidgets('backing out with nothing kept leaves no shoot', (tester) async {
    await open(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(CaptureScreen), findsNothing);
    expect(find.text('Stop the shoot?'), findsNothing);
    expect(await shoots(tester), isEmpty);
  });

  testWidgets('a skipped pose is left out, and the rest still save', (
    tester,
  ) async {
    await open(tester);
    await shoot(tester);
    await tester.tap(find.text('Keep'));
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Skip'));
      await settle(tester);
    }
    final all = await shoots(tester);
    expect(all, hasLength(1));
    final photos = (await tester.runAsync(
      () => db.photosForShoot(all.single.id),
    ))!;
    expect(photos, hasLength(1));
  });
}

class _Camera implements CaptureCamera {
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  Future<void> open({required bool front}) async => _open = true;

  @override
  double get portraitAspect => 9 / 16;

  @override
  Widget preview() => const ColoredBox(color: Color(0xFF333333));

  /// A landscape frame that says "turn me", as a phone sensor writes it.
  @override
  Future<Uint8List> takePicture() async {
    final im = img.Image(width: 320, height: 180);
    img.fill(im, color: img.ColorRgb8(80, 80, 80));
    im.exif.imageIfd.orientation = 6;
    return img.encodeJpg(im);
  }

  @override
  Future<void> dispose() async => _open = false;
}

class _Cue implements CaptureCue {
  final ticks = <int>[];
  var shutters = 0;

  @override
  Future<void> tick(int secondsLeft) async => ticks.add(secondsLeft);

  @override
  Future<void> shutter() async => shutters++;

  @override
  Future<void> dispose() async {}
}

class _Today extends TodayNotifier {
  _Today(this.d);
  final DateTime d;
  @override
  DateTime build() => d;
}
