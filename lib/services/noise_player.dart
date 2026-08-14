import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum NoiseType { off, white, pink, brown }

class NoisePlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(NoiseType type) async {
    if (type == NoiseType.off) {
      await stop();
      return;
    }

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(BytesSource(_createWav(type)), volume: 0.22);
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();

  Uint8List _createWav(NoiseType type) {
    const sampleRate = 44100;
    const seconds = 12;
    final sampleCount = sampleRate * seconds;
    final bytes = Uint8List(44 + sampleCount * 2);
    final data = ByteData.view(bytes.buffer);
    final random = Random(7);
    var brownValue = 0.0;
    var pinkB0 = 0.0;
    var pinkB1 = 0.0;
    var pinkB2 = 0.0;

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes[offset + index] = value.codeUnitAt(index);
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + sampleCount * 2, Endian.little);
    writeAscii(8, 'WAVEfmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, sampleCount * 2, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      final white = random.nextDouble() * 2 - 1;
      double sample;
      switch (type) {
        case NoiseType.white:
          sample = white;
          break;
        case NoiseType.pink:
          pinkB0 = 0.99886 * pinkB0 + white * 0.0555179;
          pinkB1 = 0.99332 * pinkB1 + white * 0.0750759;
          pinkB2 = 0.96900 * pinkB2 + white * 0.1538520;
          sample = (pinkB0 + pinkB1 + pinkB2 + white * 0.5362) * 0.12;
          break;
        case NoiseType.brown:
          brownValue = (brownValue + white * 0.02).clamp(-1.0, 1.0);
          sample = brownValue * 2.5;
          break;
        case NoiseType.off:
          sample = 0;
          break;
      }
      data.setInt16(44 + index * 2, (sample.clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return bytes;
  }
}