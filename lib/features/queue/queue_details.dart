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
    this.album,
    this.duration,
  });

  /// The title tag.
  final String? title;

  /// mpv's media title (a radio stream's current title, for one), when it
  /// says more than the file name.
  final String? mediaTitle;

  /// The artist tag.
  final String? artist;

  /// The album tag.
  final String? album;

  /// The length, null for a stream of unknown length.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is LoadedDetails &&
      other.title == title &&
      other.mediaTitle == mediaTitle &&
      other.artist == artist &&
      other.album == album &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(title, mediaTitle, artist, album, duration);
}

/// How a queue entry's last play ended.
enum EntryEnd {
  /// It played to its end.
  ended,

  /// It was left before its end: skipped, replaced or stopped.
  stopped,

  /// It could not be played.
  failed,
}

/// The last play of a queue entry: how it ended and, for a failure, why.
@immutable
class EntryOutcome {
  const EntryOutcome(this.end, {this.code = 0, this.message});

  final EntryEnd end;

  /// The mpv error code of a failure (an [MpvError] constant), else 0.
  final int code;

  /// mpv's own description of the failure, when it sent one.
  final String? message;

  /// A short readable reason, for the row badge and the details.
  String get reason => switch (end) {
    EntryEnd.ended => 'Played',
    EntryEnd.stopped => 'Skipped',
    EntryEnd.failed => failureReason(code, message),
  };

  @override
  bool operator ==(Object other) =>
      other is EntryOutcome &&
      other.end == end &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(end, code, message);

  @override
  String toString() => 'EntryOutcome($end, $code, $message)';
}

/// Why an entry failed, in words, from the mpv error [code] and mpv's
/// [message].
String failureReason(int code, String? message) {
  final error = EndFileError(
    reason: MpvEndFileReason.error,
    code: code,
    message: message ?? '',
  );
  if (error.isAudioOutputError) return 'The audio device could not be opened';
  if (error.isFormatError) return 'No playable audio found';
  if (error.isLoadingError) return 'Could not open the file or stream';
  final m = message?.trim() ?? '';
  return m.isEmpty ? 'Could not play' : m;
}

/// The engine state [QueueDetails] reads when the current entry loads.
typedef LoadedSnapshot = ({
  Map<String, String> metadata,
  String mediaTitle,
  Duration duration,
});

/// Follows the queue for the Queue page: what the engine read from each
/// entry that has played (title, artist, album, length) and how its last
/// play ended.
///
/// The current entry is read when it is ready to play
/// (`stream.seekCompleted`), and again on each tag, title or length change
/// while it stays loaded (a radio stream changing its title). Entries that
/// leave the queue are forgotten.
///
/// An end (`stream.endFile`) belongs to the entry that last loaded: by the
/// time mpv reports that a track ended or was skipped, the queue may
/// already point at the next one. A failure to open belongs to the
/// current entry, which never loaded.
///
/// Entries are known by value: the library's playlist carries no entry
/// ids, so two copies of the same media share their tags (which is right)
/// and their last outcome (a copy that never played shows the other's).
class QueueDetails {
  QueueDetails({
    required Stream<Playlist> playlist,
    required Stream<void> loaded,
    required List<Stream<Object?>> changes,
    required LoadedSnapshot Function() snapshot,
    Stream<MpvFileEndedEvent> endFile = const Stream.empty(),
    Stream<PlayerError> errors = const Stream.empty(),
  }) : _snapshot = snapshot {
    _subs = [
      playlist.listen(_onPlaylist),
      loaded.listen((_) => _onLoaded()),
      for (final s in changes) s.listen((_) => _onChange()),
      endFile.listen(_onEndFile),
      errors.listen(_onError),
    ];
  }

  /// Wires the service to [player]'s streams.
  factory QueueDetails.of(PlayerApi player) => QueueDetails(
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
    endFile: player.stream.endFile,
    errors: player.stream.error,
  );

  final LoadedSnapshot Function() _snapshot;
  late final List<StreamSubscription<Object?>> _subs;

  /// The details known so far, by entry.
  ValueListenable<Map<Media, LoadedDetails>> get details => _details;
  final _details = ValueNotifier<Map<Media, LoadedDetails>>(const {});

