import 'dart:math' as math;

/// RBJ-cookbook biquad magnitude responses, returned as `dB at Hz`
/// closures for the tone-control response curves. [fs] defaults to 48 kHz,
/// the shape is essentially sample-rate independent across the audible
/// band.
class BiquadResponse {
  BiquadResponse._();

  static double Function(double) lowShelf(
    double f0,
    double gainDb, {
    double fs = 48000,
    double slope = 0.7,
  }) => _shelf(f0, gainDb, fs, slope, low: true);

  static double Function(double) highShelf(
    double f0,
    double gainDb, {
    double fs = 48000,
    double slope = 0.7,
  }) => _shelf(f0, gainDb, fs, slope, low: false);

  static double Function(double) _shelf(
    double f0,
    double gainDb,
    double fs,
    double slope, {
    required bool low,
  }) {
    final a = math.pow(10, gainDb / 40).toDouble();
    final w0 = 2 * math.pi * f0 / fs;
    final cw = math.cos(w0);
    final sw = math.sin(w0);
    final alpha = sw / 2 * math.sqrt((a + 1 / a) * (1 / slope - 1) + 2);
    final twoSqrtAAlpha = 2 * math.sqrt(a) * alpha;
    final double b0, b1, b2, a0, a1, a2;
    if (low) {
      b0 = a * ((a + 1) - (a - 1) * cw + twoSqrtAAlpha);
      b1 = 2 * a * ((a - 1) - (a + 1) * cw);
      b2 = a * ((a + 1) - (a - 1) * cw - twoSqrtAAlpha);
      a0 = (a + 1) + (a - 1) * cw + twoSqrtAAlpha;
      a1 = -2 * ((a - 1) + (a + 1) * cw);
      a2 = (a + 1) + (a - 1) * cw - twoSqrtAAlpha;
    } else {
      b0 = a * ((a + 1) + (a - 1) * cw + twoSqrtAAlpha);
      b1 = -2 * a * ((a - 1) + (a + 1) * cw);
      b2 = a * ((a + 1) + (a - 1) * cw - twoSqrtAAlpha);
      a0 = (a + 1) - (a - 1) * cw + twoSqrtAAlpha;
      a1 = 2 * ((a - 1) - (a + 1) * cw);
      a2 = (a + 1) - (a - 1) * cw - twoSqrtAAlpha;
    }
    return (hz) {
      final w = 2 * math.pi * hz / fs;
      final cosw = math.cos(w), cos2w = math.cos(2 * w);
      final sinw = math.sin(w), sin2w = math.sin(2 * w);
      final numRe = b0 + b1 * cosw + b2 * cos2w;
      final numIm = -(b1 * sinw + b2 * sin2w);
      final denRe = a0 + a1 * cosw + a2 * cos2w;
      final denIm = -(a1 * sinw + a2 * sin2w);
      final num = math.sqrt(numRe * numRe + numIm * numIm);
      final den = math.sqrt(denRe * denRe + denIm * denIm);
      if (den == 0 || num == 0) return 0;
      return 20 * math.log(num / den) / math.ln10;
    };
  }
}
