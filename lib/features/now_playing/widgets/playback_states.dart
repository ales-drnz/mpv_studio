import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../util/media_labels.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../track_identity.dart';
import '../transport_actions.dart';

/// The Playback page with no current track: what to do to start one.
/// [onPlayQueue] is given when the queue has entries but none is playing.
class EmptyPlayback extends StatelessWidget {
  const EmptyPlayback({
    super.key,
    required this.onOpenFiles,
    required this.onOpenStream,
    this.onPlayQueue,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenStream;
  final VoidCallback? onPlayQueue;

  @override
  Widget build(BuildContext context) {
    final queued = onPlayQueue != null;
    return EmptyState(
      icon: Icons.graphic_eq_rounded,
      title: 'Nothing playing',
      message: queued
          ? 'The queue is ready. Play it, or add more to listen to.'
          : 'Open audio files from this device, or go to Stream for a URL, '
                'a radio station or a media server.',
      // One filled primary: playing the queue when it has entries, else
      // opening files.
      actions: [
        if (queued) ...[
          FilledButton.icon(
            onPressed: onPlayQueue,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play the queue'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenFiles,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Open files'),
          ),
        ] else
          FilledButton.icon(
            onPressed: onOpenFiles,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Open files'),
          ),
        OutlinedButton.icon(
          onPressed: onOpenStream,
          icon: const Icon(Icons.podcasts_rounded),
          label: const Text('Go to Stream'),
        ),
      ],
    );
  }
}

/// A banner over the player when the current track failed to play, with
/// Retry and Next. Shows nothing otherwise.
class FailedTrackBanner extends StatelessWidget {
  const FailedTrackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final failed = scope.failed;
    if (failed == null) return const SizedBox.shrink();
    final player = scope.player;
    return ValueListenableBuilder<Set<Media>>(
      valueListenable: failed,
      builder: (context, set, _) => Live<Playlist>(
        stream: player.stream.playlist,
        initial: player.state.playlist,
        builder: (context, pl) {
          final media = currentMedia(pl);
          if (media == null || !set.contains(media)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s12),
            child: _Banner(
              icon: Icons.error_outline_rounded,
              color: Tokens.red,
              message: 'Could not play "${titleOf(media)}".',
              actions: [
                TextButton(
                  onPressed: () => scope.guard(() => player.jump(pl.index)),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => skipTrack(
                    player,
                    scope.guard,
                    forward: true,
                    notify: feedbackFor(context),
                  ),
                  child: const Text('Next'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The banners over the player: a track that failed, a silent output.
class PlaybackBanners extends StatelessWidget {
  const PlaybackBanners({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [FailedTrackBanner(), MutedOutputBanner(), SoundGestureBanner()],
  );
}

/// In a browser, a banner while the page's sound waits for the user's
/// first click or key (MpvAudioKit.needsUserGesture); the next one
/// starts it. Never on the other platforms.
class SoundGestureBanner extends StatelessWidget {
  const SoundGestureBanner({super.key, this.stream, this.initial});

  /// Whether the sound waits; the kit's by default.
  final Stream<bool>? stream;
  final bool? initial;

  @override
  Widget build(BuildContext context) {
    return Live<bool>(
      stream: stream ?? MpvAudioKit.needsUserGestureStream,
      initial: initial ?? MpvAudioKit.needsUserGesture,
      builder: (context, waits) => !waits
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s12),
              child: _Banner(
                icon: Icons.touch_app_rounded,
                color: Tokens.fg,
                message:
                    'Click or press a key: the browser holds the sound '
                    'until you do.',
                actions: const [],
              ),
            ),
    );
  }
}

/// A banner while the engine plays on its null output because no device
/// opened: the position runs and nothing is heard. Not when the null
/// driver was chosen. Reopen output asks the engine to try the device
/// again.
class MutedOutputBanner extends StatelessWidget {
  const MutedOutputBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    return Live<String>(
      stream: player.stream.currentAo,
      initial: player.state.currentAo,
      builder: (context, ao) => Live<String>(
        stream: player.stream.audioDriver,
        initial: player.state.audioDriver,
        builder: (context, driver) {
          if (ao != 'null' || driver == 'null') return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s12),
            child: _Banner(
              icon: Icons.volume_off_rounded,
              color: Tokens.amber,
              message: 'No audio device: playing silently on the null output.',
              actions: [
                TextButton(
                  onPressed: () => scope.guard(player.reloadAudio),
                  child: const Text('Reopen output'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A tinted banner: an icon and a message in [color], then [actions].
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final Color color;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s16,
          Tokens.s4,
          Tokens.s8,
          Tokens.s4,
        ),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: 0.14),
          shape: Tokens.shape(Tokens.rMd),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: Tokens.s8,
          runSpacing: Tokens.s4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: Tokens.iconMd, color: color),
                const SizedBox(width: Tokens.s8),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.body.copyWith(color: color),
                  ),
                ),
              ],
            ),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }
}
