import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../settings_scope.dart';

/// What the output is doing right now: the active driver, its state, the
/// decoded codec and the format reaching the hardware.
class OutputStatusSection extends StatelessWidget {
  const OutputStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.of(context).player;
    return SettingsGroup(
      label: 'Output status',
      children: [
        Live<String>(
          stream: p.stream.currentAo,
          initial: p.state.currentAo,
          builder: (context, v) =>
              InfoRow(label: 'Active driver', value: v.isEmpty ? '-' : v),
        ),
        Live<AudioOutputState>(
          stream: p.stream.audioOutputState,
          initial: p.state.audioOutputState,
          builder: (context, v) =>
              InfoRow(label: 'Output state', value: v.mpvValue),
        ),
        // The codec is decoder side (the track source), so it comes from
        // audioParams rather than the hardware output.
        Live<AudioParams>(
          stream: p.stream.audioParams,
          initial: p.state.audioParams,
          builder: (context, a) =>
              InfoRow(label: 'Codec', value: codecLabel(a)),
        ),
        // Everything below describes the actual hardware output.
        Live<AudioParams>(
          stream: p.stream.audioOutParams,
          initial: p.state.audioOutParams,
          builder: (context, a) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(
                label: 'Format',
                value: a.format == null || a.format == Format.auto
                    ? '-'
                    : a.format!.mpvValue,
              ),
              InfoRow(label: 'Bit depth', value: bitDepthLabel(a.format)),
              InfoRow(
                label: 'Sample rate',
                value: sampleRateLabel(a.sampleRate),
              ),
              InfoRow(label: 'Channels', value: channelsLabel(a)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The decoded codec, preferring the descriptive `audio-codec-name` and
/// falling back to the short `audio-codec`; '-' when nothing is decoding.
String codecLabel(AudioParams p) {
  final c = (p.codecName?.isNotEmpty ?? false) ? p.codecName! : (p.codec ?? '');
  return c.isEmpty ? '-' : c;
}

/// Sample depth and type of [f] in words (e.g. '16-bit signed integer'),
/// noting planar layouts; '-' when no audio is being output.
String bitDepthLabel(Format? f) {
  if (f == null || f == Format.auto) return '-';
  final base = switch (f) {
    Format.u8 || Format.u8Planar => '8-bit unsigned integer',
    Format.s16 || Format.s16Planar => '16-bit signed integer',
    Format.s32 || Format.s32Planar => '32-bit signed integer',
    Format.s64 || Format.s64Planar => '64-bit signed integer',
    Format.float32 || Format.float32Planar => '32-bit float',
    Format.float64 || Format.float64Planar => '64-bit float',
    Format.auto => '-',
  };
  return f.mpvValue.endsWith('p') ? '$base, planar' : base;
}

String sampleRateLabel(int? hz) =>
    hz == null ? '-' : '${(hz / 1000).toStringAsFixed(1)} kHz';

/// The channel layout by name with the raw count when both are known
/// (e.g. 'stereo, 2 channels'); '-' when nothing is being output.
String channelsLabel(AudioParams p) {
  final hr = p.hrChannels;
  final count = p.channelCount;
  if (hr != null && hr.isNotEmpty) {
    return count != null ? '$hr, $count channels' : hr;
  }
  return count != null ? '$count channels' : '-';
}
