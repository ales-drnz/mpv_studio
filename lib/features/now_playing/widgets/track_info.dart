import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';

/// Title + artist/album line. Prefers mpv's own tags (`metadata`), then
/// falls back to the current queue item's `extras` — so server tracks
/// streamed via transcoding (which carry no embedded metadata) still show
/// their name/artist/album, taken from what we queued.
class TrackInfo extends StatelessWidget {
  /// Centre the text (stacked layout) or left-align it (side strip).
  final bool centered;
  const TrackInfo({super.key, this.centered = true});

  static String? _lookup(Map<String, String> m, String key) {
    for (final e in m.entries) {
      if (e.key.toLowerCase() == key) return e.value;
    }
    return null;
  }

  /// A non-empty string [key] from the currently-playing queue item's extras.
  static String? _extra(Playlist pl, String key) {
    if (pl.items.isEmpty || pl.index < 0 || pl.index >= pl.items.length) {
      return null;
    }
    final v = pl.items[pl.index].extras?[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
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
            final title =
                _lookup(meta, 'title') ??
                _extra(pl, 'title') ??
                (mediaTitle.isNotEmpty ? mediaTitle : 'Nothing playing');
            final artist = _lookup(meta, 'artist') ?? _extra(pl, 'artist');
            final album = _lookup(meta, 'album') ?? _extra(pl, 'album');
            final sub = [artist, album].whereType<String>().join(' · ');
            final align = centered ? TextAlign.center : TextAlign.start;
            return Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Tokens.title,
                  textAlign: align,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s4),
                  Text(
                    sub,
                    style: Tokens.label,
                    textAlign: align,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
