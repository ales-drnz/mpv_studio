import 'dart:math' as math;

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Pure-Dart analysis of the engine's [PcmFrame] taps: the maths the
/// visualizers run on every audio frame, kept out of the widgets so a
/// painter only ever receives finished numbers.
///
/// Everything here is stateless and side-effect free; stateful followers
/// (ballistics, peak-hold) live in `level_follower.dart`.

/// Linear amplitude (0..) → dBFS. Silence floors at [floorDb] instead of
/// running off to −∞.
double amplitudeToDb(double amp, {double floorDb = -120}) =>
    amp <= 1e-9 ? floorDb : 20 * (math.log(amp) / math.ln10);

/// dBFS → linear amplitude. The inverse of [amplitudeToDb].
double dbToAmplitude(double db) => math.pow(10, db / 20).toDouble();

/// Largest absolute sample (0..1) across every channel of [f].
double framePeak(PcmFrame f) {
  var peak = 0.0;
  final s = f.samples;
  for (var i = 0; i < s.length; i++) {
    final a = s[i].abs();
    if (a > peak) peak = a;
  }
  return peak.toDouble();
}

/// RMS amplitude across every channel of [f] (0 when empty).
double frameRms(PcmFrame f) {
  final s = f.samples;
  if (s.isEmpty) return 0;
  var sumSq = 0.0;
  for (var i = 0; i < s.length; i++) {
    final v = s[i];
    sumSq += v * v;
  }
  return math.sqrt(sumSq / s.length);
}

/// Per-channel peak amplitudes for the first two channels. Mono frames
/// report the same value on both sides.
({double left, double right}) channelPeaks(PcmFrame f) {
  final s = f.samples;
  final ch = f.channels;
  if (ch <= 1) {
    final p = framePeak(f);
    return (left: p, right: p);
  }
  var l = 0.0, r = 0.0;
  for (var i = 0; i + 1 < s.length; i += ch) {
    final al = s[i].abs();
    if (al > l) l = al;
    final ar = s[i + 1].abs();
    if (ar > r) r = ar;
  }
  return (left: l.toDouble(), right: r.toDouble());
}

/// Phase correlation of the first two channels: +1 mono/correlated, 0
/// uncorrelated (wide), −1 anti-phase. Mono frames return +1.
double stereoCorrelation(PcmFrame f) {
  final s = f.samples;
  final ch = f.channels;
  if (ch < 2 || s.length < 2) return 1;
  var sumLR = 0.0, sumL2 = 0.0, sumR2 = 0.0;
  final pairs = s.length ~/ ch;
  for (var p = 0; p < pairs; p++) {
    final l = s[p * ch];
    final r = s[p * ch + 1];
    sumLR += l * r;
    sumL2 += l * l;
    sumR2 += r * r;
  }
  final denom = math.sqrt(sumL2 * sumR2);
  return denom > 1e-9 ? (sumLR / denom).clamp(-1.0, 1.0).toDouble() : 1.0;
}

/// Rotate an L/R sample pair into vectorscope space: `x` = side (width),
/// `y` = mid (centre). Both roughly in −1..1 for full-scale input.
({double x, double y}) midSide(double l, double r) {
  const invSqrt2 = 0.70710678;
  return (x: (l - r) * invSqrt2, y: (l + r) * invSqrt2);
}

/// One-pole smoothing toward [target] from [previous] by [alpha] (0..1).
/// Used for per-frame meter ballistics where a fixed coefficient is
/// enough; time-constant smoothing lives in [emaTowardsTau].
double emaTowards(double previous, double target, double alpha) =>
    previous + alpha * (target - previous);

/// Time-constant one-pole smoothing: advances [previous] toward [target]
/// over [dtSeconds] with time constant [tauSeconds], so the rate is
/// frame-rate independent.
double emaTowardsTau(
  double previous,
  double target,
  double dtSeconds,
  double tauSeconds,
) {
  if (tauSeconds <= 0) return target;
  final alpha = 1 - math.exp(-dtSeconds / tauSeconds);
  return previous + alpha * (target - previous);
}
