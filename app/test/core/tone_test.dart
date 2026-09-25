import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/audio/tone.dart';

/// The self-timer's pips, made in code: no sound file to bundle.
void main() {
  String ascii(Uint8List b, int at) =>
      String.fromCharCodes(b.sublist(at, at + 4));

  test('is a valid 16-bit mono WAV of the asked length', () {
    final wav = sineWav(hz: 880, ms: 100, sampleRate: 20000);
    final h = ByteData.sublistView(wav);
    expect(ascii(wav, 0), 'RIFF');
    expect(ascii(wav, 8), 'WAVE');
    expect(ascii(wav, 12), 'fmt ');
    expect(h.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(h.getUint32(24, Endian.little), 20000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(ascii(wav, 36), 'data');
    expect(h.getUint32(40, Endian.little), 2000 * 2, reason: '0.1 s');
    expect(h.getUint32(4, Endian.little), wav.length - 8);
  });

  test('fades in and out, so it does not click', () {
    final wav = sineWav(hz: 880, ms: 100, sampleRate: 20000);
    final h = ByteData.sublistView(wav);
    int sample(int i) => h.getInt16(44 + i * 2, Endian.little);
    expect(sample(0), 0);
    expect(sample(1999).abs(), lessThan(200));
    final loudest = [for (var i = 0; i < 2000; i++) sample(i).abs()]
        .reduce((a, b) => a > b ? a : b);
    expect(loudest, greaterThan(8000));
    expect(loudest, lessThanOrEqualTo(32767));
  });
}
