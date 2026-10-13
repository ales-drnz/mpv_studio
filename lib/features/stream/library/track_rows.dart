import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../favorites_controller.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import '../widgets/stream_row.dart';
import 'server_cover.dart';

/// [track] of [server] as a queue entry played with [options]. The extras
/// carry the tags the queue shows before the stream's own load, the
/// segment container mpv cannot report, and the `serverId` and `server`
/// keys the app-level PlaybackReporter routes its reports by (Now Playing,
/// progress, scrobble, the lock-screen like), plus what the server needs to
/// resolve the entry later ([MediaServer.mediaExtras]).
Media serverMedia(
  MediaServer server,
  ServerTrack track,
  StreamOptions options, {
  required bool isFavorite,
}) => Media(
  server.streamUrl(track, options),
  demuxerLavfOptions: server.demuxerLavfOptions(options),
  extras: {
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    if (track.duration > Duration.zero)
      'durationMs': track.duration.inMilliseconds,
    'art': ?track.artUrl,
    'segment': ?server.segmentContainer(options),
    'serverId': track.id,
    'server': server.kind.name,
    'isFavorite': isFavorite,
    ...server.mediaExtras(track, options),
  },
);

/// The playing entry's `(serverId, server)` extras, or empty strings when
/// nothing server-backed plays. Rows match on the id, not the title, so two
/// songs with the same title never both light up, and on the server so a
/// Jellyfin id never matches a Plex row.
(String, String) currentServerTrack(Playlist pl) {
  if (pl.index < 0 || pl.index >= pl.items.length) return ('', '');
  final ex = pl.items[pl.index].extras;
  return ((ex?['serverId'] as String?) ?? '', (ex?['server'] as String?) ?? '');
}

/// `m:ss`, or `h:mm:ss` from an hour up.
String formatTrackLength(Duration d) {
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
  return '${d.inMinutes}:$s';
}

/// A server track row: title over artist and album, the favourite star and
/// the length, and the context menu (play now, play next, add to queue,
/// favourite).
class ServerTrackRow extends StatelessWidget {
  const ServerTrackRow({
    super.key,
    required this.track,
    required this.kind,
    required this.favorites,
    required this.current,
    required this.onTap,
    required this.onAction,
    this.showAlbum = true,
  });

  final ServerTrack track;
  final ServerKind kind;
  final FavoritesController favorites;
  final bool current;
  final VoidCallback onTap;

  /// Runs a context menu action on this track (the favourite toggles
  /// included).
  final ValueChanged<RowAction> onAction;

  /// Whether the subtitle names the album (not inside an album's own list).
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final sub = [
      track.artist,
      if (showAlbum) track.album,
    ].where((e) => e.isNotEmpty).join(', ');
    return StreamRow(
      title: track.title,
      subtitle: sub,
      leading: ServerCover(
        url: track.artUrl,
        radius: Tokens.rPill,
        placeholderIcon: Icons.music_note_rounded,
      ),
      current: current,
      onTap: onTap,
      menu: () {
        final fav = favorites.resolved(kind, track.id, track.isFavorite);
        return [
          for (final a in RowAction.queueActions) a.item,
          (fav ? RowAction.unfavorite : RowAction.favorite).item,
        ];
      },
      onMenu: onAction,
      trailing: [
        FavoriteButton(
          favorites: favorites,
          kind: kind,
          track: track,
          onToggle: onAction,
        ),
        if (track.duration > Duration.zero)
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: Tokens.s8),
              child: Text(
                formatTrackLength(track.duration),
                style: Tokens.numeric.copyWith(
                  color: StreamRow.onCurrent(context)
                      ? Tokens.onAccentContainer
                      : Tokens.fgDim,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The favourite star of a track. Rebuilds off the shared
/// [FavoritesController], so a toggle from the lock screen or another row
/// shows at once.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.favorites,
    required this.kind,
    required this.track,
    required this.onToggle,
  });

  final FavoritesController favorites;
  final ServerKind kind;
  final ServerTrack track;

  /// Gets [RowAction.favorite] or [RowAction.unfavorite].
  final ValueChanged<RowAction> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        final fav = favorites.resolved(kind, track.id, track.isFavorite);
        return RowButton(
          icon: fav ? Icons.star_rounded : Icons.star_border_rounded,
          tooltip: fav ? 'Unfavorite' : 'Favorite',
          selected: fav,
          onPressed: () =>
              onToggle(fav ? RowAction.unfavorite : RowAction.favorite),
        );
      },
    );
  }
}
