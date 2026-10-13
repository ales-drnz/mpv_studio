import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// The headline: `playbackState` with its three axes as status lights,
/// and the libmpv and FFmpeg builds.
class StatusView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const StatusView({super.key, required this.snapshot});

  static Color colorOf(MpvPlaybackState s) => switch (s) {
    MpvPlaybackState.idle => Tokens.fgFaint,
    MpvPlaybackState.loading => Tokens.amber,
    MpvPlaybackState.buffering => Tokens.amber,
    MpvPlaybackState.playing => Tokens.green,
    MpvPlaybackState.paused => Tokens.accent,
    MpvPlaybackState.completed => Tokens.fgDim,
  };

  @override
  Widget build(BuildContext context) {
    final s = snapshot.state;
    final phase = snapshot.playbackState;
    final color = colorOf(phase);

    final headline = Semantics(
      label: 'Playback state ${EngineFormat.playbackState(phase)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: Tokens.s12),
          Text(EngineFormat.playbackState(phase), style: Tokens.title),
        ],
      ),
    );

    final spies = Wrap(
      spacing: Tokens.s16,
      runSpacing: Tokens.s8,
      children: [
        Spy(label: 'playWhenReady', on: s.playWhenReady, color: Tokens.accent),
        Spy(label: 'playing', on: s.playing),
        Spy(label: 'completed', on: s.completed, color: Tokens.fgDim),
      ],
    );

    final versions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Version('libmpv', s.mpvVersion),
        const SizedBox(height: Tokens.s4),
        _Version('FFmpeg', s.ffmpegVersion),
      ],
    );

    return EngineCard(
      title: 'Engine',
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 520;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              headline,
              const SizedBox(height: Tokens.s12),
              spies,
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: Tokens.s16),
                versions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: Tokens.s16),
              versions,
            ],
          );
        },
      ),
    );
  }
}

class _Version extends StatelessWidget {
  final String name;
  final String value;
  const _Version(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 56, child: Text(name, style: Tokens.caption)),
        ValueBadge(value.isEmpty ? 'n/a' : value, color: Tokens.fg),
      ],
    );
  }
}
