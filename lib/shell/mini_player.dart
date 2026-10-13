import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/effects/rack_controller.dart';
import '../features/now_playing/track_identity.dart';
import '../features/now_playing/transport_actions.dart';
import '../features/now_playing/widgets/cover_art.dart';
import '../features/now_playing/widgets/transport_controls.dart'
    show PlaybackBusy;
import '../studio/playback_issues.dart';
import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import '../ui/widgets/round_icon_button.dart';
import '../util/duration_format.dart';
import '../util/reactive.dart';

/// The persistent mini-player shown on every section but Playback: cover,
/// title and artist, play and pause bound to `playWhenReady`, previous and
/// next, a thin seekable progress bar, a ring while the track loads,
/// buffers or seeks, and the FX bypass toggle of the effects [rack].
///
/// [variant] fits it to the shell: a full [MiniPlayerVariant.bar] under
/// the sidebar or the rail, a trimmed [MiniPlayerVariant.compact] bar above
/// the phone tab bar, or a vertical [MiniPlayerVariant.rail] stack at the
/// foot of the navigation rail on low windows. Tapping the cover or the
/// title calls [onOpen] (Playback). On touch, a swipe left or right on
/// them goes to the next or previous track and a swipe up opens Playback;
/// with a pointer they light up on hover and a right-click opens a menu.
/// Next and previous say so at either end of the queue. The player calls
/// run through [guard]; the shell owns the safe-area insets around it.
class MiniPlayer extends StatelessWidget {
  final PlayerApi player;
  final RackController? rack;
  final VoidCallback? onOpen;
  final MiniPlayerVariant variant;
  final CallGuard guard;

  const MiniPlayer({
    super.key,
    required this.player,
    this.rack,
    this.onOpen,
    this.variant = MiniPlayerVariant.bar,
    this.guard = unguarded,
  });

  /// The swipe speed, in logical pixels per second, that counts as a
  /// swipe rather than a slow drag.
  static const double _swipeVelocity = 300;

  void _skip(BuildContext context, {required bool forward}) =>
      skipTrack(player, guard, forward: forward, notify: feedbackFor(context));

