import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/audio/tone_generator.dart';

/// The samples the Live PCM tab plays: interleaved stereo s16le.
void main() {
  Int16List samples(Uint8List bytes) =>
      bytes.buffer.asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);

  /// The left channel of [bytes].
  List<int> left(Uint8List bytes) {
    final s = samples(bytes);
    return [for (var i = 0; i < s.length; i += 2) s[i]];
  }

  test('a chunk is the asked duration of stereo s16le', () {
    final g = ToneGenerator(sampleRate: 48000);
    final chunk = g.next(const Duration(milliseconds: 20));
    // 960 frames, 2 channels, 2 bytes.
    expect(chunk.lengthInBytes, 960 * 2 * 2);
  });

  test('a sine has its frequency and its level', () {
    final g = ToneGenerator(sampleRate: 48000)
      ..kind = ToneKind.sine
      ..frequency = 1000
      ..levelDb = -6;
    final l = left(g.next(const Duration(seconds: 1)));
    var crossings = 0;
    for (var i = 1; i < l.length; i++) {
      if (l[i - 1] < 0 && l[i] >= 0) crossings++;
    }
    expect(crossings, inInclusiveRange(999, 1001));
    final peak = l.map((v) => v.abs()).reduce(math.max) / 32767;
    expect(peak, closeTo(math.pow(10, -6 / 20), 0.01));
  });

  test('the phase carries over from chunk to chunk', () {
    final g = ToneGenerator(sampleRate: 48000)
      ..kind = ToneKind.sine
      ..frequency = 440;
    final a = left(g.next(const Duration(milliseconds: 10)));
    final b = left(g.next(const Duration(milliseconds: 10)));
    // No jump at the seam: the step is a sine step, not a restart.
    expect((b.first - a.last).abs(), lessThan(1500));
  });

  test('a sweep rises from 20 Hz to 20 kHz', () {
    final g = ToneGenerator(sampleRate: 48000)..kind = ToneKind.sweep;
    expect(g.sweepFrequencyAt(Duration.zero), closeTo(20, 0.01));
    expect(
      g.sweepFrequencyAt(ToneGenerator.sweepLength ~/ 2),
      closeTo(632.5, 1),
    );
  });

  test('pink noise stays under full scale', () {
    final g = ToneGenerator(sampleRate: 48000)
      ..kind = ToneKind.pinkNoise
      ..levelDb = 0;
    final l = left(g.next(const Duration(seconds: 1)));
    expect(l.map((v) => v.abs()).reduce(math.max), lessThanOrEqualTo(32767));
    expect(l.toSet().length, greaterThan(1000));
  });

  test('pulses are silent between bursts', () {
    final g = ToneGenerator(sampleRate: 48000)..kind = ToneKind.pulses;
    final l = left(g.next(const Duration(seconds: 1)));
    final quiet = l.where((v) => v == 0).length;
    expect(quiet, greaterThan(l.length ~/ 2));
  });
}
