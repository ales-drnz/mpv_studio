import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/playback_states.dart';
import 'package:mpv_studio/features/now_playing/widgets/spectrum_curve.dart';
import 'package:mpv_studio/features/now_playing/widgets/speed_pitch.dart';

/// Cases the review of the listen branch found.
void main() {
  test('a frequency mark sits where its band is drawn', () {
    const low = 20.0, high = 20000.0;
    for (final n in [16, 64]) {
      final r = math.pow(high / low, 1 / n);
      for (final i in [0, n ~/ 3, n - 1]) {
        // Band i is drawn at i / (n - 1) of the width and centred, on
        // its geometric edges, at low * r^(i + 1/2).
        final centre = low * math.pow(r, i + 0.5);
        expect(
          spectrumMarkX(centre, low: low, high: high, bands: n, width: 1440),
          closeTo(i / (n - 1) * 1440, 0.01),
        );
      }
    }
  });

  test('a driver list with null is a choice of silence', () {
    expect(chosenNullOutput('null'), isTrue);
    expect(chosenNullOutput('pipewire,null'), isTrue);
    expect(chosenNullOutput('null=untimed'), isTrue);
    expect(chosenNullOutput('pipewire'), isFalse);
    expect(chosenNullOutput(''), isFalse);
  });

  test('a pitch between semitones reads as it is', () {
    expect(formatSemitones(semitonesOf(1.03)), '+0.5 st');
    expect(
      formatSemitones(semitonesOf(math.pow(2, 3 / 12).toDouble())),
      '+3 st',
    );
    expect(formatSemitones(semitonesOf(1)), '0 st');
  });
}
