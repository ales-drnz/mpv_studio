import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/widgets/featured_editors.dart';
import 'package:mpv_studio/features/effects/runtime_params.dart';
import 'package:mpv_studio/features/effects/widgets/param_controls.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

/// The effects' sliders move frequencies, times and ratios along a log
/// track, as their graphs draw them, and say which options change the
/// running filter live and which rebuild it.
void main() {
  SliderRow row(FeaturedEditor e, String label) =>
      e.controls.whereType<SliderRow>().firstWhere((r) => r.label == label);

  FeaturedEditor editor(AudioEffect e) =>
      FeaturedEditor.of(e, onChange: (_, {live = false}) {}, onEnd: () {})!;

  test('frequencies, times and ratios are on log tracks', () {
    final bass = editor(const BassEffect(gain: 6, frequency: 120));
    expect(row(bass, 'Frequency').scale, SliderScale.log);
    expect(row(bass, 'Gain').scale, SliderScale.linear);
    final comp = editor(const AcompressorEffect());
    for (final l in ['Ratio', 'Attack', 'Release']) {
      expect(row(comp, l).scale, SliderScale.log, reason: l);
    }
    expect(row(comp, 'Threshold').scale, SliderScale.linear);
  });

  test('each slider says whether it moves the filter live', () {
    final bass = editor(const BassEffect());
    expect(row(bass, 'Gain').tag, 'live');
    final norm = editor(const LoudnormEffect());
    expect(norm.controls.whereType<SliderRow>().first.tag, 'rebuild');
  });

  test('the generic editor picks the scale by the option', () {
    final d = descriptorOf(const AcompressorEffect().filter)!;
    SliderRow of(String name) =>
        buildParamControl(
              d.params.firstWhere((p) => p.name == name),
              const AcompressorEffect(),
              onChange: (_, {live = false}) {},
              onEnd: () {},
            )
            as SliderRow;
    expect(of('attack').scale, SliderScale.log);
    expect(of('attack').tag, 'live');
    expect(of('threshold').scale, SliderScale.linear);
  });

  test('a biquad frequency from 0 Hz is a log track from 10 Hz', () {
    final d = descriptorOf(const EqualizerEffect().filter)!;
    final row =
        buildParamControl(
              d.params.firstWhere((p) => p.name == 'frequency'),
              const EqualizerEffect(),
              onChange: (_, {live = false}) {},
              onEnd: () {},
            )
            as SliderRow;
    expect(row.scale, SliderScale.log);
    expect(row.min, 10);
    expect(row.max, 24000);
  });

  test('centre frequencies, rates and Q factors are log too', () {
    for (final (name, min) in [
      ('centerf', 2.0),
      ('hz', 0.01),
      ('lforate', 0.01),
      ('qfactor', 0.1),
      ('dqfactor', 0.1),
      ('tempo', 0.5),
    ]) {
      expect(logScaled(name, min), isTrue, reason: name);
    }
  });

  test('every featured option is an option of its filter', () {
    for (final e in [
      const AcompressorEffect(),
      const BassEffect(),
      const TrebleEffect(),
      const AsubboostEffect(),
      const ExtrastereoEffect(),
      const CrossfeedEffect(),
      const CrystalizerEffect(),
      const LoudnormEffect(),
    ]) {
      // The editor asserts each slider's option against the filter's.
      expect(editor(e).controls, isNotEmpty, reason: '${e.filter}');
    }
  });
}
