import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/biquad.dart';
import '../../../audio/pcm_analysis.dart';
import '../../../audio/units.dart';
import '../../../ui/widgets/controls.dart';
import 'compressor_curve.dart';
import 'crossfeed_diagram.dart';
import 'crystalizer_waveform.dart';
import 'equalizer.dart';
import 'loudness_gauge.dart';
import '../runtime_params.dart';
import 'param_controls.dart';
import 'response_curve.dart';
import 'stereo_scope.dart';

/// The graphic editor of a featured stage, and its curated controls: the
/// hero graphic over a few sliders in musical units (dB, Hz, ms), where
/// the generic editor would show the raw lavfi values.
class FeaturedEditor {
  final Widget graphic;
  final List<Widget> controls;
  const FeaturedEditor(this.graphic, this.controls);

  /// The editor of [e], or `null` when its filter is not featured.
  ///
  /// [tapInstance] and [live] let the compressor curve follow the right
  /// stage, only while the rack grants it a tap. [loudness] is the live
  /// loudness meter, for the loudnorm gauge (null while the meter is off).
  static FeaturedEditor? of(
    AudioEffect e, {
    required StageChange onChange,
    required VoidCallback onEnd,
    int tapInstance = 0,
    bool live = false,
    Stream<Loudness>? loudness,
  }) {
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      AudioEffect Function(double v) apply, {
      required String Function(double v) format,
      double? resetTo,
      String? option,
      SliderScale scale = SliderScale.linear,
    }) {
      final tag = option == null ? null : liveTagOf(e, option);
      return SliderRow(
        label: label,
        scale: scale,
        tag: tag?.$1,
        tagTooltip: tag?.$2,
        value: value.clamp(min, max),
        min: min,
        max: max,
        format: format,
        resetTo: resetTo,
        enabled: e.enabled,
        onChanged: (v) => onChange(apply(v), live: true),
        onChangeEnd: (_) => onEnd(),
      );
    }

    String pct(double v) => '${(v * 100).round()}%';

