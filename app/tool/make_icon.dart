// Generates the launcher icon from code.
//
//   dart run tool/make_icon.dart
//
// Drawn rather than drawn-on: no new dependency (the `image` package is
// already here for photo resizing), and the mark is reproducible — change a
// number, re-run, every density regenerates in step.
//
// The mark: a loaded barbell, straight on. Crimson bar and plates on
// near-black, which is the app's whole palette and reads at launcher size
// where anything more detailed turns to mud.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const bg = 0xFF0A0A0C; // near-black, matching AppTheme.bg
const crimson = 0xFFD81E3F; // AppTheme.crimson
const crimsonDim = 0xFF8E1428; // the outer plates, a shade back

/// ARGB -> the image package's colour order.
img.ColorRgba8 rgba(int argb) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);

/// Draws the barbell into a square canvas of side [size].
///
/// Everything is a fraction of [size], so one routine serves every density
/// from 48 px to 432 px without a second set of numbers to keep in sync.
img.Image drawMark(int size, {bool transparentBackground = false}) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  img.fill(im, color: transparentBackground
      ? img.ColorRgba8(0, 0, 0, 0)
      : rgba(bg));

  final c = size / 2;
  final bar = rgba(crimson);
  final outer = rgba(crimsonDim);

  // The bar: a horizontal rounded shaft across the middle.
  final barHalfLen = size * 0.40;
  final barHalfThick = math.max(1, size * 0.030);
  img.fillRect(
    im,
    x1: (c - barHalfLen).round(),
    y1: (c - barHalfThick).round(),
    x2: (c + barHalfLen).round(),
    y2: (c + barHalfThick).round(),
    color: bar,
    radius: barHalfThick,
  );

  // Two plates each side: inner tall, outer shorter. Sleeve order reads as
  // depth without any shading.
  void plate(double offset, double halfWidth, double halfHeight, img.Color col) {
    for (final dir in [-1, 1]) {
      final x = c + dir * offset;
      img.fillRect(
        im,
        x1: (x - halfWidth).round(),
        y1: (c - halfHeight).round(),
        x2: (x + halfWidth).round(),
        y2: (c + halfHeight).round(),
        color: col,
        radius: math.max(1, size * 0.02),
      );
    }
  }

  plate(size * 0.205, size * 0.052, size * 0.255, bar); // inner
  plate(size * 0.325, size * 0.044, size * 0.170, outer); // outer

  return im;
}

Future<void> write(String path, img.Image im) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(img.encodePng(im));
  stdout.writeln('  ${im.width}x${im.height}  $path');
}

Future<void> main() async {
  const res = 'android/app/src/main/res';

  // Legacy square icon, one per density.
  const legacy = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  stdout.writeln('launcher icons:');
  for (final e in legacy.entries) {
    await write('$res/${e.key}/ic_launcher.png', drawMark(e.value));
  }

  // Adaptive icon foreground. Android crops the outer ~28% and animates the
  // rest, so the mark is drawn into the middle 60% of a transparent canvas or
  // the plates get shaved off on a round-masked launcher.
  const adaptive = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };
  stdout.writeln('adaptive foregrounds:');
  for (final e in adaptive.entries) {
    final full = e.value;
    final inner = (full * 0.62).round();
    final canvas = img.Image(width: full, height: full, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(
      canvas,
      drawMark(inner, transparentBackground: true),
      dstX: ((full - inner) / 2).round(),
      dstY: ((full - inner) / 2).round(),
    );
    await write('$res/${e.key}/ic_launcher_foreground.png', canvas);
  }

  stdout.writeln('done');
}
