import 'package:flutter/foundation.dart';

import 'source_failure.dart';

export 'source_failure.dart';

/// How a track is requested from the server: untouched original bytes
/// (`direct`), or a server-side transcode. For a transcode the user picks the
/// codec, bitrate, streaming protocol ([StreamProtocol]) and segment container
/// ([StreamTransport]); Jellyfin transcodes over HLS only, while Plex offers
/// both HLS and DASH.
enum PlaybackMode {
  direct('Direct'),
  transcode('Transcode');

  final String label;
  const PlaybackMode(this.label);
}

/// The media-server backend kind. Embedded in each server [Media]'s extras
/// (`'server'`) so the app-level playback reporter can route a report to the
/// right connected server.
enum ServerKind { jellyfin, plex }

/// Output audio codec for a server-side transcode. [value] is the wire
/// token both servers accept as their `audioCodec` parameter.
enum TranscodeCodec {
  aac('AAC', 'aac'),
  mp3('MP3', 'mp3'),
  opus('Opus', 'opus');

  final String label;
  final String value;
  const TranscodeCodec(this.label, this.value);
}

/// Segment container for a transcoded stream. **fMP4** (fragmented MP4) is
/// the safe default for every codec: Plex carries it over DASH, Jellyfin
/// over HLS-fMP4. **MPEG-TS** (Plex HLS, Jellyfin HLS-ts) is offered only
/// for MP3: AAC and Opus in MPEG-TS reintroduce encoder-priming PTS
/// discontinuities ("Invalid audio PTS") at segment boundaries, so they
/// always ride fMP4. Applies to [PlaybackMode.transcode] only: direct play
/// streams the original file's own container untouched.
enum StreamTransport {
  fmp4('fMP4'),
  mpegts('MPEG-TS');

  final String label;
  const StreamTransport(this.label);
}

/// The streaming protocol (manifest and transport) for a transcode: **HLS**
/// (`start.m3u8`) or **DASH** (`start.mpd`). Independent of the segment
/// container ([StreamTransport]) save for one physical rule: DASH carries
/// only fMP4, while HLS carries fMP4 *or* MPEG-TS.
enum StreamProtocol {
  hls('HLS'),
  dash('DASH');

  final String label;
  const StreamProtocol(this.label);
}

/// True when [codec] can safely use MPEG-TS (MP3 only).
bool mpegtsAllowed(TranscodeCodec codec) => codec == TranscodeCodec.mp3;

/// What the user picked for server playback: direct play, or a transcode
/// with its codec, bitrate, protocol and container. One value object so the
/// picker and every server call read the same choice.
@immutable
class StreamOptions {
  const StreamOptions({
    this.mode = PlaybackMode.transcode,
    this.codec = TranscodeCodec.aac,
    this.bitrateKbps = 256,
    this.transport = StreamTransport.fmp4,
    this.protocol = StreamProtocol.hls,
  });

  final PlaybackMode mode;
  final TranscodeCodec codec;
  final int bitrateKbps;
  final StreamTransport transport;
  final StreamProtocol protocol;

  bool get transcodes => mode == PlaybackMode.transcode;

  /// The container a transcode actually uses: DASH always rides fMP4 (it
  /// cannot carry MPEG-TS); under HLS the requested [transport] stands when
  /// it is allowed (MPEG-TS needs MP3), otherwise fMP4. Both servers and the
  /// picker go through this, so they can never disagree.
  StreamTransport get effectiveTransport {
    if (protocol == StreamProtocol.dash) return StreamTransport.fmp4;
    return transport == StreamTransport.mpegts && mpegtsAllowed(codec)
        ? StreamTransport.mpegts
        : StreamTransport.fmp4;
  }

  /// These options with the given fields replaced. A change that makes the
  /// container impossible (a non-MP3 codec, DASH) falls back to fMP4, so the
  /// picker never shows a choice the stream would not honour.
  StreamOptions copyWith({
    PlaybackMode? mode,
    TranscodeCodec? codec,
    int? bitrateKbps,
    StreamTransport? transport,
    StreamProtocol? protocol,
  }) {
    final next = StreamOptions(
      mode: mode ?? this.mode,
      codec: codec ?? this.codec,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      transport: transport ?? this.transport,
      protocol: protocol ?? this.protocol,
    );
    return next.transport == next.effectiveTransport
        ? next
        : next.copyWith(transport: StreamTransport.fmp4);
  }

