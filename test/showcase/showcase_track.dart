import 'dart:math' as math;
import 'dart:typed_data';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// A made-up song for the showcase scenes: its loudness over time, beat
/// by beat, from which the waveform, the spectrum and the level meter all
/// follow, so the three agree. Everything is a pure function of the
/// position in the song: the same position always looks the same.
class ShowcaseSong {
  const ShowcaseSong();

  static const String title = 'Harbour Lights';
  static const String artist = 'Juniper Avenue';
  static const String album = 'Night Ferry';

  static const Duration length = Duration(minutes: 4, seconds: 52);

  /// Beats per minute, and so the seconds of one beat.
  static const double bpm = 112;
  static const double beat = 60 / bpm;

  static const List<Chapter> chapters = [
    Chapter(time: Duration.zero, title: 'Intro'),
    Chapter(time: Duration(seconds: 44), title: 'Verse'),
    Chapter(time: Duration(minutes: 1, seconds: 36), title: 'Chorus'),
    Chapter(time: Duration(minutes: 2, seconds: 48), title: 'Bridge'),
    Chapter(time: Duration(minutes: 3, seconds: 18), title: 'Final chorus'),
    Chapter(time: Duration(minutes: 4, seconds: 20), title: 'Outro'),
  ];

  /// The song's energy (0 to 1) at [t] seconds: the sections, eased into
  /// each other over a couple of seconds.
  static double energy(double t) {
    const marks = <(double, double)>[
      (0, 0.10),
      (6, 0.32),
      (40, 0.45),
      (46, 0.60),
      (92, 0.66),
      (98, 0.86),
      (164, 0.90),
      (170, 0.46),
      (196, 0.55),
      (199, 0.95),
      (258, 0.92),
      (266, 0.50),
      (285, 0.18),
      (292, 0.02),
    ];
    if (t <= marks.first.$1) return marks.first.$2;
    for (var i = 1; i < marks.length; i++) {
      final (t1, e1) = marks[i];
      if (t <= t1) {
        final (t0, e0) = marks[i - 1];
        final x = (t - t0) / (t1 - t0);
        return e0 + (e1 - e0) * x * x * (3 - 2 * x);
      }
    }
    return marks.last.$2;
  }

  /// A hit's envelope [since] seconds after it: a quick rise and a decay
  /// of [decay] seconds.
  static double _hit(double since, double decay) {
    if (since < 0) return 0;
    const attack = 0.03;
    if (since < attack) return since / attack;
    return math.exp(-(since - attack) / decay);
  }

  /// The kick on every beat, the snare on two and four, the hats on the
  /// eighths: their envelopes at [t].
  static ({double kick, double snare, double hats}) drums(double t) {
    final b = t / beat;
    final inBeat = (b - b.floorToDouble()) * beat;
    final kick = _hit(inBeat, 0.11);
    final snare = b.floor().isOdd ? _hit(inBeat, 0.16) : 0.0;
    final half = beat / 2;
    final hats = _hit(inBeat % half, 0.05);
    // Quiet parts keep fewer drums.
    final e = energy(t);
    final drive = ((e - 0.25) / 0.5).clamp(0.0, 1.0);
    return (kick: kick * drive, snare: snare * drive, hats: hats * drive);
  }

  /// The waveform the engine would hand over: [bins] min, max and RMS
  /// points over the song, or over a track of [duration] that follows
  /// the same shape, stretched.
  static WaveformData waveform({int bins = 2920, Duration? duration}) {
    final min = Float32List(bins);
    final max = Float32List(bins);
    final rms = Float32List(bins);
    final secs = length.inMicroseconds / 1e6;
    for (var i = 0; i < bins; i++) {
      final t = (i + 0.5) * secs / bins;
      final e = energy(t);
      final d = drums(t);
      final grain = 0.9 + 0.1 * sceneNoise(t * 4.0, 3);
      final peak = (e * (0.7 + 0.16 * d.kick + 0.05 * d.snare) * grain)
          .clamp(0.015, 0.97)
          .toDouble();
      max[i] = peak;
      min[i] = -peak * 0.93;
      rms[i] = peak * 0.45;
    }
    return WaveformData(
      duration: duration ?? length,
      min: min,
      max: max,
      rms: rms,
      filled: Uint8List.fromList(List.filled(bins, 1)),
    );
  }