  Future<void> _menu(BuildContext context, Offset position) async {
    final s = player.state;
    final picked = await showStudioMenu<_MiniAction>(
      context,
      position: position,
      title: 'Playback',
      items: [
        if (onOpen != null)
          const StudioMenuItem(
            value: _MiniAction.open,
            label: 'Open Playback',
            icon: Icons.open_in_full_rounded,
          ),
        StudioMenuItem(
          value: _MiniAction.playPause,
          label: s.playWhenReady ? 'Pause' : 'Play',
          icon: s.playWhenReady
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
        ),
        const StudioMenuItem(
          value: _MiniAction.previous,
          label: 'Previous track',
          icon: Icons.skip_previous_rounded,
        ),
        const StudioMenuItem(
          value: _MiniAction.next,
          label: 'Next track',
          icon: Icons.skip_next_rounded,
        ),
        StudioMenuItem(
          value: _MiniAction.mute,
          label: s.mute ? 'Unmute' : 'Mute',
          icon: s.mute ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        ),
        const StudioMenuItem(
          value: _MiniAction.stop,
          label: 'Stop',
          icon: Icons.stop_rounded,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case null:
        return;
      case _MiniAction.open:
        onOpen?.call();
      case _MiniAction.playPause:
        await togglePlay(player, guard);
      case _MiniAction.previous:
        _skip(context, forward: false);
      case _MiniAction.next:
        _skip(context, forward: true);
      case _MiniAction.mute:
        await guard(() => player.setMute(!s.mute));
      case _MiniAction.stop:
        await guard(player.stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variant == MiniPlayerVariant.rail) {
      return _RailMini(
        player: player,
        guard: guard,
        onNext: () => _skip(context, forward: true),
      );
    }
    final compact = variant == MiniPlayerVariant.compact;
    final touch = context.layout.isTouch;
    // Shape contrast: a round cover (the logo's disc), a large accent
    // circle for play, smaller tonal circles for the rest.
    final cover = compact ? 40.0 : 48.0;
    final info = Row(
      children: [
        ExcludeSemantics(
          child: CoverArtView(
            player: player,
            size: cover,
            radius: Tokens.rPill,
          ),
        ),
        const SizedBox(width: Tokens.s12),
        Expanded(child: _MiniTitle(player: player)),
      ],
    );
    final infoArea = GestureDetector(
      key: const ValueKey('mini-info'),
      onSecondaryTapUp: (d) => _menu(context, d.globalPosition),
      onLongPressStart: (d) => _menu(context, d.globalPosition),
      onHorizontalDragEnd: touch
          ? (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < _swipeVelocity) return;
              _skip(context, forward: v < 0);
            }
          : null,
      onVerticalDragEnd: touch && onOpen != null
          ? (d) {
              if ((d.primaryVelocity ?? 0) < -_swipeVelocity) onOpen!();
            }
          : null,
      child: Semantics(
        button: onOpen != null,
        hint: onOpen != null ? 'Open Playback' : null,
        onTap: onOpen,
        child: _OpenTooltip(
          enabled: onOpen != null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpen,
              customBorder: Tokens.pill,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: context.layout.minTap),
                child: info,
              ),
            ),
          ),
        ),
      ),
    );

    if (compact) {
      // A floating card (the card tone) above the tab bar, 8 from the
      // screen edges and the bar, its progress a slim pill along its foot.
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s8,
          Tokens.s8,
          Tokens.s8,
          Tokens.s8,
        ),
        child: Material(
          color: Tokens.surface,
          shape: Tokens.shape(Tokens.rLg),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s8,
              Tokens.s8,
              Tokens.s8,
              Tokens.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: infoArea),
                    const SizedBox(width: Tokens.s4),
                    if (rack != null)
                      FxBypassToggle(rack: rack!, compact: true),
                    _PlayPause(player: player, guard: guard),
                    RoundIconButton(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Next',
                      onTap: () => _skip(context, forward: true),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
                  child: MiniProgressBar(player: player, guard: guard),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // The bar: info on the left, the transport in the centre, the time
    // and the progress with the FX switch on the right, on the chrome.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s16,
          0,
          Tokens.s16,
          Tokens.s8,
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(flex: 4, child: infoArea),
              const SizedBox(width: Tokens.s16),
              RoundIconButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous',
                tone: RoundTone.tonal,
                diameter: 40,
                onTap: () => _skip(context, forward: false),
              ),
              const SizedBox(width: Tokens.s8),
              _PlayPause(player: player, guard: guard),
              const SizedBox(width: Tokens.s8),
              RoundIconButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Next',
                tone: RoundTone.tonal,
                diameter: 40,
                onTap: () => _skip(context, forward: true),
              ),
              const SizedBox(width: Tokens.s16),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: _TimedProgress(player: player, guard: guard),
                    ),
                    if (rack != null) ...[
                      const SizedBox(width: Tokens.s16),
                      FxBypassToggle(rack: rack!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Position, the progress pill and the length, in a row.
class _TimedProgress extends StatelessWidget {
  const _TimedProgress({required this.player, required this.guard});

  final PlayerApi player;
  final CallGuard guard;

  @override
  Widget build(BuildContext context) {
    final style = Tokens.numeric.copyWith(fontSize: 11);
    return Row(
      children: [
        Live<Duration>(
          stream: player.stream.position,
          initial: player.state.position,
          builder: (context, p) => Text(formatDuration(p), style: style),
        ),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: MiniProgressBar(player: player, guard: guard),
        ),
        const SizedBox(width: Tokens.s12),
        Live<Duration>(
          stream: player.stream.duration,
          initial: player.state.duration,
          builder: (context, d) => Text(formatDuration(d), style: style),
        ),
      ],
    );
  }
}

enum _MiniAction { open, playPause, previous, next, mute, stop }

/// "Open Playback" on hover, when the title opens it.
class _OpenTooltip extends StatelessWidget {
  const _OpenTooltip({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? Tooltip(
          message: 'Open Playback',
          waitDuration: const Duration(milliseconds: 600),
          child: child,
        )
      : child;
}

/// The shapes of the [MiniPlayer].
enum MiniPlayerVariant {
  /// A full-width bar: cover, title, FX toggle, previous, play and next.
  bar,

  /// The bar trimmed for a phone: smaller cover, icon-only FX toggle, no
  /// previous button (swipe right on the title instead).
  compact,

  /// A narrow vertical stack for the navigation rail: play and pause ringed
  /// by the progress, and next.
  rail,
}

/// The rail mini-player: play and pause inside a ring that shows the
/// progress (or spins while waiting), then next.
class _RailMini extends StatelessWidget {
  final PlayerApi player;
  final CallGuard guard;
  final VoidCallback onNext;
  const _RailMini({
    required this.player,
    required this.guard,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Live<Duration>(
          stream: player.stream.duration,
          initial: player.state.duration,
          builder: (context, duration) => Live<Duration>(
            stream: player.stream.position,
            initial: player.state.position,
            builder: (context, position) {
              final total = duration.inMilliseconds;
              final f = total <= 0
                  ? 0.0
                  : (position.inMilliseconds / total).clamp(0.0, 1.0);
              return _PlayPause(player: player, guard: guard, progress: f);
            },
          ),
        ),
        RoundIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next',
          onTap: onNext,
        ),
      ],
    );
  }
}

/// A slim progress pill of the mini-player. With a pointer, a click or
/// drag anywhere on it seeks (the hit area is taller than the pill). On
/// touch it only shows the progress: a strip this thin is no tap target
/// and sits next to the swipe area, so seeking is left to Playback and to
/// the screen reader's increase and decrease actions.
class MiniProgressBar extends StatelessWidget {
  final PlayerApi player;
  final CallGuard guard;
  const MiniProgressBar({
    super.key,
    required this.player,
    this.guard = unguarded,
  });

  static const double _hit = 16;

  static String _of(Duration at, Duration total) {
    final clamped = at < Duration.zero
        ? Duration.zero
        : (at > total ? total : at);
    return '${formatDuration(clamped)} of ${formatDuration(total)}';
  }

  void _seekAt(double dx, double width, Duration duration) {
    if (width <= 0 || duration <= Duration.zero) return;
    final f = (dx / width).clamp(0.0, 1.0);
    guard(() => player.seek(duration * f));
  }

  @override
  Widget build(BuildContext context) {
    final touch = context.layout.isTouch;
    return Live<Duration>(
      stream: player.stream.duration,
      initial: player.state.duration,
      builder: (context, duration) => Live<Duration>(
        stream: player.stream.position,
        initial: player.state.position,
        builder: (context, position) {
          final total = duration.inMilliseconds;
          final f = total <= 0
              ? 0.0
              : (position.inMilliseconds / total).clamp(0.0, 1.0);
          final seekable = total > 0;
          return Semantics(
            slider: true,
            label: 'Seek',
            value: seekable
                ? '${formatDuration(position)} of ${formatDuration(duration)}'
                : 'Not seekable',
            increasedValue: seekable
                ? _of(position + const Duration(seconds: 5), duration)
                : null,
            decreasedValue: seekable
                ? _of(position - const Duration(seconds: 5), duration)
                : null,
            onIncrease: seekable
                ? () => guard(
                    () =>
                        player.seek(const Duration(seconds: 5), relative: true),
                  )
                : null,
            onDecrease: seekable
                ? () => guard(
                    () => player.seek(
                      const Duration(seconds: -5),
                      relative: true,
                    ),
                  )
                : null,
            child: Tooltip(
              message: seekable
                  ? '${formatDuration(position)} of ${formatDuration(duration)}'
                  : 'Nothing to seek',
              waitDuration: const Duration(milliseconds: 600),
              child: LayoutBuilder(
                builder: (context, c) => MouseRegion(
                  cursor: seekable && !touch
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: touch
                        ? null
                        : (d) =>
                              _seekAt(d.localPosition.dx, c.maxWidth, duration),
                    onHorizontalDragUpdate: touch
                        ? null
                        : (d) =>
                              _seekAt(d.localPosition.dx, c.maxWidth, duration),
                    child: SizedBox(
                      key: const ValueKey('mini-progress'),
                      height: _hit,
                      child: Center(
                        child: SizedBox(
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(color: Tokens.surface4),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: f,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: Tokens.accent,
                                      shape: Tokens.pill,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _MiniTitle extends StatelessWidget {
  final PlayerApi player;
  const _MiniTitle({required this.player});

  @override
  Widget build(BuildContext context) {
    return LiveTrackIdentity(
      player: player,
      builder: (context, id) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            id.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (id.artist case final artist?)
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tokens.label,
            ),
        ],
      ),
    );
  }
}

/// Play and pause, bound to `playWhenReady`, ringed by a spinner while the
/// track loads, buffers or seeks.
class _PlayPause extends StatelessWidget {
  final PlayerApi player;
  final CallGuard guard;

  /// When set, a ring around the button shows this much progress.
  final double? progress;
  const _PlayPause({required this.player, required this.guard, this.progress});

  @override
  Widget build(BuildContext context) {
    return PlaybackBusy(
      player: player,
      builder: (context, wait) => Live<bool>(
        stream: player.stream.playWhenReady,
        initial: player.state.playWhenReady,
        builder: (context, wants) {
          final action = wants ? 'Pause' : 'Play';
          const dimension = 48.0;
          void onTap() => guard(wants ? player.pause : player.play);
          return Semantics(
            button: true,
            label: action,
            value: wait?.label,
            excludeSemantics: true,
            onTap: onTap,
            child: Tooltip(
              message: wait == null ? action : '$action (${wait.label})',
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: dimension,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (wait != null)
                          SizedBox.square(
                            key: const ValueKey('mini-waiting'),
                            dimension: dimension - 2,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Tokens.accent,
                              backgroundColor: Tokens.surface4,
                            ),
                          )
                        else if (progress != null)
                          SizedBox.square(
                            dimension: dimension - 2,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2,
                              color: Tokens.accent,
                              backgroundColor: Tokens.surface4,
                            ),
                          ),
                        Container(
                          width: dimension - 8,
                          height: dimension - 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Tokens.accent,
                          ),
                          child: Icon(
                            wants
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 24,
                            color: Tokens.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The before and after switch: the rack's global bypass, the same one
/// as on the Effects page. Disabled when no stage but the meter is
/// switched on and nothing is bypassed.
class FxBypassToggle extends StatelessWidget {
  final RackController rack;
  final bool compact;

  const FxBypassToggle({super.key, required this.rack, this.compact = false});

  void _toggle() => rack.setBypass(!rack.bypass);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rack,
      builder: (context, _) {
        final on = rack.bypass;
        final enabled = rack.canBypass;
        final tip = on
            ? 'FX bypassed. Tap to restore the chain'
            : enabled
            ? 'Bypass FX to compare before and after'
            : 'No effects to bypass';
        final color = on
            ? Tokens.amber
            : (enabled ? Tokens.fgDim : Tokens.fgFaint);
        return Semantics(
          button: true,
          toggled: on,
          enabled: enabled,
          label: 'Bypass FX',
          excludeSemantics: true,
          onTap: enabled ? _toggle : null,
          child: Tooltip(
            message: tip,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: enabled ? _toggle : null,
                customBorder: Tokens.pill,
                // The pill stays small; the tap area grows to a full target.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: context.layout.minTap,
                    minHeight: context.layout.minTap,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? Tokens.s8 : Tokens.s12,
                        vertical: Tokens.s8,
                      ),
                      decoration: ShapeDecoration(
                        color: on
                            ? Tokens.amber.withValues(alpha: 0.18)
                            : (compact ? Colors.transparent : Tokens.surface3),
                        shape: Tokens.pill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            on
                                ? Icons.layers_clear_rounded
                                : Icons.layers_rounded,
                            size: compact ? 20 : 18,
                            color: color,
                          ),
                          if (!compact) ...[
                            const SizedBox(width: Tokens.s8),
                            Text(
                              on ? 'Dry' : 'FX',
                              style: Tokens.label.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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