  @override
  bool operator ==(Object other) =>
      other is StreamOptions &&
      other.mode == mode &&
      other.codec == codec &&
      other.bitrateKbps == bitrateKbps &&
      other.transport == transport &&
      other.protocol == protocol;

  @override
  int get hashCode =>
      Object.hash(mode, codec, bitrateKbps, transport, protocol);
}

/// A server-agnostic audio track: what the lists need, plus an optional
/// [artUrl] (token embedded) so the Playback view can show cover art for
/// transcoded streams that carry no embedded metadata.
@immutable
class ServerTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? artUrl;

  /// Whether the track is a favourite for the current user (Jellyfin
  /// favourites; Plex `userRating == 10`).
  final bool isFavorite;

  const ServerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.artUrl,
    this.isFavorite = false,
  });
}

/// A server-agnostic music album.
@immutable
class ServerAlbum {
  final String id;
  final String title;
  final String artist;

  /// Release year, when the server knows it.
  final int? year;

  /// Cover art (token embedded), or null.
  final String? artUrl;

  const ServerAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.year,
    this.artUrl,
  });
}

/// One page of a library listing plus the server's total count.
class LibraryPage<T> {
  final List<T> items;
  final int total;
  const LibraryPage(this.items, this.total);
}

/// A connected media library (Jellyfin or Plex), reduced to what the
/// Stream page needs: connect, page and search the songs and albums, and
/// build a playable URL per track. The concrete servers wrap the
/// `dart_jellyfin` and `dart_plex` packages; the UI only sees this
/// interface.
abstract class MediaServer {
  String get name;

  /// Which backend this is; lets the reporter route to the right server.
  ServerKind get kind;

  bool get isConnected;

  /// The streaming protocols this server can transcode over, the default
  /// first.
  List<StreamProtocol> get protocols;

  /// What the host field expects, shown as its hint.
  String get hostHint;

  /// Authenticate against [host] (IP or URL) with [username] and
  /// [password].
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  });

  /// Re-establish a previously saved session (token) without a password.
  /// Returns true when a stored session was restored. Does not verify the
  /// token is still valid: a stale token surfaces as a load error that
  /// [isAuthError] then recognises.
  Future<bool> tryRestore();

  /// What kind of failure [error] (thrown by [connect], [fetchTracks] and
  /// the other calls) is. An auth failure (HTTP 401 or 403, often a stale
  /// restored token) makes the UI drop the session and show the sign-in
  /// form; a network failure offers a retry.
  FailureKind classify(Object error);

  /// Drop the session and forget the stored credentials.
  Future<void> logout();

  /// A page of the user's songs. [query] empty browses all (sorted by
  /// title); non-empty finds the songs whose title, artist or album
  /// matches.
  Future<LibraryPage<ServerTrack>> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  });

  /// A page of the user's albums, sorted by title. [query] non-empty
  /// finds the albums whose title or artist matches.
  Future<LibraryPage<ServerAlbum>> fetchAlbums({
    required int startIndex,
    required int pageSize,
    String query = '',
  });

  /// The tracks of [album], in disc and track order.
  Future<List<ServerTrack>> fetchAlbumTracks(ServerAlbum album);

  /// A URL mpv can open (auth token embedded in the query, or a marker the
  /// source resolver turns into one) for [track] with [options].
  String streamUrl(ServerTrack track, StreamOptions options);

  /// The real segment container of a transcode, which mpv cannot report
  /// (its `file-format` only shows the `hls` or `dash` protocol). Null for
  /// direct play, where mpv reports the true container itself.
  String? segmentContainer(StreamOptions options) =>
      options.transcodes ? options.effectiveTransport.label : null;

  /// Extra [Media.extras] the entry for [track] needs to stay playable on
  /// its own, beyond the tags; none by default.
  Map<String, Object?> mediaExtras(ServerTrack track, StreamOptions options) =>
      const {};

  /// Per-track libavformat demuxer options, handed to mpv as the file-local
  /// `demuxer-lavf-o` (through `Media.demuxerLavfOptions`) so they scope to
  /// exactly this stream. Null when none are needed, the common case.
  Map<String, String>? demuxerLavfOptions(StreamOptions options) => null;

  /// Mark or unmark [trackId] as a favourite for the current user. Throws
  /// when the server refuses (the [FavoritesController] undoes the toggle).
  /// Jellyfin uses its Favorites API; Plex encodes a favourite as
  /// `userRating == 10`.
  Future<void> setFavorite(String trackId, bool isFavorite);

  // Playback reporting: tell the server what is playing so it shows in
  // "Now Playing", advances play progress, and scrobbles. All best effort:
  // failures are logged so a reporting hiccup never disrupts playback.

  /// Playback of [itemId] has started.
  Future<void> reportStart(String itemId);

  /// Periodic progress for [itemId]: current [position] and whether [paused].
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool paused,
  });

  /// Playback of [itemId] stopped at [position].
  Future<void> reportStopped(String itemId, {required Duration position});
}

