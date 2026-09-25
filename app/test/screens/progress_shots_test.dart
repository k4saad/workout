import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:keller_twelve/app/progress_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/data/capture_camera.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/media_repository.dart';
import 'package:keller_twelve/data/photo_processing.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/screenshot.dart';

/// Photos, the tape and the checkpoints, rendered: `build/screens/p6_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/progress_shots_test.dart
///
/// The "photos" are drawn figures — there are no real ones to use, and
/// there never will be in a test.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

/// A stand-in progress photo: a lit figure against the basement wall,
/// broader at the shoulders by [build] (0..1).
Uint8List figure({required double build, int pose = 0, int w = 540}) {
  final h = w * 16 ~/ 9;
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final v = 38 + (y * 22 ~/ h);
    img.drawLine(
      im,
      x1: 0,
      y1: y,
      x2: w - 1,
      y2: y,
      color: img.ColorRgb8(v, v, v + 4),
    );
  }
  final cx = w ~/ 2;
  final skin = img.ColorRgb8(176, 132, 108);
  final shorts = img.ColorRgb8(30, 30, 36);
  final side = pose == 2;
  final shoulder = ((side ? 0.13 : 0.2) + build * 0.03) * w;
  final waist = (side ? 0.1 : 0.13) * w;
  // Head, neck, torso as a trapezium, arms, shorts, legs.
  img.fillCircle(
    im,
    x: cx,
    y: (h * 0.14).round(),
    radius: (w * 0.07).round(),
    color: skin,
  );
  img.fillRect(
    im,
    x1: cx - (w * 0.03).round(),
    y1: (h * 0.18).round(),
    x2: cx + (w * 0.03).round(),
    y2: (h * 0.22).round(),
    color: skin,
  );
  final top = (h * 0.22).round(), hip = (h * 0.5).round();
  for (var y = top; y < hip; y++) {
    final f = (y - top) / (hip - top);
    final half = (shoulder * (1 - f) + waist * f).round();
    img.drawLine(im, x1: cx - half, y1: y, x2: cx + half, y2: y, color: skin);
  }
  if (!side) {
    for (final s in [-1, 1]) {
      final x = cx + s * (shoulder + w * 0.035).round();
      img.fillRect(
        im,
        x1: x - (w * 0.03).round(),
        y1: top + 6,
        x2: x + (w * 0.03).round(),
        y2: (h * 0.52).round(),
        color: skin,
      );
    }
  }
  img.fillRect(
    im,
    x1: cx - (waist + 4).round(),
    y1: hip,
    x2: cx + (waist + 4).round(),
    y2: (h * 0.62).round(),
    color: shorts,
  );
  for (final s in side ? [0] : [-1, 1]) {
    final x = cx + s * (waist * 0.5).round();
    img.fillRect(
      im,
      x1: x - (w * 0.045).round(),
      y1: (h * 0.62).round(),
      x2: x + (w * 0.045).round(),
      y2: (h * 0.93).round(),
      color: skin,
    );
  }
  if (pose == 3) {
    // The back: a darker spine line.
    img.drawLine(
      im,
      x1: cx,
      y1: top,
      x2: cx,
      y2: hip,
      color: img.ColorRgb8(140, 100, 82),
      thickness: 3,
    );
  }
  return img.encodeJpg(im, quality: 88);
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late MediaRepository media;

  // Thursday of week 4: the checkpoint week.
  final today = DateTime(2026, 10, 22);

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_p6_shots_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    media = MediaRepository(db: db, documentsDir: tmp);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  Future<void> seed() async {
    await repo.ensureSeeded();
    await Screenshot.seedHistory(db, repo: repo, today: today);
    await media.ensurePosesSeeded();
    final poses = await db.enabledPoses();
    for (final (date, week, build) in [
      (DateTime(2026, 9, 27), 1, 0.0),
      (DateTime(2026, 10, 19), 4, 0.6),
    ]) {
      final shoot = await media.startShoot(date, weekNo: week);
      for (final (i, pose) in poses.indexed) {
        final p = PhotoProcessing.process(figure(build: build, pose: i));
        await media.savePhoto(
          shootId: shoot.id,
          poseId: pose.id,
          bytes: p.bytes,
          thumb: p.thumb,
          width: p.width,
          height: p.height,
          takenAt: date.add(Duration(minutes: i)),
        );
      }
    }
    const sites = {
      MeasurementSite.waist: (68.0, 68.6),
      MeasurementSite.chest: (82.0, 83.4),
      MeasurementSite.upperArm: (25.0, 25.9),
      MeasurementSite.thigh: (48.0, 48.8),
      MeasurementSite.neck: (33.0, 33.3),
    };
    for (final MapEntry(key: site, value: (a, b)) in sites.entries) {
      await db.upsertMeasurement(DateTime(2026, 9, 27), site, a);
      await db.upsertMeasurement(DateTime(2026, 10, 19), site, b);
    }
  }

  List<Override> overrides() => [
    Screenshot.pinToday(today),
    mediaRepositoryProvider.overrideWith((ref) async {
      await media.ensurePosesSeeded();
      return media;
    }),
    preferencesServiceProvider.overrideWithValue(
      PreferencesService(documentsDir: tmp),
    ),
  ];

  testWidgets(
    'photos: timeline, compare, time-lapse, one shoot',
    skip: !_enabled,
    (tester) async {
      await tester.runAsync(seed);
      Screenshot.phone(tester, height: 1500);
      final router = await Screenshot.pumpApp(
        tester,
        db: db,
        repo: repo,
        location: '/progress/photos',
        overrides: overrides(),
      );
      await Screenshot.settle(tester, rounds: 30);
      await Screenshot.capture(tester, 'p6_timeline');

      await tester.tap(find.text('Compare'));
      await Screenshot.settle(tester, rounds: 30);
      await Screenshot.capture(tester, 'p6_compare');

      await tester.tap(find.text('Time-lapse'));
      await Screenshot.settle(tester, rounds: 30);
      await Screenshot.capture(tester, 'p6_timelapse');

      final shoots = (await tester.runAsync(db.shoots))!;
      router.go('/progress/photos/${shoots.first.id}');
      await Screenshot.settle(tester, rounds: 30);
      await Screenshot.capture(tester, 'p6_viewer');
    },
  );

  testWidgets('body: the scale and the tape', skip: !_enabled, (tester) async {
    await tester.runAsync(seed);
    Screenshot.phone(tester, height: 1700);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/progress/body',
      overrides: overrides(),
    );
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p6_body');

    Screenshot.phone(tester);
    await Screenshot.settle(tester);
    await tester.tap(find.text('Waist'));
    await Screenshot.settle(tester, rounds: 20);
    await Screenshot.capture(tester, 'p6_tape_sheet');
  });

  testWidgets('the checkpoint ticks itself', skip: !_enabled, (tester) async {
    await tester.runAsync(seed);
    Screenshot.phone(tester, height: 1700);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      location: '/week',
      overrides: overrides(),
    );
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p6_week_checkpoint');
  });

  testWidgets('the capture screen', skip: !_enabled, (tester) async {
    await tester.runAsync(seed);
    Screenshot.phone(tester);
    final live = PhotoProcessing.process(figure(build: 0.7), longEdge: 1080);
    final camera = _Camera(live.bytes);
    final router = await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: [
        ...overrides(),
        captureCameraProvider.overrideWithValue(() => camera),
        captureCueProvider.overrideWithValue(_SilentCue.new),
        photoProcessorProvider.overrideWithValue(
          (raw) async => PhotoProcessing.process(raw),
        ),
      ],
    );
    router.push('/capture?week=4');
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p6_capture_framing');

    await tester.tap(find.text('3 s'));
    await Screenshot.settle(tester);
    await tester.tap(find.textContaining('Start the'));
    await tester.pump(const Duration(seconds: 1));
    await Screenshot.settle(tester, rounds: 4);
    await Screenshot.capture(tester, 'p6_capture_countdown');
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p6_capture_review');
  });
}

class _Camera implements CaptureCamera {
  _Camera(this.frame);

  final Uint8List frame;

  @override
  bool get isOpen => true;

  @override
  Future<void> open({required bool front}) async {}

  @override
  double get portraitAspect => 9 / 16;

  /// The "live" preview: a still, standing a touch off where last time was.
  @override
  Widget preview() => Transform.translate(
    offset: const Offset(9, 4),
    child: Transform.rotate(
      angle: -1.5 * math.pi / 180,
      child: Image.memory(frame, fit: BoxFit.cover),
    ),
  );

  @override
  Future<Uint8List> takePicture() async => frame;

  @override
  Future<void> dispose() async {}
}

class _SilentCue implements CaptureCue {
  @override
  Future<void> tick(int secondsLeft) async {}

  @override
  Future<void> shutter() async {}

  @override
  Future<void> dispose() async {}
}
