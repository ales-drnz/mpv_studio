import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/playback_issues.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/widgets/controls.dart';
import '../../../util/reactive.dart';
import '../transport_actions.dart';

/// Speed and pitch side by side, as the engine moves them: the speed on a
/// log track with 1x in the middle, the pitch in semitones (a pitch of 2
/// is an octave, 12 up), and Keep pitch, which holds the pitch when the
/// speed changes.
Future<void> showSpeedAndPitch(
  BuildContext context,
  PlayerApi player,
  CallGuard guard,
) => showStudioDialog<void>(
  context,
  title: 'Speed and pitch',
  builder: (context) => Live<double>(
    stream: player.stream.rate,
    initial: player.state.rate,
    builder: (context, rate) => Live<double>(
      stream: player.stream.pitch,
      initial: player.state.pitch,
      builder: (context, pitch) => Live<bool>(
        stream: player.stream.pitchCorrection,
        initial: player.state.pitchCorrection,
        builder: (context, keep) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderRow(
              label: 'Speed',
              value: rate,
              min: 0.25,
              max: 4,
              scale: SliderScale.log,
              resetTo: 1,
              format: formatRate,
              onChanged: (v) => guard(() => player.setRate(v)),
            ),
            SliderRow(
              label: 'Pitch',
              description: 'In semitones; 12 is an octave',
              value: semitonesOf(pitch),
              min: -12,
              max: 12,
              divisions: 24,
              resetTo: 0,
              format: formatSemitones,
              onChanged: (v) => guard(() => player.setPitch(pitchOf(v))),
            ),
            SwitchRow(
              label: 'Keep pitch',
              subtitle: 'Hold the pitch when the speed changes',
              value: keep,
              onChanged: (v) => guard(() => player.setPitchCorrection(v)),
            ),
          ],
        ),
      ),
    ),
  ),
  actions: (context) => [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Done'),
    ),
  ],
);

/// The semitones a pitch ratio shifts by, to the nearest one.
double semitonesOf(double pitch) =>
    pitch <= 0 ? 0 : (12 * math.log(pitch) / math.ln2).roundToDouble();

/// The pitch ratio of a shift by [semitones].
double pitchOf(double semitones) => math.pow(2, semitones / 12).toDouble();

/// "+3 st", "0 st", "-5 st".
String formatSemitones(double semitones) {
  final s = semitones.round();
  return '${s > 0 ? '+' : ''}$s st';
}
