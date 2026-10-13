import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../util/reactive.dart';

/// The queue entry mpv is on, or null when there is none.
Media? currentMedia(Playlist pl) =>
    pl.index >= 0 && pl.index < pl.items.length ? pl.items[pl.index] : null;

/// A non-empty string [key] from the current queue entry's extras.
String? currentExtra(Playlist pl, String key) {
  final v = currentMedia(pl)?.extras?[key];
  return (v is String && v.isNotEmpty) ? v : null;
}

/// The value of tag [key] in [tags], matched without regard to case.
String? tagOf(Map<String, String> tags, String key) {
  for (final e in tags.entries) {
    if (e.key.toLowerCase() == key && e.value.isNotEmpty) return e.value;
  }
  return null;
}

/// What to call the current track: mpv's own tags first, then the extras
/// the queue entry was added with (server tracks streamed through a
/// transcode carry no tags), then mpv's media title.
@immutable
class TrackIdentity {
  const TrackIdentity({this.title, this.artist, this.album});

  /// Reads the identity from the player's current values.
  factory TrackIdentity.of({
    required Playlist playlist,
    required Map<String, String> metadata,
    required String mediaTitle,
  }) => TrackIdentity(
    title:
        tagOf(metadata, 'title') ??
        currentExtra(playlist, 'title') ??
        (mediaTitle.isNotEmpty ? mediaTitle : null),
    artist: tagOf(metadata, 'artist') ?? currentExtra(playlist, 'artist'),
    album: tagOf(metadata, 'album') ?? currentExtra(playlist, 'album'),
  );

  final String? title;
  final String? artist;
  final String? album;

  /// The title, or "Nothing playing".
  String get displayTitle => title ?? 'Nothing playing';

  /// Artist and album joined, or null when neither is known.
  String? subtitle({String separator = ' · '}) {
    final parts = [artist, album].whereType<String>();
    return parts.isEmpty ? null : parts.join(separator);
  }
}

/// Rebuilds [builder] with the current [TrackIdentity] of [player].
class LiveTrackIdentity extends StatelessWidget {
  const LiveTrackIdentity({
    super.key,
    required this.player,
    required this.builder,
  });

  final PlayerApi player;
  final Widget Function(BuildContext context, TrackIdentity identity) builder;

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
          builder: (context, mediaTitle) => builder(
            context,
            TrackIdentity.of(
              playlist: pl,
              metadata: meta,
              mediaTitle: mediaTitle,
            ),
          ),
        ),
      ),
    );
  }
}
