import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/audio/tone.dart';

/// The camera, as the capture screen needs it.
///
/// An interface so the capture flow — keep, retake, skip, leave — can be
/// tested with a fake: the plugin cannot run in a widget test.
abstract class CaptureCamera {
  /// Opens the front or back lens. Throws when there is no camera or no
  /// permission; the screen says so.
  Future<void> open({required bool front});

  bool get isOpen;

  /// Width over height of the portrait preview. The ghost, the preview and
  /// the review are all drawn in one box of this shape, so they line up.
  double get portraitAspect;

  Widget preview();

  /// Takes a picture and returns its bytes. The plugin's temporary file is
  /// deleted: it is not app-private.
  Future<Uint8List> takePicture();

  Future<void> dispose();
}

/// The real camera, through the `camera` plugin.
class PluginCaptureCamera implements CaptureCamera {
  CameraController? _controller;

  @override
  bool get isOpen => _controller?.value.isInitialized ?? false;

  @override
  Future<void> open({required bool front}) async {
    await _controller?.dispose();
    _controller = null;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera on this phone.');
    final want = front ? CameraLensDirection.front : CameraLensDirection.back;
    final lens = cameras.firstWhere(
      (c) => c.lensDirection == want,
      orElse: () => cameras.first,
    );
    // 1080p: the picture comes out 1080 x 1920 upright, the size the photos
    // are stored at, and the preview runs at the same 16:9, so the ghost
    // drawn over it lines up.
    final controller = CameraController(
      lens,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
  }

  @override
  double get portraitAspect {
    final size = _controller?.value.previewSize;
    if (size == null || size.width == 0 || size.height == 0) return 9 / 16;
    // The plugin reports the sensor's landscape size.
    final long = size.longestSide, short = size.shortestSide;
    return short / long;
  }

  @override
  Widget preview() => CameraPreview(_controller!);

  @override
  Future<Uint8List> takePicture() async {
    final shot = await _controller!.takePicture();
    final file = File(shot.path);
    try {
      return await file.readAsBytes();
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

/// What the self-timer sounds and feels like.
abstract class CaptureCue {
  /// One second gone.
  Future<void> tick(int secondsLeft);

  /// The picture is being taken.
  Future<void> shutter();

  Future<void> dispose();
}

/// Pips through the speaker, a buzz in the hand. The phone is propped on
/// a bench two metres away, so the sound is the part that reaches him.
class AudioCaptureCue implements CaptureCue {
  final _player = AudioPlayer();
  late final _pip = sineWav(hz: 880, ms: 90);
  late final _last = sineWav(hz: 1175, ms: 90);
  late final _click = sineWav(hz: 1568, ms: 160);

  Future<void> _play(Uint8List wav) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
    } on Object {
      // A phone with no audio output still takes the picture.
    }
  }

  @override
  Future<void> tick(int secondsLeft) async {
    await HapticFeedback.selectionClick();
    await _play(secondsLeft <= 3 ? _last : _pip);
  }

  @override
  Future<void> shutter() async {
    await HapticFeedback.heavyImpact();
    await _play(_click);
  }

  @override
  Future<void> dispose() => _player.dispose();
}
