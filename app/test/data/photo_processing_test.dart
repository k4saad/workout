import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:keller_twelve/data/photo_processing.dart';

/// What happens to a photo between the shutter and the disk.
void main() {
  /// A landscape frame as the sensor writes it, with a red block in the
  /// top-left so a rotation shows.
  Uint8List shot({int w = 400, int h = 300, int orientation = 1}) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(90, 90, 90));
    img.fillRect(
      im,
      x1: 0,
      y1: 0,
      x2: 40,
      y2: 40,
      color: img.ColorRgb8(255, 0, 0),
    );
    im.exif.imageIfd.orientation = orientation;
    return img.encodeJpg(im);
  }

  test('a sideways sensor frame comes out upright', () {
    final out = PhotoProcessing.process(
      shot(orientation: 6),
      longEdge: 200,
      thumbEdge: 100,
    );
    expect((out.width, out.height), (150, 200));
    final back = img.decodeJpg(out.bytes)!;
    expect((back.width, back.height), (150, 200));
  });

  test('nothing is left for a viewer to rotate a second time', () {
    final out = PhotoProcessing.process(shot(orientation: 6), longEdge: 200);
    final back = img.decodeJpg(out.bytes)!;
    expect(back.exif.imageIfd.orientation ?? 1, 1);
    expect(back.exif.gpsIfd.isEmpty, isTrue, reason: 'no location, ever');
  });

  test('a small photo is never enlarged', () {
    final out = PhotoProcessing.process(shot(), longEdge: 1920);
    expect((out.width, out.height), (400, 300));
  });

  test('a thumbnail comes with it, long edge as asked', () {
    final out = PhotoProcessing.process(
      shot(orientation: 6),
      longEdge: 200,
      thumbEdge: 100,
    );
    final thumb = img.decodeJpg(out.thumb)!;
    expect((thumb.width, thumb.height), (75, 100));
    expect(out.thumb.length, lessThan(out.bytes.length));
  });

  test('garbage is refused rather than saved as a photo', () {
    expect(
      () => PhotoProcessing.process(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
  });

  test('runs off the UI thread', () async {
    final raw = shot(orientation: 6);
    final out = await Isolate.run(
      () => PhotoProcessing.process(raw, longEdge: 200),
    );
    expect((out.width, out.height), (150, 200));
  });
}
