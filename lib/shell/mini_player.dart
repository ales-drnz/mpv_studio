import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../studio/fx_bypass.dart';
import '../ui/tokens.dart';
import '../util/duration_format.dart';
import '../util/reactive.dart';

/// The persistent mini-player shown on every section but Playback: cover,
/// title and artist, play and pause bound to `playWhenReady`, next, a thin
/// seekable progress bar, a loading and buffering indicator from
/// `playbackState`, and the FX bypass toggle.
///
/// [compact] trims it for the mobile shell, where it sits above the tab
/// bar. [onOpen] (tapping the cover or the title) goes to Playback.
class MiniPlayer extends StatelessWidget {
  final PlayerApi player;
  final FxBypass? bypass;
  final VoidCallback? onOpen;
  final bool compact;

  const MiniPlayer({
    super.key,
    required this.player,
    this.bypass,
    this.onOpen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cover = compact ? 40.0 : 44.0;
    return Material(
      color: Tokens.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Tokens.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MiniProgressBar(player: player),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? Tokens.s12 : Tokens.s16,
                compact ? Tokens.s6 : Tokens.s8,
                compact ? Tokens.s4 : Tokens.s12,
                compact ? Tokens.s6 : Tokens.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: onOpen != null,
                      hint: onOpen != null ? 'Open Playback' : null,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onOpen,
                          customBorder: Tokens.squircle(Tokens.rSm),
                          child: Row(
                            children: [
                              _MiniCover(player: player, size: cover),
                              const SizedBox(width: Tokens.s12),
                              Expanded(child: _MiniTitle(player: player)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Tokens.s8),
                  if (bypass != null) ...[
                    FxBypassToggle(
                      player: player,
                      bypass: bypass!,
                      compact: compact,
                    ),
                    SizedBox(width: compact ? Tokens.s2 : Tokens.s8),
                  ],
                  _PlayPause(player: player),
                  _MiniGlyph(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next',
                    onTap: player.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin progress line along the top edge of the mini-player. Tap or
/// drag anywhere on it to seek; the hit area is taller than the line.
class MiniProgressBar extends StatelessWidget {
  final PlayerApi player;
  const MiniProgressBar({super.key, required this.player});

  static const double _hit = 14;

  static String _of(Duration at, Duration total) {
    final clamped =
        at < Duration.zero ? Duration.zero : (at > total ? total : at);
    return '${formatDuration(clamped)} of ${formatDuration(total)}';
  }

  void _seekAt(double dx, double width, Duration duration) {
    if (width <= 0 || duration <= Duration.zero) return;
    final f = (dx / width).clamp(0.0, 1.0);
    player.seek(duration * f);
  }

  @override
  Widget build(BuildContext context) {
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
                ? () => player.seek(const Duration(seconds: 5), relative: true)
                : null,
            onDecrease: seekable
                ? () => player.seek(const Duration(seconds: -5), relative: true)
                : null,
            child: Tooltip(
              message: seekable
                  ? '${formatDuration(position)} / ${formatDuration(duration)}'
                  : 'Nothing to seek',
              waitDuration: const Duration(milliseconds: 600),
              child: LayoutBuilder(
                builder: (context, c) => MouseRegion(
                  cursor: seekable
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _seekAt(d.localPosition.dx, c.maxWidth, duration),
                    onHorizontalDragUpdate: (d) =>
                        _seekAt(d.localPosition.dx, c.maxWidth, duration),
                    child: SizedBox(
                      key: const ValueKey('mini-progress'),
                      height: _hit,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ColoredBox(color: Tokens.line2),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: f,
                                child: const ColoredBox(color: Tokens.accent),
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
          );
        },
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  final PlayerApi player;
  final double size;
  const _MiniCover({required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Tokens.surface2,
      child: Center(
        child: Icon(Icons.music_note_rounded, size: 20, color: Tokens.fgFaint),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: Tokens.squircle(Tokens.rSm)),
          child: Live<Playlist>(
            stream: player.stream.playlist,
            initial: player.state.playlist,
            builder: (context, pl) => Live<CoverArt?>(
              stream: player.stream.coverArt,
              initial: player.state.coverArt,
              builder: (context, art) {
                if (art != null) {
                  return Image.memory(
                    art.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => placeholder,
                  );
                }
                final url = nowPlayingExtra(pl, 'art');
                if (url != null) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => placeholder,
                  );
                }
                return placeholder;
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A non-empty string [key] from the current queue item's extras.
String? nowPlayingExtra(Playlist pl, String key) {
  if (pl.index < 0 || pl.index >= pl.items.length) return null;
  final v = pl.items[pl.index].extras?[key];
  return (v is String && v.isNotEmpty) ? v : null;
}

String? _tag(Map<String, String> m, String key) {
  for (final e in m.entries) {
    if (e.key.toLowerCase() == key) return e.value;
  }
  return null;
}

class _MiniTitle extends StatelessWidget {
  final PlayerApi player;
  const _MiniTitle({required this.player});

  @override
  Widget build(BuildContext context) {
    return Live<Playlist>(
      stream: player.stream.playlist,
      initial: player.state.playlist,
      builder: (context, pl) => Live<Map<String, String>>(
        stream: player.stream.metadata,
        initial: player.state.metadata,
        builder: (context, meta) => Live<String>(
          stream: player.stream.mediaTitle,
          initial: player.state.mediaTitle,
          builder: (context, mediaTitle) {
            final title = _tag(meta, 'title') ??
                nowPlayingExtra(pl, 'title') ??
                (mediaTitle.isNotEmpty ? mediaTitle : 'Nothing playing');
            final artist =
                _tag(meta, 'artist') ?? nowPlayingExtra(pl, 'artist');
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (artist != null)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.label,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Play and pause, bound to `playWhenReady`, ringed by a spinner while
/// `playbackState` is loading or buffering.
class _PlayPause extends StatelessWidget {
  final PlayerApi player;
  const _PlayPause({required this.player});

  @override
  Widget build(BuildContext context) {
    return Live<MpvPlaybackState>(
      stream: player.stream.playbackState,
      initial: MpvPlaybackState.idle,
      builder: (context, phase) => Live<bool>(
        stream: player.stream.playWhenReady,
        initial: player.state.playWhenReady,
        builder: (context, wants) {
          final waiting = phase == MpvPlaybackState.loading ||
              phase == MpvPlaybackState.buffering;
          final stateLabel = switch (phase) {
            MpvPlaybackState.loading => 'Loading',
            MpvPlaybackState.buffering => 'Buffering',
            _ => null,
          };
          final action = wants ? 'Pause' : 'Play';
          return Semantics(
            button: true,
            label: action,
            value: stateLabel,
            excludeSemantics: true,
            onTap: () => wants ? player.pause() : player.play(),
            child: Tooltip(
              message: stateLabel == null ? action : '$action ($stateLabel)',
              child: SizedBox.square(
                dimension: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (waiting)
                      const SizedBox.square(
                        key: ValueKey('mini-waiting'),
                        dimension: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Tokens.accent,
                          backgroundColor: Tokens.line,
                        ),
                      ),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => wants ? player.pause() : player.play(),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Tokens.accent,
                          ),
                          child: Icon(
                            wants
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                            color: Tokens.onAccent,
                          ),
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

class _MiniGlyph extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniGlyph({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s8),
              child: Icon(icon, size: 24, color: Tokens.fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// The before and after switch: bypasses the effects chain through
/// [FxBypass] and restores it on the second tap. Disabled when no stage
/// is switched on and nothing is bypassed.
class FxBypassToggle extends StatelessWidget {
  final PlayerApi player;
  final FxBypass bypass;
  final bool compact;

  const FxBypassToggle({
    super.key,
    required this.player,
    required this.bypass,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bypass,
      builder: (context, _) => Live<List<AudioEffect>>(
        stream: player.stream.audioEffects,
        initial: player.state.audioEffects,
        builder: (context, chain) {
          final on = bypass.active;
          final enabled = on || FxBypass.hasActiveStages(chain);
          final tip = on
              ? 'FX bypassed. Tap to restore the chain'
              : enabled
                  ? 'Bypass FX to compare before and after'
                  : 'No effects to bypass';
          final color =
              on ? Tokens.amber : (enabled ? Tokens.fgDim : Tokens.fgFaint);
          return Semantics(
            button: true,
            toggled: on,
            enabled: enabled,
            label: 'Bypass FX',
            excludeSemantics: true,
            onTap: enabled ? bypass.toggle : null,
            child: Tooltip(
              message: tip,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: enabled ? bypass.toggle : null,
                  customBorder: Tokens.squircle(Tokens.rSm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? Tokens.s6 : Tokens.s8,
                      vertical: Tokens.s6,
                    ),
                    decoration: ShapeDecoration(
                      color: on
                          ? Tokens.amber.withValues(alpha: 0.16)
                          : Colors.transparent,
                      shape: Tokens.squircle(
                        Tokens.rSm,
                        side: BorderSide(
                          color: on ? Colors.transparent : Tokens.line2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          on
                              ? Icons.layers_clear_rounded
                              : Icons.layers_rounded,
                          size: 16,
                          color: color,
                        ),
                        if (!compact) ...[
                          const SizedBox(width: Tokens.s6),
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
          );
        },
      ),
    );
  }
}
