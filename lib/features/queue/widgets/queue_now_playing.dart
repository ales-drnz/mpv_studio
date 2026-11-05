import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/focus_ring.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../util/duration_format.dart';
import '../../../util/reactive.dart';
import '../../now_playing/widgets/cover_art.dart';
import '../queue_details.dart';

/// The third column of a wide Queue: the entry that plays, with its cover
/// and where it stands, and the next ones, which a tap plays.
class QueueNowPlaying extends StatelessWidget {
  const QueueNowPlaying({
    super.key,
    required this.player,
    required this.details,
    required this.playlist,
    required this.onJump,
  });

  final PlayerApi player;
  final QueueDetails details;
  final Playlist playlist;
  final ValueChanged<int> onJump;

  /// How many entries Up next lists.
  static const int upNext = 5;

  @override
  Widget build(BuildContext context) {
    final index = playlist.index;
    final items = playlist.items;
    QueueRowInfo info(int i) =>
        QueueRowInfo.of(items[i], details.details.value[items[i]]);
    return ListenableBuilder(
      listenable: details.details,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Now playing'),
          Container(
            padding: const EdgeInsets.all(Tokens.s16),
            decoration: ShapeDecoration(
              color: Tokens.surface,
              shape: Tokens.shape(Tokens.rLg),
            ),
            child: index < 0 || index >= items.length
                ? Text(
                    'Nothing playing',
                    style: Tokens.body.copyWith(color: Tokens.fgDim),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) => Center(
                          child: CoverArtView(
                            player: player,
                            size: c.maxWidth,
                            radius: Tokens.rMd,
                          ),
                        ),
                      ),
                      const SizedBox(height: Tokens.s12),
                      Text(
                        info(index).title,
                        style: Tokens.heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (info(index).artist case final artist?)
                        Text(
                          artist,
                          style: Tokens.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: Tokens.s12),
                      _Progress(player: player),
                    ],
                  ),
          ),
          if (index + 1 < items.length) ...[
            const SizedBox(height: Tokens.s24),
            const SectionHeader('Up next'),
            for (
              var i = index + 1;
              i < items.length && i <= index + upNext;
              i++
            )
              _NextRow(info: info(i), onTap: () => onJump(i)),
          ],
        ],
      ),
    );
  }
}

/// Where the current entry stands: a thin bar and the times.
class _Progress extends StatelessWidget {
  const _Progress({required this.player});

  final PlayerApi player;

  @override
  Widget build(BuildContext context) => Live<Duration>(
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.rPill),
              child: LinearProgressIndicator(
                value: f,
                minHeight: Tokens.progressH,
              ),
            ),
            const SizedBox(height: Tokens.s4),
            Row(
              children: [
                Text(formatDuration(position), style: Tokens.numeric),
                const Spacer(),
                Text(
                  total <= 0 ? 'live' : formatDuration(duration),
                  style: Tokens.numeric,
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.info, required this.onTap});

  final QueueRowInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s4),
    child: Material(
      color: Tokens.surface,
      shape: Tokens.shape(Tokens.rMd),
      child: FocusRing(
        shape: Tokens.shape(Tokens.rMd),
        inside: true,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.shape(Tokens.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s16,
              vertical: Tokens.s12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: Tokens.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (info.artist case final artist?)
                        Text(
                          artist,
                          style: Tokens.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (info.duration case final d?) ...[
                  const SizedBox(width: Tokens.s8),
                  Text(formatDuration(d), style: Tokens.numeric),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