    switch (e) {
      case SuperequalizerEffect eq:
        return FeaturedEditor(
          Equalizer(
            bandsDb: {
              for (final b in kEqBands)
                b.key: eqLinearToDb(eq.params[b.key] ?? 1.0),
            },
            enabled: eq.enabled,
            onChanged: (key, db) {
              final params = Map<String, double>.from(eq.params);
              if (db.abs() < 0.05) {
                params.remove(key);
              } else {
                params[key] = eqDbToLinear(db);
              }
              onChange(eq.copyWith(params: params), live: true);
            },
            onChangeEnd: onEnd,
          ),
          const [],
        );
      case AcompressorEffect c:
        return FeaturedEditor(
          CompressorCurve(
            threshold: c.threshold,
            ratio: c.ratio,
            knee: c.knee,
            makeup: c.makeup,
            enabled: c.enabled,
            instance: tapInstance,
            live: live,
          ),
          [
            slider(
              'Threshold',
              eqLinearToDb(c.threshold),
              -60,
              0,
              (v) =>
                  c.copyWith(threshold: eqDbToLinear(v).clamp(0.000977, 1.0)),
              format: (v) => '${v.round()} dB',
              resetTo: -18,
              option: 'threshold',
            ),
            slider(
              'Ratio',
              c.ratio,
              1,
              20,
              (v) => c.copyWith(ratio: v),
              format: (v) => '${v.toStringAsFixed(1)}:1',
              resetTo: 2,
              option: 'ratio',
              scale: SliderScale.log,
            ),
            slider(
              'Attack',
              c.attack,
              1,
              200,
              (v) => c.copyWith(attack: v),
              format: (v) => '${v.round()} ms',
              resetTo: 20,
              option: 'attack',
              scale: SliderScale.log,
            ),
            slider(
              'Release',
              c.release,
              20,
              2000,
              (v) => c.copyWith(release: v),
              format: (v) => '${v.round()} ms',
              resetTo: 250,
              option: 'release',
              scale: SliderScale.log,
            ),
            slider(
              'Make-up gain',
              eqLinearToDb(c.makeup),
              0,
              24,
              (v) => c.copyWith(makeup: eqDbToLinear(v).clamp(1.0, 64.0)),
              format: (v) => '+${v.round()} dB',
              resetTo: 0,
              option: 'makeup',
            ),
          ],
        );
      case BassEffect b:
        return FeaturedEditor(
          ResponseCurve(
            response: BiquadResponse.lowShelf(b.frequency, b.gain),
            markerHz: b.frequency,
            enabled: b.enabled,
            description:
                '${b.gain.toStringAsFixed(1)} dB below '
                '${formatHz(b.frequency)}',
          ),
          [
            slider(
              'Gain',
              b.gain,
              -24,
              24,
              (v) => b.copyWith(gain: v),
              format: (v) => '${v.toStringAsFixed(1)} dB',
              resetTo: 0,
              option: 'gain',
            ),
            slider(
              'Frequency',
              b.frequency,
              20,
              500,
              (v) => b.copyWith(frequency: v),
              format: formatHz,
              resetTo: 100,
              option: 'frequency',
              scale: SliderScale.log,
            ),
          ],
        );
      case TrebleEffect t:
        return FeaturedEditor(
          ResponseCurve(
            response: BiquadResponse.highShelf(t.frequency, t.gain),
            markerHz: t.frequency,
            enabled: t.enabled,
            description:
                '${t.gain.toStringAsFixed(1)} dB above '
                '${formatHz(t.frequency)}',
          ),
          [
            slider(
              'Gain',
              t.gain,
              -24,
              24,
              (v) => t.copyWith(gain: v),
              format: (v) => '${v.toStringAsFixed(1)} dB',
              resetTo: 0,
              option: 'gain',
            ),
            slider(
              'Frequency',
              t.frequency,
              1000,
              16000,
              (v) => t.copyWith(frequency: v),
              format: formatHz,
              resetTo: 3000,
              option: 'frequency',
              scale: SliderScale.log,
            ),
          ],
        );
      case AsubboostEffect sb:
        return FeaturedEditor(
          ResponseCurve(
            response: BiquadResponse.lowShelf(
              sb.cutoff,
              amplitudeToDb(sb.boost),
            ),
            markerHz: sb.cutoff,
            description:
                'boost ${sb.boost.toStringAsFixed(1)} below '
                '${formatHz(sb.cutoff)}',
            enabled: sb.enabled,
          ),
          [
            slider(
              'Boost',
              sb.boost,
              1,
              12,
              (v) => sb.copyWith(boost: v),
              format: (v) => v.toStringAsFixed(1),
              resetTo: 2,
              option: 'boost',
            ),
            slider(
              'Cutoff',
              sb.cutoff,
              50,
              900,
              (v) => sb.copyWith(cutoff: v),
              format: formatHz,
              resetTo: 100,
              option: 'cutoff',
              scale: SliderScale.log,
            ),
            slider(
              'Wet',
              sb.wet,
              0,
              1,
              (v) => sb.copyWith(wet: v),
              format: pct,
              resetTo: 1,
              option: 'wet',
            ),
            slider(
              'Dry',
              sb.dry,
              0,
              1,
              (v) => sb.copyWith(dry: v),
              format: pct,
              resetTo: 1,
              option: 'dry',
            ),
          ],
        );
      case ExtrastereoEffect st:
        return FeaturedEditor(StereoScope(enabled: st.enabled), [
          slider(
            'Amount',
            st.m,
            0,
            8,
            (v) => st.copyWith(m: v),
            format: (v) => v.toStringAsFixed(1),
            resetTo: 2.5,
            option: 'm',
          ),
        ]);
      case CrossfeedEffect cf:
        return FeaturedEditor(
          CrossfeedDiagram(
            strength: cf.strength,
            range: cf.range,
            enabled: cf.enabled,
          ),
          [
            slider(
              'Strength',
              cf.strength,
              0,
              1,
              (v) => cf.copyWith(strength: v),
              format: pct,
              resetTo: 0.2,
              option: 'strength',
            ),
            slider(
              'Range',
              cf.range,
              0,
              1,
              (v) => cf.copyWith(range: v),
              format: pct,
              resetTo: 0.5,
              option: 'range',
            ),
          ],
        );
      case CrystalizerEffect cr:
        return FeaturedEditor(
          CrystalizerWaveform(intensity: cr.i, enabled: cr.enabled),
          [
            slider(
              'Intensity',
              cr.i,
              -10,
              10,
              (v) => cr.copyWith(i: v),
              format: (v) => v.toStringAsFixed(1),
              resetTo: 2,
              option: 'i',
            ),
          ],
        );
      case LoudnormEffect ln:
        return FeaturedEditor(
          StreamBuilder<Loudness>(
            stream: loudness,
            builder: (context, snap) => LoudnessGauge(
              reading: snap.data,
              target: ln.i,
              range: ln.lra,
              truePeak: ln.tp,
              enabled: ln.enabled,
            ),
          ),
          [
            slider(
              'Target',
              ln.i,
              -70,
              -5,
              (v) => ln.copyWith(i: v),
              format: (v) => '${v.round()} LUFS',
              resetTo: -24,
              option: 'i',
            ),
            slider(
              'Range',
              ln.lra,
              1,
              50,
              (v) => ln.copyWith(lra: v),
              format: (v) => '${v.round()} LU',
              resetTo: 7,
              option: 'lra',
            ),
            slider(
              'True peak',
              ln.tp,
              -9,
              0,
              (v) => ln.copyWith(tp: v),
              format: (v) => '${v.toStringAsFixed(1)} dB',
              resetTo: -2,
              option: 'tp',
            ),
          ],
        );
      default:
        return null;
    }
  }
}
