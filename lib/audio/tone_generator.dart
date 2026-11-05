import 'dart:math' as math;
import 'dart:typed_data';

/// What a [ToneGenerator] plays.
enum ToneKind {
  /// A pure tone at [ToneGenerator.frequency].
  sine('Sine'),

  /// A tone gliding from 20 Hz to 20 kHz on a log scale, then again.
  sweep('Sweep'),

  /// Noise with equal energy per octave, the ear's flat.
  pinkNoise('Pink noise'),

  /// Short bursts of the tone, a quarter of a second apart.
  pulses('Pulses');

  final String label;
  const ToneKind(this.label);
}

/// Test signals made in Dart, chunk by chunk, as interleaved stereo
/// 16-bit little-endian samples: what the Live PCM tab feeds a
/// `PcmSource`. [kind], [frequency] and [levelDb] change between chunks
/// without a click: the phase carries over.
class ToneGenerator {
  ToneGenerator({this.sampleRate = 48000, int seed = 1})
    : _random = math.Random(seed);

  final int sampleRate;

  /// The channels of every chunk.
  static const int channels = 2;

  /// How long a [ToneKind.sweep] takes from 20 Hz to 20 kHz.
  static const Duration sweepLength = Duration(seconds: 10);

  /// The bottom and the top of a sweep, in Hz.
  static const double sweepLow = 20;
  static const double sweepHigh = 20000;

  ToneKind kind = ToneKind.sine;

  /// The tone's frequency, for [ToneKind.sine] and [ToneKind.pulses].
  double frequency = 440;

  /// The peak level, in dBFS.
  double levelDb = -12;

  final math.Random _random;
  double _phase = 0;
  int _frame = 0;

  // Paul Kellet's pink filter state.
  double _b0 = 0, _b1 = 0, _b2 = 0, _b3 = 0, _b4 = 0, _b5 = 0, _b6 = 0;

  /// The frequency a sweep plays [at] into its cycle.
  double sweepFrequencyAt(Duration at) {
    final cycle = sweepLength.inMicroseconds;
    final t = (at.inMicroseconds % cycle) / cycle;
    return sweepLow * math.pow(sweepHigh / sweepLow, t);
  }

  /// The next [length] of audio.
  Uint8List next(Duration length) {
    final frames = (length.inMicroseconds * sampleRate / 1e6).round();
    final out = Int16List(frames * channels);
    final gain = math.pow(10, levelDb / 20).toDouble();
    for (var i = 0; i < frames; i++) {
      final v = (_sample() * gain).clamp(-1.0, 1.0);
      final s = (v * 32767).round();
      out[i * 2] = s;
      out[i * 2 + 1] = s;
      _frame++;
    }
    return out.buffer.asUint8List();
  }

  double _sample() {
    switch (kind) {
      case ToneKind.sine:
        return _tone(frequency);
      case ToneKind.sweep:
        final at = Duration(microseconds: (_frame * 1e6 / sampleRate).round());
        return _tone(sweepFrequencyAt(at));
      case ToneKind.pinkNoise:
        return _pink();
      case ToneKind.pulses:
        // 50 ms of tone every 250 ms, with 5 ms fades against clicks.
        final period = sampleRate ~/ 4;
        final burst = sampleRate ~/ 20;
        final fade = sampleRate ~/ 200;
        final at = _frame % period;
        final tone = _tone(frequency);
        if (at >= burst) return 0;
        final edge = math.min(at, burst - at);
        return edge < fade ? tone * edge / fade : tone;
    }
  }

  /// One step of a sine at [hz], the phase carried across calls.
  double _tone(double hz) {
    final v = math.sin(_phase);
    _phase += 2 * math.pi * hz / sampleRate;
    if (_phase > 2 * math.pi) _phase -= 2 * math.pi;
    return v;
  }

  double _pink() {
    final white = _random.nextDouble() * 2 - 1;
    _b0 = 0.99886 * _b0 + white * 0.0555179;
    _b1 = 0.99332 * _b1 + white * 0.0750759;
    _b2 = 0.96900 * _b2 + white * 0.1538520;
    _b3 = 0.86650 * _b3 + white * 0.3104856;
    _b4 = 0.55000 * _b4 + white * 0.5329522;
    _b5 = -0.7616 * _b5 - white * 0.0168980;
    final pink = _b0 + _b1 + _b2 + _b3 + _b4 + _b5 + _b6 + white * 0.5362;
    _b6 = white * 0.115926;
    // The filter's peak sits near 5x white: scale back under full scale.
    return pink * 0.2;
  }
}
