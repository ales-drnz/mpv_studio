import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// The headline: `playbackState`, then what the app asked for next to
/// what the engine does, where the track stands, what was opened, and the
/// libmpv and FFmpeg builds.
///
/// The request (`playWhenReady`) and the audio (`playing`) are two facts:
/// the request changes only through the Player API (play, pause, open,
/// stop), so a raw command can start the audio without it, and a request
/// waits while the engine loads or buffers. The card shows both, and says
/// why when they differ.
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

  /// Why the request and the audio differ, or null when they agree or
  /// there is nothing to wait for (no file loaded, the end reached).
  static String? mismatch(PlayerState s, MpvPlaybackState phase) {
    if (s.playing && !s.playWhenReady) {
      return 'Audio runs without a play request: a raw command started '
          'it. The request follows the next play or pause.';
    }
    final waiting =
        phase == MpvPlaybackState.loading ||
        phase == MpvPlaybackState.buffering;
    if (s.playWhenReady && !s.playing && waiting) {
      return 'Play requested, waiting for the engine to load or buffer.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot.state;
    final phase = snapshot.playbackState;
    final color = colorOf(phase);
    final note = mismatch(s, phase);
    final opened = s.streamOpenFilename;
    final source = s.streamPath.isNotEmpty ? s.streamPath : s.path;
    final rewritten = opened.isNotEmpty && opened != source;

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
          Flexible(
            child: Text(
              EngineFormat.playbackState(phase),
              style: Tokens.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return EngineCard(
      title: 'Playback',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headline,
          const SizedBox(height: Tokens.s12),
          ReadoutGrid(
            minCellWidth: 150,
            children: [
              _Fact(
                title: 'Play requested',
                wire: 'playWhenReady',
                on: s.playWhenReady,
                color: Tokens.accent,
              ),
              _Fact(title: 'Audio running', wire: 'playing', on: s.playing),
              _Fact(
                title: 'Reached the end',
                wire: 'completed',
                on: s.completed,
                color: Tokens.fgDim,
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: Tokens.s8),
            Text(
              note,
              key: const ValueKey('engine-intent-note'),
              style: Tokens.caption.copyWith(color: Tokens.amber),
            ),
          ],
          const SizedBox(height: Tokens.s16),
          ReadoutGrid(
            children: [
              Readout(
                'Position',
                s.duration > Duration.zero
                    ? '${EngineFormat.seconds(s.position)}, '
                          '${s.percentPos.round()}%'
                    : EngineFormat.seconds(s.position),
              ),
              Readout('Remaining', EngineFormat.seconds(s.playtimeRemaining)),
            ],
          ),
          if (source.isNotEmpty) ...[
            const SizedBox(height: Tokens.s12),
            _Path(label: 'Source', value: source),
            if (rewritten) ...[
              const SizedBox(height: Tokens.s8),
              _Path(
                label: 'Opened as (rewritten by the source resolver)',
                value: opened,
                color: Tokens.accent,
              ),
            ],
          ],
          const SizedBox(height: Tokens.s16),
          Wrap(
            spacing: Tokens.s16,
            runSpacing: Tokens.s8,
            children: [
              _Version('libmpv', s.mpvVersion),
              _Version('FFmpeg', s.ffmpegVersion),
            ],
          ),
        ],
      ),
    );
  }
}

/// One yes or no fact with its light: the plain name over the property.
class _Fact extends StatelessWidget {
  final String title;
  final String wire;
  final bool on;
  final Color? color;
  const _Fact({
    required this.title,
    required this.wire,
    required this.on,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Tokens.s8),
      child: Semantics(
        label: '$title ($wire): ${on ? 'yes' : 'no'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Spy(label: on ? 'yes' : 'no', on: on, color: color),
            const SizedBox(height: Tokens.s2),
            Text(
              title,
              style: Tokens.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              wire,
              style: Tokens.caption.copyWith(fontFamily: Tokens.mono),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A path or URL, one line, the whole of it in a tooltip.
class _Path extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Path({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Tokens.caption),
          const SizedBox(height: Tokens.s2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.numeric.copyWith(color: color ?? Tokens.fg),
          ),
        ],
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
        Text(name, style: Tokens.caption),
        const SizedBox(width: Tokens.s8),
        ValueBadge(value.isEmpty ? 'n/a' : value, color: Tokens.fg),
      ],
    );
  }
}