/// A library search whose matches come from several server queries (songs
/// or albums whose title matches, plus those of the artists and albums whose
/// name matches) merged into one list and paged locally. Neither Jellyfin's
/// `searchTerm` nor Plex's title filter looks past the item's own name, so
/// "Coldplay" alone finds no Coldplay song; the extra queries fill that in.
///
/// The merged list keeps the order of the groups [load] returns, drops
/// repeats by [idOf] and stops at [maxResults]. Page 0 always runs the
/// queries again (a refresh or a new query); later pages of the same query
/// read the cached list. A failed load is not cached, so a retry runs it
/// again.
class MergedSearch<T> {
  MergedSearch(this.idOf);

  /// Upper bound on the merged list, and on each query feeding it.
  static const maxResults = 500;

  /// How many matching artists or albums contribute their songs.
  static const maxOwners = 10;

  final String Function(T item) idOf;

  String? _query;
  Future<List<T>>? _results;

  Future<LibraryPage<T>> page(
    String query, {
    required int startIndex,
    required int pageSize,
    required Future<List<Iterable<T>>> Function() load,
  }) async {
    var results = _results;
    if (startIndex == 0 || results == null || _query != query) {
      _query = query;
      results = _results = load().then(merge);
    }
    final List<T> all;
    try {
      all = await results;
    } catch (_) {
      if (identical(_results, results)) {
        _results = null;
        _query = null;
      }
      rethrow;
    }
    if (startIndex >= all.length) return LibraryPage(const [], all.length);
    final end = startIndex + pageSize;
    return LibraryPage(
      all.sublist(startIndex, end > all.length ? all.length : end),
      all.length,
    );
  }

  /// [groups] flattened in order, without repeats, capped at [maxResults].
  List<T> merge(List<Iterable<T>> groups) {
    final seen = <String>{};
    final out = <T>[];
    for (final group in groups) {
      for (final item in group) {
        if (out.length >= maxResults) return out;
        if (seen.add(idOf(item))) out.add(item);
      }
    }
    return out;
  }
}

/// Thrown by a [MediaServer] call that needs a session when there is none.
/// The UI treats it like an expired session: back to the sign-in form.
class NotConnectedException implements Exception {
  const NotConnectedException(this.server);

  final String server;

  @override
  String toString() => 'Not connected to $server.';
}

/// The server base URL for what the user typed in [host]. A bare host or
/// IP (no scheme) gets `http://` and [defaultPort] unless it names a port;
/// a full URL is kept as typed, so `https://jf.example.com` stays on 443
/// behind a reverse proxy. Trailing slashes go.
String normalizeServerBase(String host, int defaultPort) {
  var h = host.trim();
  if (h.isEmpty) return h;
  if (!h.contains('://')) {
    var uri = Uri.parse('http://$h');
    if (!uri.hasPort) uri = uri.replace(port: defaultPort);
    h = uri.toString();
  }
  return h.replaceAll(RegExp(r'/+$'), '');
}
