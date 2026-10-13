import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';
import 'info_sheet.dart';

/// Full DAW-style transport. A primary row (previous · skip-back ·
/// play/pause · skip-forward · next) over a secondary row of mode toggles
/// (shuffle · stop · loop). Play/pause binds to `playWhenReady` (the
/// intent axis) so it never flickers during seeks or buffering.
class TransportControls extends StatelessWidget {
  static const _skip = Duration(seconds: 10);

  const TransportControls({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    // A seek with nothing loaded, or a stale queue index, throws: show it.
    final guard = PlayerScope.issuesOf(context).guard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s12,
              vertical: Tokens.s4,
            ),
            decoration: ShapeDecoration(
              // A slightly raised squircle container that lifts the
              // transport off the near-black backdrop.
              color: Tokens.surface2,
              shape: Tokens.squircle(Tokens.rLg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Glyph(
                  icon: Icons.skip_previous_rounded,
                  size: 28,
                  onTap: () => guard(player.previous),
                  // Long-press forces past the first entry (stops playback).
                  onLongPress: () => guard(() => player.previous(force: true)),
                  tooltip: 'Previous (long-press to force)',
                ),
                const SizedBox(width: Tokens.s16),
                _Glyph(
                  icon: Icons.replay_10_rounded,
                  size: 26,
                  onTap: () => guard(() => player.seek(-_skip, relative: true)),
                  tooltip: 'Back 10s',
                ),
                const SizedBox(width: Tokens.s16),
                Live<bool>(
                  stream: player.stream.playWhenReady,
                  initial: player.state.playWhenReady,
                  builder: (context, playing) => _PlayButton(
                    playing: playing,
                    onTap: () =>
                        guard(() => playing ? player.pause() : player.play()),
                  ),
                ),
                const SizedBox(width: Tokens.s16),
                _Glyph(
                  icon: Icons.forward_10_rounded,
                  size: 26,
                  onTap: () => guard(() => player.seek(_skip, relative: true)),
                  tooltip: 'Forward 10s',
                ),
                const SizedBox(width: Tokens.s16),
                _Glyph(
                  icon: Icons.skip_next_rounded,
                  size: 28,
                  onTap: () => guard(player.next),
                  // Long-press forces past the last entry (stops playback).
                  onLongPress: () => guard(() => player.next(force: true)),
                  tooltip: 'Next (long-press to force)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.s12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Live<bool>(
                stream: player.stream.shuffle,
                initial: player.state.shuffle,
                builder: (context, on) => _Glyph(
                  icon: Icons.shuffle_rounded,
                  size: 19,
                  active: on,
                  onTap: () => player.setShuffle(!on),
                  tooltip: 'Shuffle',
                ),
              ),
              const SizedBox(width: Tokens.s24),
              _Glyph(
                icon: Icons.stop_rounded,
                size: 20,
                onTap: () => guard(player.stop),
                tooltip: 'Stop',
              ),
              const SizedBox(width: Tokens.s24),
              Live<Loop>(
                stream: player.stream.loop,
                initial: player.state.loop,
                builder: (context, loop) => _Glyph(
                  icon: loop == Loop.file
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  size: 19,
                  active: loop != Loop.off,
                  onTap: () => player.setLoop(_nextLoop(loop)),
                  tooltip: 'Repeat',
                ),
              ),
              const SizedBox(width: Tokens.s24),
              _Glyph(
                icon: Icons.settings_backup_restore_rounded,
                size: 19,
                onTap: player.revertSeek,
                tooltip: 'Undo last seek',
              ),
              const SizedBox(width: Tokens.s24),
              _Glyph(
                icon: Icons.info_outline_rounded,
                size: 19,
                onTap: () => showInfoSheet(context),
                tooltip: 'Track & playback info',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Loop _nextLoop(Loop l) => switch (l) {
    Loop.off => Loop.file,
    Loop.file => Loop.playlist,
    Loop.playlist => Loop.off,
  };
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _PlayButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rLg),
        child: Container(
          width: 58,
          height: 58,
          decoration: ShapeDecoration(
            color: Tokens.accent,
            shape: Tokens.squircle(Tokens.rLg),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              size: 30,
              color: Tokens.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final String? tooltip;

  const _Glyph({
    required this.icon,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s8),
          child: Icon(
            icon,
            size: size,
            color: active ? Tokens.accent : Tokens.fg,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