  /// How each entry's last play ended. An entry has none while it plays
  /// and before it first plays.
  ValueListenable<Map<Media, EntryOutcome>> get outcomes => _outcomes;
  final _outcomes = ValueNotifier<Map<Media, EntryOutcome>>(const {});

  Media? _current;

  /// Whether [_current] has loaded, so the engine state describes it.
  bool _loaded = false;

  /// The entry that loaded last and has not ended yet.
  Media? _playing;

  /// The entry of the latest failure, until mpv's message for it arrives.
  Media? _lastFailed;

  void _onPlaylist(Playlist pl) {
    final current = pl.index >= 0 && pl.index < pl.items.length
        ? pl.items[pl.index]
        : null;
    if (current != _current) {
      _current = current;
      _loaded = false;
    }
    if (_playing != null && !pl.items.contains(_playing)) _playing = null;
    _details.value = _retain(_details.value, pl.items);
    _outcomes.value = _retain(_outcomes.value, pl.items);
  }

  static Map<Media, V> _retain<V>(Map<Media, V> known, List<Media> items) {
    if (known.keys.every(items.contains)) return known;
    return {
      for (final e in known.entries)
        if (items.contains(e.key)) e.key: e.value,
    };
  }

  void _onLoaded() {
    final entry = _current;
    if (entry == null) return;
    _loaded = true;
    _playing = entry;
    if (_outcomes.value.containsKey(entry)) {
      _outcomes.value = {..._outcomes.value}..remove(entry);
    }
    _record();
  }

  void _onChange() {
    if (_loaded) _record();
  }

  void _onEndFile(MpvFileEndedEvent event) {
    final EntryEnd end;
    final Media? entry;
    switch (event.reason) {
      case MpvEndFileReason.eof:
        end = EntryEnd.ended;
        entry = _playing;
      case MpvEndFileReason.stop:
        end = EntryEnd.stopped;
        entry = _playing;
      case MpvEndFileReason.error:
        end = EntryEnd.failed;
        entry = _loaded ? _playing : _current;
      case MpvEndFileReason.quit || MpvEndFileReason.redirect:
        return;
    }
    if (entry == _playing) _playing = null;
    if (entry == _current) _loaded = false;
    _lastFailed = end == EntryEnd.failed ? entry : null;
    if (entry == null) return;
    _outcomes.value = {
      ..._outcomes.value,
      entry: EntryOutcome(end, code: event.error),
    };
  }

  void _onError(PlayerError error) {
    if (error is! EndFileError) return;
    final entry = _lastFailed;
    _lastFailed = null;
    final known = entry == null ? null : _outcomes.value[entry];
    if (known == null || known.end != EntryEnd.failed) return;
    _outcomes.value = {
      ..._outcomes.value,
      entry!: EntryOutcome(
        EntryEnd.failed,
        code: known.code == 0 ? error.code : known.code,
        message: error.message,
      ),
    };
  }

  void _record() {
    final entry = _current;
    if (entry == null) return;
    final s = _snapshot();
    final next = LoadedDetails(
      title: tagOf(s.metadata, 'title'),
      mediaTitle: _informative(s.mediaTitle, entry),
      artist: tagOf(s.metadata, 'artist'),
      album: tagOf(s.metadata, 'album'),
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
    _outcomes.dispose();
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

/// What one queue row shows. Built the same way for the current, the
/// played and the waiting entries: the tags the engine read win over what
/// the app knew when it queued the entry (its extras), which win over a
/// name taken from the URI.
@immutable
class QueueRowInfo {
  const QueueRowInfo({
    required this.title,
    required this.artist,
    required this.album,
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
      artist: loaded?.artist ?? stringExtra(media, 'artist'),
      album: loaded?.album ?? stringExtra(media, 'album'),
      origin: originOf(media),
      duration: loaded?.duration ?? extrasDuration,
      artUrl: stringExtra(media, 'art'),
    );
  }

  final String title;
  final String? artist;
  final String? album;
  final MediaOrigin origin;
  final Duration? duration;
  final String? artUrl;

  /// The second line of the row: the artist when known, then the source.
  String get subtitle =>
      artist == null ? origin.label : '$artist · ${origin.label}';
}
