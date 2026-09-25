import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A photo ready for the disk: upright, sized, stripped, with a thumbnail.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
    required this.thumb,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final Uint8List thumb;
}

/// Between the shutter and the disk.
///
/// Pure and synchronous, so the capture screen can hand it to
/// `Isolate.run`: decoding and re-encoding a 12-megapixel frame takes long
/// enough on a phone to freeze the countdown on the UI thread.
abstract final class PhotoProcessing {
  /// A 1920 px long edge at q85 is 400–600 KB: a year of weekly shoots fits
  /// the storage budget, and it is still sharper than the screen.
  static const longEdge = 1920;

  /// Big enough for a timeline row and a grid at three across.
  static const thumbEdge = 480;

  static ProcessedPhoto process(
    Uint8List raw, {
    int longEdge = PhotoProcessing.longEdge,
    int thumbEdge = PhotoProcessing.thumbEdge,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(raw);
    } on Object {
      decoded = null;
    }
    if (decoded == null) {
      throw const FormatException(
        'The camera returned something that is '
        'not a photo.',
      );
    }

    // The sensor writes landscape and a tag saying "turn me". Turn it now,
    // once, and drop every tag: a viewer that honours the tag as well would
    // turn it twice, and a location tag has no business in these files.
    final upright = img.bakeOrientation(decoded)..exif = img.ExifData();
    final full = _fit(upright, longEdge);
    final thumb = _fit(full, thumbEdge);
    return ProcessedPhoto(
      bytes: img.encodeJpg(full, quality: 85),
      width: full.width,
      height: full.height,
      thumb: img.encodeJpg(thumb, quality: 75),
    );
  }

  /// Shrinks to [edge] on the long side. Never enlarges.
  static img.Image _fit(img.Image im, int edge) {
    if (math.max(im.width, im.height) <= edge) return im;
    return im.width >= im.height
        ? img.copyResize(
            im,
            width: edge,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            im,
            height: edge,
            interpolation: img.Interpolation.average,
          );
  }
}
