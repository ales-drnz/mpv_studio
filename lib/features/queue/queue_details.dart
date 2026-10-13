import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../util/media_import.dart';
import '../../util/media_labels.dart';

/// What the engine reported about a queue entry once it loaded.
@immutable
class LoadedDetails {
  const LoadedDetails({
    this.title,
    this.mediaTitle,
    this.artist,
    this.duration,
  });

  /// The title tag.
  final String? title;

  /// mpv's media title (a radio stream's current title, for one), when it
  /// says more than the file name.
  final String? mediaTitle;

  /// The artist tag.
  final String? artist;

  /// The length, null for a stream of unknown length.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is LoadedDetails &&
      other.title == title &&
      other.mediaTitle == mediaTitle &&
      other.artist == artist &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(title, mediaTitle, artist, duration);
}

/// The engine state [QueueDetails] reads when the current entry loads.
typedef LoadedSnapshot = ({
  Map<String, String> metadata,
  String mediaTitle,
  Duration duration,
});

/// Remembers, for each queue entry that has played, the title, artist and
/// length the engine read from it, so the Queue can show them for every
/// row and not only for the current one.
///
/// The current entry is read when it is ready to play
/// (`stream.seekCompleted`), and again on each tag, title or length change
/// while it stays loaded (a radio stream changing its title). Entries that
/// leave the queue are forgotten.
class QueueDetails {
  QueueDetails({
    required Stream<Playlist> playlist,
    required Stream<void> loaded,
    required List<Stream<Object?>> changes,
    required LoadedSnapshot Function() snapshot,
  }) : _snapshot = snapshot {
    _subs = [
      playlist.listen(_onPlaylist),
      loaded.listen((_) => _onLoaded()),
      for (final s in changes) s.listen((_) => _onChange()),
    ];
  }

  /// Wires the service to [player]'s streams.
  factory QueueDetails.of(Player player) => QueueDetails(
    playlist: player.stream.playlist,
    loaded: player.stream.seekCompleted,
    changes: [
      player.stream.metadata,
      player.stream.mediaTitle,
      player.stream.duration,
    ],
    snapshot: () => (
      metadata: player.state.metadata,
      mediaTitle: player.state.mediaTitle,
      duration: player.state.duration,
    ),
  );

  final LoadedSnapshot Function() _snapshot;
  late final List<StreamSubscription<Object?>> _subs;

  /// The details known so far, by entry.
  ValueListenable<Map<Media, LoadedDetails>> get details => _details;
  final _details = ValueNotifier<Map<Media, LoadedDetails>>(const {});

  Media? _current;

  /// Whether [_current] has loaded, so the engine state describes it.
  bool _loaded = false;

  void _onPlaylist(Playlist pl) {
    final current = pl.index >= 0 && pl.index < pl.items.length
        ? pl.items[pl.index]
        : null;
    if (current != _current) {
      _current = current;
      _loaded = false;
    }
    final known = _details.value;
    if (known.keys.any((m) => !pl.items.contains(m))) {
      _details.value = {
        for (final e in known.entries)
          if (pl.items.contains(e.key)) e.key: e.value,
      };
    }
  }

  void _onLoaded() {
    if (_current == null) return;
    _loaded = true;
    _record();
  }

  void _onChange() {
    if (_loaded) _record();
  }

  void _record() {
    final entry = _current;
    if (entry == null) return;
    final s = _snapshot();
    final next = LoadedDetails(
      title: tagOf(s.metadata, 'title'),
      mediaTitle: _informative(s.mediaTitle, entry),
      artist: tagOf(s.metadata, 'artist'),
      duration: s.duration > Duration.zero ? s.duration : null,
    );
    if (_details.value[entry] == next) return;
    _details.value = {..._details.value, entry: next};
  }

  /// [mediaTitle] when it is more than the entry's file name, else null.
  static String? _informative(String mediaTitle, Media entry) {
    final t = mediaTitle.trim();
    if (t.isEmpty) return null;
    // Without a title, mpv reports the file name, raw or decoded, with or
    // without its extension.
    final uri = entry.uri;
    final name = nameFromUri(uri);
    final fallbacks = {
      uri,
      uri.substring(uri.lastIndexOf(RegExp(r'[/\\]')) + 1),
      name,
      baseNameNoExt(name),
    };
    return fallbacks.contains(t) || fallbacks.contains(baseNameNoExt(t))
        ? null
        : t;
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _details.dispose();
  }
}

/// The value of tag [key] in [metadata], ignoring case, or null when it is
/// missing or blank.
String? tagOf(Map<String, String> metadata, String key) {
  for (final e in metadata.entries) {
    if (e.key.toLowerCase() == key) {
      final v = e.value.trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}

/// What one queue row shows.
@immutable
class QueueRowInfo {
  const QueueRowInfo({
    required this.title,
    required this.artist,
    required this.origin,
    required this.duration,
    required this.artUrl,
  });

  /// Builds the row for [media] from its extras and, when it has loaded,
  /// the [loaded] details.
  factory QueueRowInfo.of(Media media, LoadedDetails? loaded) {
    final ms = media.extras?['durationMs'];
    final extrasDuration = ms is int && ms > 0
        ? Duration(milliseconds: ms)
        : null;
    return QueueRowInfo(
      title:
          loaded?.title ??
          stringExtra(media, 'title') ??
          loaded?.mediaTitle ??
          nameFromUri(media.uri),
      artist: stringExtra(media, 'artist') ?? loaded?.artist,
      origin: originOf(media),
      duration: loaded?.duration ?? extrasDuration,
      artUrl: stringExtra(media, 'art'),
    );
  }

  final String title;
  final String? artist;
  final MediaOrigin origin;
  final Duration? duration;
  final String? artUrl;
}
