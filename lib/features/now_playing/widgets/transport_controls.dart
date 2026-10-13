import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/playback_issues.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../transport_actions.dart';
import 'info_sheet.dart';

/// The full transport: previous, back 10 s, play and pause, forward 10 s
/// and next, over a row of modes (shuffle, stop, repeat, undo seek, speed
/// and track info). Play and pause binds to `playWhenReady`, the intent,
/// so it never flickers during seeks or buffering; a ring spins around it
/// while the track loads, buffers or seeks. Next and previous say so when
/// the queue has no entry that way; a long press forces past the end
/// (which stops).
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, this.dense = false});

  /// Smaller buttons, for short windows.
  final bool dense;

  static const _skip = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    final guard = scope.guard;
    final notify = feedbackFor(context);
    final maxGap = dense ? Tokens.s4 : Tokens.s12;
    final minTap = context.layout.minTap;
    final pad = dense ? Tokens.s4 : Tokens.s12;
    final play = dense ? 52.0 : 60.0;
    return LayoutBuilder(
      builder: (context, c) {
        // The gaps give way first, so the buttons keep their full tap
        // size; the FittedBoxes only shrink a row that still does not fit.
        double gapFor(double fixed, int gaps) => c.maxWidth.isFinite
            ? ((c.maxWidth - fixed) / gaps).clamp(0.0, maxGap).toDouble()
            : maxGap;
        final gap = gapFor(4 * minTap + play + 2 * pad, 4);
        final modeGap = gapFor(6 * minTap, 5);
        return _rows(context, player, guard, notify, gap, modeGap, pad, play);
      },
    );
  }

  Widget _rows(
    BuildContext context,
    PlayerApi player,
    CallGuard guard,
    Notify notify,
    double gap,
    double modeGap,
    double pad,
    double play,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: Tokens.s4),
            decoration: ShapeDecoration(
              color: Tokens.surface2,
              shape: Tokens.squircle(Tokens.rLg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TransportButton(
                  icon: Icons.skip_previous_rounded,
                  size: 28,
                  tooltip: 'Previous (long press to force)',
                  label: 'Previous',
                  onTap: () =>
                      skipTrack(player, guard, forward: false, notify: notify),
                  onLongPress: () =>
                      skipTrack(player, guard, forward: false, force: true),
                ),
                SizedBox(width: gap),
                TransportButton(
                  icon: Icons.replay_10_rounded,
                  size: 26,
                  tooltip: 'Back 10 s',
                  onTap: () => guard(() => player.seek(-_skip, relative: true)),
                ),
                SizedBox(width: gap),
                PlayPauseButton(player: player, guard: guard, size: play),
                SizedBox(width: gap),
                TransportButton(
                  icon: Icons.forward_10_rounded,
                  size: 26,
                  tooltip: 'Forward 10 s',
                  onTap: () => guard(() => player.seek(_skip, relative: true)),
                ),
                SizedBox(width: gap),
                TransportButton(
                  icon: Icons.skip_next_rounded,
                  size: 28,
                  tooltip: 'Next (long press to force)',
                  label: 'Next',
                  onTap: () =>
                      skipTrack(player, guard, forward: true, notify: notify),
                  onLongPress: () =>
                      skipTrack(player, guard, forward: true, force: true),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: dense ? Tokens.s4 : Tokens.s8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Live<bool>(
                stream: player.stream.shuffle,
                initial: player.state.shuffle,
                builder: (context, on) => TransportButton(
                  icon: Icons.shuffle_rounded,
                  size: 20,
                  active: on,
                  tooltip: on ? 'Shuffle on' : 'Shuffle off',
                  label: 'Shuffle',
                  toggled: on,
                  onTap: () => guard(() => player.setShuffle(!on)),
                ),
              ),
              SizedBox(width: modeGap),
              TransportButton(
                icon: Icons.stop_rounded,
                size: 20,
                tooltip: 'Stop',
                onTap: () => guard(player.stop),
              ),
              SizedBox(width: modeGap),
              Live<Loop>(
                stream: player.stream.loop,
                initial: player.state.loop,
                builder: (context, loop) => TransportButton(
                  icon: loop == Loop.file
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  size: 20,
                  active: loop != Loop.off,
                  tooltip: switch (loop) {
                    Loop.off => 'Repeat off',
                    Loop.file => 'Repeat this track',
                    Loop.playlist => 'Repeat the queue',
                  },
                  label: 'Repeat',
                  onTap: () => guard(() => player.setLoop(_nextLoop(loop))),
                ),
              ),
              SizedBox(width: modeGap),
              TransportButton(
                icon: Icons.settings_backup_restore_rounded,
                size: 20,
                tooltip: 'Undo last seek',
                onTap: () => guard(player.revertSeek),
              ),
              SizedBox(width: modeGap),
              _SpeedButton(player: player, guard: guard),
              SizedBox(width: modeGap),
              TransportButton(
                icon: Icons.info_outline_rounded,
                size: 20,
                tooltip: 'Track and playback info',
                onTap: () => showInfoSheet(context),
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

/// The big play and pause button, ringed by a spinner while the track
/// loads, buffers or seeks.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.player,
    required this.guard,
    this.size = 60,
  });

  final PlayerApi player;
  final CallGuard guard;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PlaybackBusy(
      player: player,
      builder: (context, busy) => Live<bool>(
        stream: player.stream.playWhenReady,
        initial: player.state.playWhenReady,
        builder: (context, playing) {
          final action = playing ? 'Pause' : 'Play';
          void onTap() => guard(playing ? player.pause : player.play);
          return Semantics(
            button: true,
            label: action,
            value: busy?.label,
            excludeSemantics: true,
            onTap: onTap,
            child: Tooltip(
              message: busy == null ? action : '$action (${busy.label})',
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Material(
                      color: Tokens.accent,
                      shape: Tokens.squircle(Tokens.rLg),
                      child: InkWell(
                        onTap: onTap,
                        customBorder: Tokens.squircle(Tokens.rLg),
                        child: SizedBox.square(
                          dimension: size,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(playing),
                              size: size / 2,
                              color: Tokens.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (busy != null)
                      IgnorePointer(
                        child: SizedBox.square(
                          key: const ValueKey('play-busy'),
                          dimension: size - 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Tokens.onAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What the player is waiting on, when it is.
enum PlaybackWait {
  loading('Loading'),
  buffering('Buffering'),
  seeking('Seeking');

  const PlaybackWait(this.label);

  /// The word the UI shows.
  final String label;
}

/// Rebuilds [builder] with what [player] is waiting on: the track loading
/// or buffering (`playbackState`) or a seek in flight (`seeking`), or null
/// when it is not waiting.
class PlaybackBusy extends StatelessWidget {
  const PlaybackBusy({super.key, required this.player, required this.builder});

  final PlayerApi player;
  final Widget Function(BuildContext context, PlaybackWait? wait) builder;

  @override
  Widget build(BuildContext context) {
    return Live<MpvPlaybackState>(
      stream: player.stream.playbackState,
      initial: MpvPlaybackState.idle,
      builder: (context, phase) => Live<bool>(
        stream: player.stream.seeking,
        initial: player.state.seeking,
        builder: (context, seeking) => builder(context, switch (phase) {
          MpvPlaybackState.loading => PlaybackWait.loading,
          MpvPlaybackState.buffering => PlaybackWait.buffering,
          _ => seeking ? PlaybackWait.seeking : null,
        }),
      ),
    );
  }
}

/// A round icon button of the transport, a full tap target on touch, with
/// a tooltip. [label] names it for screen readers when the tooltip says
/// more; [toggled] marks an on and off switch.
class TransportButton extends StatelessWidget {
  const TransportButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 24,
    this.onLongPress,
    this.active = false,
    this.label,
    this.toggled,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final bool active;
  final String? label;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final minTap = context.layout.minTap;
    final color = onTap == null
        ? Tokens.fgFaint
        : active
        ? Tokens.accent
        : Tokens.fg;
    return Semantics(
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      label: label ?? tooltip,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minTap, minHeight: minTap),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s6),
                child: Icon(icon, size: size, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The playback speed as a small "1x" button that opens the speeds.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.player, required this.guard});

  final PlayerApi player;
  final CallGuard guard;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> _pick(BuildContext context, double current) async {
    final box = context.findRenderObject() as RenderBox?;
    final at = box?.localToGlobal(box.size.bottomLeft(Offset.zero));
    final picked = await showStudioMenu<double>(
      context,
      position: at,
      title: 'Playback speed',
      items: [
        for (final s in _speeds)
          StudioMenuItem(
            value: s,
            label: s == current ? '${formatRate(s)} (current)' : formatRate(s),
            icon: s == current ? Icons.check_rounded : Icons.speed_rounded,
          ),
      ],
    );
    if (picked != null) await guard(() => player.setRate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final minTap = context.layout.minTap;
    return Live<double>(
      stream: player.stream.rate,
      initial: player.state.rate,
      builder: (context, rate) {
        final normal = (rate - 1).abs() < 0.001;
        return Semantics(
          button: true,
          label: 'Playback speed',
          value: formatRate(rate),
          excludeSemantics: true,
          onTap: () => _pick(context, rate),
          child: Tooltip(
            message: 'Playback speed',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _pick(context, rate),
                customBorder: Tokens.squircle(Tokens.rSm),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: minTap,
                    minHeight: minTap,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.s6,
                      ),
                      child: Text(
                        formatRate(rate),
                        style: Tokens.numeric.copyWith(
                          color: normal ? Tokens.fg : Tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
