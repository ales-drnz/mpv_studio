import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
  /// points over the song.
  static WaveformData waveform({int bins = 2920}) {
    final min = Float32List(bins);
    final max = Float32List(bins);
    final rms = Float32List(bins);
    final secs = length.inMicroseconds / 1e6;
    for (var i = 0; i < bins; i++) {
      final t = (i + 0.5) * secs / bins;
      final e = energy(t);
      final d = drums(t);
      final grain = 0.9 + 0.1 * _noise(t * 4.0, 3);
      final peak = (e * (0.7 + 0.16 * d.kick + 0.05 * d.snare) * grain)
          .clamp(0.015, 0.97)
          .toDouble();
      max[i] = peak;
      min[i] = -peak * 0.93;
      rms[i] = peak * 0.45;
    }
    return WaveformData(
      duration: length,
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
          0.13 * (_noise(i * 0.13 + t * 0.22, 23) - 0.5) +
          0.05 * (_noise(i * 0.31 - t * 0.12, 17) - 0.5);
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
    final right = left * (0.9 + 0.08 * _noise(t * 2.2, 29));
    return PcmFrame(
      samples: Float32List.fromList([left, right]),
      timestamp: Duration(microseconds: (t * 1e6).round()),
      sampleRate: 48000,
      channels: 2,
    );
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
double _noise(double x, int seed) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  return _hash(i, seed) * (1 - u) + _hash(i + 1, seed) * u;
}

double _hash(int i, int seed) {
  var h = (i * 374761393 + seed * 668265263) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  h ^= h >> 16;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}

/// Paints the song's cover, a flat poster of a night harbour (a banded
/// dusk sky, a low moon in rings of glow, its broken reflection, a
/// ferry), [size] pixels square, and returns it as PNG bytes. Flat colours
/// only: a GIF palette keeps them exact. Run it inside `tester.runAsync`.
Future<Uint8List> paintShowcaseCover({int size = 600}) async {
  final recorder = ui.PictureRecorder();
  final s = size.toDouble();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, s, s));
  Paint flat(int argb) => Paint()..color = Color(argb);
  final horizon = s * 0.63;

  // The sky in flat bands, deep blue at the top to a warm horizon.
  const sky = [0xFF101633, 0xFF1A1E45, 0xFF2B2856, 0xFF4A3463, 0xFF7C4567];
  const stops = [0.0, 0.26, 0.48, 0.66, 0.82];
  for (var i = 0; i < sky.length; i++) {
    final top = horizon * stops[i];
    canvas.drawRect(Rect.fromLTRB(0, top, s, horizon), flat(sky[i]));
  }
  canvas.drawRect(
    Rect.fromLTRB(0, horizon * 0.93, s, horizon),
    flat(0xFFC46F63),
  );

  // A few stars, placed by a fixed hash.
  for (var i = 0; i < 34; i++) {
    final x = _hash(i, 3) * s;
    final y = _hash(i, 7) * horizon * 0.5;
    final r = (_hash(i, 9) < 0.8 ? 1.4 : 2.4) * s / 600;
    canvas.drawCircle(Offset(x, y), r, flat(0xFFE9E4F5));
  }

  // The moon, low over the water, in rings of glow.
  final moon = Offset(s * 0.62, horizon - s * 0.1);
  canvas.drawCircle(moon, s * 0.25, flat(0x22FFC79A));
  canvas.drawCircle(moon, s * 0.185, flat(0x2EFFC79A));
  canvas.drawCircle(moon, s * 0.14, flat(0x3DFFD3A8));
  canvas.drawCircle(moon, s * 0.105, flat(0xFFFFE6C4));

  // Hills along the horizon, in front of the moon.
  final hills = Path()..moveTo(0, horizon);
  for (var i = 0; i <= 12; i++) {
    final x = i / 12 * s;
    final y = horizon - s * (0.02 + 0.035 * _noise(i * 0.9, 41));
    hills.lineTo(x, y);
  }
  hills
    ..lineTo(s, horizon)
    ..close();
  canvas.drawPath(hills, flat(0xFF211C3B));

  // Water in flat bands, darker towards the front.
  const water = [0xFF2A2446, 0xFF201C3A, 0xFF16152C, 0xFF0E0F20];
  for (var i = 0; i < water.length; i++) {
    final top = horizon + (s - horizon) * i / water.length;
    canvas.drawRect(Rect.fromLTRB(0, top, s, s), flat(water[i]));
  }

  // The moon's reflection, broken into strokes that widen and dim.
  for (var i = 0; i < 16; i++) {
    final y = horizon + s * 0.02 + i * (s - horizon - s * 0.05) / 16;
    final w = s * (0.05 + 0.013 * i) * (0.55 + 0.45 * _hash(i, 13));
    final x = moon.dx + s * 0.03 * (_hash(i, 17) - 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: w, height: s * 0.008),
        Radius.circular(s * 0.004),
      ),
      flat(i < 5 ? 0xFFFFD9AE : (i < 11 ? 0xFFD9A07E : 0xFF8C6170)),
    );
  }

  // A small ferry crossing the light, its windows lit.
  final deck = horizon + s * 0.05;
  final boat = Path()
    ..moveTo(s * 0.26, deck)
    ..lineTo(s * 0.44, deck)
    ..lineTo(s * 0.42, deck + s * 0.024)
    ..lineTo(s * 0.28, deck + s * 0.024)
    ..close()
    ..addRect(Rect.fromLTWH(s * 0.3, deck - s * 0.026, s * 0.1, s * 0.026))
    ..addRect(Rect.fromLTWH(s * 0.335, deck - s * 0.046, s * 0.012, s * 0.02));
  canvas.drawPath(boat, flat(0xFF080912));
  for (var i = 0; i < 5; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        s * (0.308 + i * 0.018),
        deck - s * 0.018,
        s * 0.009,
        s * 0.008,
      ),
      flat(0xFFFFD27F),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