  /// The spectrum at [t] seconds, in [n] perceptual bands from 20 Hz to
  /// 20 kHz: a falling tilt scaled by the energy, with peaks and dips
  /// that drift slowly, a soft kick in the lows, the snare in the mids
  /// and the hats on top. The motion stays gentle, as an analyser's
  /// smoothing shows it (and a GIF stays small).
  static FftFrame spectrum(double t, {int n = 64}) {
    final e = energy(t);
    final d = drums(t);
    final bands = Float32List(n);
    for (var i = 0; i < n; i++) {
      final x = i / (n - 1);
      final tilt = 0.94 - 0.6 * math.pow(x, 0.85);
      final body = (0.28 + 0.6 * e) * tilt;
      final shape =
          0.13 * (sceneNoise(i * 0.13 + t * 0.22, 23) - 0.5) +
          0.05 * (sceneNoise(i * 0.31 - t * 0.12, 17) - 0.5);
      final kick = 0.09 * d.kick * math.exp(-math.pow(x / 0.14, 2));
      final snare = 0.05 * d.snare * math.exp(-math.pow((x - 0.46) / 0.2, 2));
      final hats = 0.035 * d.hats * _smoothstep(0.62, 0.86, x);
      bands[i] = (body + shape * (0.5 + e) + kick + snare + hats)
          .clamp(0.0, 0.96)
          .toDouble();
    }
    return FftFrame(
      bins: Float32List(0),
      bands: bands,
      timestamp: Duration(microseconds: (t * 1e6).round()),
      sampleRate: 48000,
      bandLowHz: 20,
      bandHighHz: 20000,
    );
  }

  /// The output peaks at [t] (left and right, 0 to 1) as one tiny PCM
  /// frame, enough for the level meter's peak follower.
  static PcmFrame levels(double t) {
    final e = energy(t);
    final d = drums(t);
    final db = -29 + 18 * e + 3 * d.kick + 1.5 * d.snare;
    final left = math.pow(10, db / 20).toDouble();
    final right = left * (0.9 + 0.08 * sceneNoise(t * 2.2, 29));
    return PcmFrame(
      samples: Float32List.fromList([left, right]),
      timestamp: Duration(microseconds: (t * 1e6).round()),
      sampleRate: 48000,
      channels: 2,
    );
  }

  /// [n] stereo samples of the song from [t] seconds, interleaved, at
  /// [rate] Hz: a kick and a bass line, a pad chord, the snare and the
  /// hats on noise, all scaled by the energy. Plain synthesis, but with
  /// a spectrum and a stereo image that look like music on the meters.
  /// [brightness] tilts it (below 1 darker, above brighter) and [gain]
  /// scales it, for the "after" side of a stage.
  static Float32List block(
    double t,
    int n, {
    int rate = 48000,
    double gain = 1,
    double brightness = 1,
  }) {
    final out = Float32List(n * 2);
    const notes = [55.0, 65.41, 73.42, 49.0];
    var lastNoise = 0.0;
    for (var i = 0; i < n; i++) {
      final ts = t + i / rate;
      final e = energy(ts);
      final b = ts / beat;
      final inBeat = (b - b.floorToDouble()) * beat;
      final bar = (b / 4).floor();
      final drive = ((e - 0.25) / 0.5).clamp(0.0, 1.0);
      final kickEnv = _hit(inBeat, 0.18);
      final kick =
          math.sin(
            2 * math.pi * (48 + 60 * math.exp(-inBeat / 0.03)) * inBeat,
          ) *
          kickEnv *
          0.55 *
          drive;
      final bassF = notes[bar % notes.length];
      final bass = math.sin(2 * math.pi * bassF * ts) * 0.22 * e;
      final sample = (ts * rate).floor();
      final noise = sceneHash(sample, 71) * 2 - 1;
      final snare = b.floor().isOdd ? noise * _hit(inBeat, 0.11) * 0.28 : 0.0;
      final hiss = noise - lastNoise; // a crude high-pass for the hats
      lastNoise = noise;
      final half = beat / 2;
      final hats = hiss * _hit(inBeat % half, 0.035) * 0.1 * drive * brightness;
      double pad(double detune) =>
          (math.sin(2 * math.pi * 220 * detune * ts) +
              math.sin(2 * math.pi * 277.2 * detune * ts) * 0.8 +
              math.sin(2 * math.pi * 329.6 * detune * ts) * 0.7 +
              math.sin(2 * math.pi * 1318.5 * detune * ts) *
                  0.12 *
                  brightness) *
          0.07 *
          e;
      final mid = kick + bass + snare;
      out[i * 2] = ((mid + pad(1.0) + hats) * gain).clamp(-1.0, 1.0).toDouble();
      out[i * 2 + 1] = ((mid + pad(1.004) - hats * 0.6) * gain)
          .clamp(-1.0, 1.0)
          .toDouble();
    }
    return out;
  }

  /// The loudness scan's result, as the info dialog shows it.
  static const LoudnessScan loudness = LoudnessScan(
    state: LoudnessScanState.ready,
    integrated: -9.8,
    range: 6.4,
    samplePeak: 0.933,
    truePeak: 0.966,
  );
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Smooth 1D value noise in 0 to 1, from a [seed]ed integer hash.
double sceneNoise(double x, int seed) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  return sceneHash(i, seed) * (1 - u) + sceneHash(i + 1, seed) * u;
}

/// A value in 0 to 1 from [i] and [seed], the same on every run.
double sceneHash(int i, int seed) {
  var h = (i * 374761393 + seed * 668265263) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  h ^= h >> 16;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}
