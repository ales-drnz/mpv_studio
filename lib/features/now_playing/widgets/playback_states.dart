import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
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
    return Center(
      child: SingleChildScrollView(
        // Centred, so as far from the top as from the page end.
        padding: EdgeInsets.symmetric(vertical: PageEnd.of(context)),
        child: ReadableWidth(
          maxWidth: Breakpoints.medium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: ShapeDecoration(
                  color: Tokens.tonal,
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 44,
                  color: Tokens.fg,
                ),
              ),
              const SizedBox(height: Tokens.s24),
              Semantics(
                header: true,
                child: Text(
                  'Nothing playing',
                  style: Tokens.display,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Tokens.s8),
              Text(
                queued
                    ? 'The queue is ready. Play it, or add more to listen to.'
                    : 'Open audio files from this device, or go to Stream '
                          'for a URL, a radio station or a media server.',
                style: Tokens.body.copyWith(color: Tokens.fgDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.s24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Tokens.s8,
                runSpacing: Tokens.s8,
                // One filled primary: playing the queue when it has
                // entries, else opening files.
                children: [
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
              ),
            ],
          ),
        ),
      ),
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
              title: titleOf(media),
              onRetry: () => scope.guard(() => player.jump(pl.index)),
              onNext: () => skipTrack(
                player,
                scope.guard,
                forward: true,
                notify: feedbackFor(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.onRetry,
    required this.onNext,
  });

  final String title;
  final VoidCallback onRetry;
  final VoidCallback onNext;

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
          color: Tokens.red.withValues(alpha: 0.14),
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
                Icon(Icons.error_outline_rounded, size: 20, color: Tokens.red),
                const SizedBox(width: Tokens.s8),
                Flexible(
                  child: Text(
                    'Could not play "$title".',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.body.copyWith(color: Tokens.red),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onRetry, child: const Text('Retry')),
                TextButton(onPressed: onNext, child: const Text('Next')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
