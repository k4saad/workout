import 'dart:math' as math;
import 'dart:typed_data';

/// A short sine tone as a 16-bit mono WAV, made in code rather than
/// shipped as a file.
///
/// The ends are faded over 10 ms: a tone that starts or stops mid-wave
/// clicks, and a click on a phone speaker sounds like a fault.
Uint8List sineWav({
  required double hz,
  required int ms,
  int sampleRate = 22050,
  double volume = 0.6,
}) {
  final n = sampleRate * ms ~/ 1000;
  final fade = math.min(sampleRate ~/ 100, n ~/ 2);
  final data = ByteData(44 + n * 2);

  void ascii(int at, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // PCM header size
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, n * 2, Endian.little);

  for (var i = 0; i < n; i++) {
    final edge = math.min(i, n - 1 - i);
    final envelope = fade == 0 ? 1.0 : math.min(1.0, edge / fade);
    final v = math.sin(2 * math.pi * hz * i / sampleRate) * volume * envelope;
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}
