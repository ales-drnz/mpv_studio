import 'dart:io' show Platform;

import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:dart_plex/dart_plex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'plex_transcode_session_manager.dart';

// Human-readable device name shown in the servers' "Now Playing" (e.g.
// "Alex's MacBook Pro"). Resolved once at startup via [resolveDeviceName]
// and set with [setMediaDeviceName]; both servers read it when they build
// their credentials. Defaults to the app name until resolved.
String _deviceName = 'MPV Studio';

/// Override the reported device name (call before connecting). See
/// [resolveDeviceName].
void setMediaDeviceName(String name) {
  if (name.trim().isNotEmpty) _deviceName = name.trim();
}

// Stable, per-install unique device identifier. Jellyfin binds each access
// token to the DeviceId and treats a device as a single session, so a constant
// id shared across installs/devices makes the server invalidate the restored
// token — surfacing as "session expired" on (nearly) every launch. Generated
// once and persisted; Plex's clientIdentifier reuses it too (best practice:
// one stable, unique id per install — Plex is unaffected only because its token
// is account-level, not device-bound).
String _deviceId = 'mpv-studio';

const _kDeviceIdPref = 'media.deviceId';

/// Loads the persisted per-install device id, generating + storing a fresh
/// UUID on first run. Call once at startup before connecting (see
/// [resolveDeviceName]).
Future<void> resolveDeviceId() async {
  final p = await SharedPreferences.getInstance();
  var id = p.getString(_kDeviceIdPref);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await p.setString(_kDeviceIdPref, id);
  }
  _deviceId = id;
}

/// Best-effort, header-safe device name for server reporting: the machine
/// name on desktop, the device name on mobile. Falls back to 'MPV Studio'.
Future<String> resolveDeviceName() async {
  try {
    final info = DeviceInfoPlugin();
    String name;
    if (Platform.isMacOS) {
      name = (await info.macOsInfo).computerName;
    } else if (Platform.isIOS) {
      name = (await info.iosInfo).name;
    } else if (Platform.isWindows) {
      name = (await info.windowsInfo).computerName;
    } else if (Platform.isAndroid) {
      final a = await info.androidInfo;
      name = '${a.manufacturer} ${a.model}';
    } else if (Platform.isLinux) {
      name = (await info.linuxInfo).name;
    } else {
      name = 'MPV Studio';
    }
    // Normalise smart quotes, drop double quotes, keep printable ASCII only
    // (X-Plex-* / Jellyfin auth headers must stay ASCII-clean).
    name = name.replaceAll('’', "'").replaceAll('‘', "'");
    name = name.replaceAll('"', '');
    final sanitized = name.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    return sanitized.isEmpty ? 'MPV Studio' : sanitized;
  } catch (e) {
    debugPrint('resolveDeviceName failed: $e');
    return 'MPV Studio';
  }
}

/// How a track is requested from the server: untouched original bytes
/// (`direct`), or a server-side transcode. For a transcode the user picks the
/// codec, bitrate, streaming protocol ([StreamProtocol]) and segment container
/// ([StreamTransport]); Jellyfin transcodes over HLS only, while Plex offers
/// both HLS and DASH.
enum PlaybackMode { direct, transcode }

/// The media-server backend kind. Embedded in each server [Media]'s extras
/// (`'server'`) so the app-level playback reporter can route a report to the
/// right connected server.
enum ServerKind { jellyfin, plex }

extension PlaybackModeLabel on PlaybackMode {
  String get label => switch (this) {
        PlaybackMode.direct => 'Direct',
        PlaybackMode.transcode => 'Transcode',
      };
}

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
/// the safe default for every codec — Plex carries it over DASH, Jellyfin
/// over HLS-fMP4. **MPEG-TS** (Plex HLS / Jellyfin HLS-ts) is offered only
/// for MP3: AAC/Opus in MPEG-TS reintroduce encoder-priming PTS
/// discontinuities ("Invalid audio PTS") at segment boundaries, so they
/// always ride fMP4. Applies to [PlaybackMode.transcode] only — direct play
/// streams the original file's own container untouched.
enum StreamTransport {
  fmp4('fMP4'),
  mpegts('MPEG-TS');

  final String label;
  const StreamTransport(this.label);
}

/// The streaming protocol (manifest/transport) for a transcode: **HLS**
/// (`start.m3u8`) or **DASH** (`start.mpd`). Independent of the segment
/// container ([StreamTransport]) save for one physical rule: DASH carries
/// only fMP4, while HLS carries fMP4 *or* MPEG-TS. Jellyfin transcodes over
/// HLS only — DASH is Plex-only (the picker greys it out on Jellyfin).
enum StreamProtocol {
  hls('HLS'),
  dash('DASH');

  final String label;
  const StreamProtocol(this.label);
}

/// True when [codec] can safely use MPEG-TS (MP3 only). The Container
/// picker uses this to gate the MPEG-TS option.
bool mpegtsAllowed(String codec) => codec == TranscodeCodec.mp3.value;

/// The container a transcode will actually use given the chosen [protocol]
/// and [codec]: DASH always rides fMP4 (it cannot carry MPEG-TS); under HLS
/// the [requested] container stands when it's allowed (MPEG-TS → MP3 only),
/// otherwise fMP4. Both servers funnel through this so the picker and the
/// stream can never disagree.
StreamTransport effectiveTransport(
  StreamTransport requested,
  String codec, {
  StreamProtocol protocol = StreamProtocol.hls,
}) {
  if (protocol == StreamProtocol.dash) return StreamTransport.fmp4;
  return requested == StreamTransport.mpegts && mpegtsAllowed(codec)
      ? StreamTransport.mpegts
      : StreamTransport.fmp4;
}

/// A server-agnostic audio track — only what the minimal list needs, plus
/// an optional [artUrl] (token-embedded) so the Playback view can show cover
/// art for transcoded streams that carry no embedded metadata.
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

/// One page of tracks plus the server's total count (for pagination).
class TrackPage {
  final List<ServerTrack> tracks;
  final int total;
  const TrackPage(this.tracks, this.total);
}

/// A connected media library (Jellyfin or Plex), reduced to what the
/// Stream page needs: connect, page/search the song list, and build a
/// playable URL per track. The concrete impls wrap the author's
/// `dart_jellyfin` / `dart_plex` packages; the UI only sees this interface.
abstract class MediaServer {
  String get name;
  bool get isConnected;

  /// Authenticate against [host] (IP or URL) with [username] / [password].
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  });

  /// A page of the user's songs. [query] empty = browse all (sorted by
  /// title); non-empty = search.
  Future<TrackPage> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  });

  /// A URL mpv can open directly (auth token embedded in the query) for
  /// [track] in the given [mode]. For [PlaybackMode.transcode] the server
  /// re-encodes to [codec] capped at [bitrateKbps], streams it over [protocol]
  /// and packages the segments in [transport] (see [effectiveTransport]); all
  /// four are ignored for direct play. Jellyfin streams HLS regardless of
  /// [protocol].
  String streamUrl(
    ServerTrack track,
    PlaybackMode mode, {
    String codec,
    int bitrateKbps,
    StreamTransport transport,
    StreamProtocol protocol,
  });

  /// The real segment container for a transcode [mode] — which mpv can't
  /// report (its `file-format` only shows the `hls`/`dash` protocol). Null
  /// for direct play, where mpv reports the true container itself. Reflects
  /// the [effectiveTransport] for [protocol] / [codec] / [transport].
  String? segmentContainer(
    PlaybackMode mode, {
    String codec,
    StreamTransport transport,
    StreamProtocol protocol,
  });

  /// Per-track libavformat demuxer options for this [mode], handed to mpv as
  /// the file-local `demuxer-lavf-o` (via [Media.demuxerLavfOptions]) so they
  /// scope to exactly this stream. Null when none are needed — the common
  /// case. Used to correct a transcoder-specific demuxing quirk without
  /// changing the stream (see [JellyfinServer.demuxerLavfOptions]).
  Map<String, String>? demuxerLavfOptions(
    PlaybackMode mode, {
    String codec,
    StreamTransport transport,
    StreamProtocol protocol,
  });

  /// Mark/unmark [trackId] as a favourite for the current user. Best-effort
  /// (errors are swallowed/logged). Jellyfin uses its Favorites API; Plex
  /// encodes a favourite as `userRating == 10`.
  Future<void> setFavorite(String trackId, bool isFavorite);

  /// Re-establish a previously saved session (token) without a password.
  /// Returns true when a stored session was restored. Does not verify the
  /// token is still valid — a stale token surfaces as a load error that
  /// [isAuthError] then recognises.
  Future<bool> tryRestore();

  /// Whether [error] (thrown from [fetchTracks] etc.) is an authentication
  /// failure — an expired/invalid token, i.e. HTTP 401/403. The UI uses this
  /// to drop a dead session and fall back to the connect form instead of
  /// showing a raw, un-retryable error. A stale restored token is the common
  /// case (see [tryRestore]).
  bool isAuthError(Object error);

  /// Drop the session and forget the stored credentials.
  Future<void> logout();

  // ─── Playback reporting ──────────────────────────────────────────────
  // Tell the server what's playing so it shows in "Now Playing", advances
  // on-deck / play progress, and scrobbles. All are best-effort: failures
  // are swallowed (logged) so a reporting hiccup never disrupts playback.

  /// Which backend this is — lets the reporter route to the right server.
  ServerKind get kind;

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

/// Adds a scheme (http) and the platform default port when the user typed a
/// bare IP, and trims a trailing slash. Leaves explicit scheme/port alone.
String _normalizeBase(String host, int defaultPort) {
  var h = host.trim();
  if (h.isEmpty) return h;
  if (!h.contains('://')) h = 'http://$h';
  var uri = Uri.parse(h);
  if (!uri.hasPort) uri = uri.replace(port: defaultPort);
  return uri.toString().replaceAll(RegExp(r'/+$'), '');
}

// ── Jellyfin ──────────────────────────────────────────────────────────

class JellyfinServer implements MediaServer {
  JellyfinClient? _client;

  // Built per access so it picks up the resolved [_deviceName]. `client`
  // is the app (shown as the Jellyfin "Client"); `device` is the machine
  // name (shown as the "Device").
  JellyfinCredentials get _credentials => JellyfinCredentials(
        client: 'MPV Studio',
        device: _deviceName,
        deviceId: _deviceId,
        version: '0.1.0',
      );

  static const _kBase = 'jellyfin.base';
  static const _kToken = 'jellyfin.token';
  static const _kUserId = 'jellyfin.userId';

  // The PlaySessionId minted for each track's transcode (itemId → session),
  // captured when [streamUrl] builds the URL so the playback reports
  // ([reportStart] / [reportProgress] / [reportStopped]) can carry the SAME id.
  // That linkage is what lets Jellyfin reap a track's transcode the moment we
  // report it stopped — without it (reports with no session) the server keeps
  // old transcodes alive across track changes and the pile-up 500s the next
  // track's first segment. Bounded so a long queue can't grow it unboundedly.
  final Map<String, String> _playSessionByItem = {};
  int _sessionSeq = 0;
  String _nextSession() =>
      'mpv-${DateTime.now().microsecondsSinceEpoch}-${_sessionSeq++}';

  @override
  String get name => 'Jellyfin';

  @override
  bool get isConnected => _client?.token != null;

  @override
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    final base = _normalizeBase(host, 8096);
    final client = JellyfinClient(baseUrl: base, credentials: _credentials);
    final auth = await client.user
        .authenticateByName(username: username, password: password);
    client.setSession(token: auth.accessToken, userId: auth.user.id);
    _client = client;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, base);
    await p.setString(_kToken, auth.accessToken);
    await p.setString(_kUserId, auth.user.id);
  }

  @override
  Future<bool> tryRestore() async {
    final p = await SharedPreferences.getInstance();
    final base = p.getString(_kBase);
    final token = p.getString(_kToken);
    final userId = p.getString(_kUserId);
    if (base == null || token == null || userId == null) return false;
    final client = JellyfinClient(baseUrl: base, credentials: _credentials);
    client.setSession(token: token, userId: userId);
    _client = client;
    return true;
  }

  @override
  Future<void> logout() async {
    _client = null;
    _playSessionByItem.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBase);
    await p.remove(_kToken);
    await p.remove(_kUserId);
  }

  @override
  bool isAuthError(Object error) =>
      error is JellyfinException && error.type.isAuthError;

  @override
  Future<TrackPage> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    // `fields` is left at its default (empty — the server's own projection)
    // deliberately: since dart_jellyfin 0.1.1 the music field set is opt-in
    // (`JellyfinItemsApi.musicFields`) and none of it is used here. Title,
    // Artists, Album, AlbumArtist and RunTimeTicks are always sent, and the
    // favourite flag rides on UserData (`enableUserData`, on by default), so
    // the lighter payload costs nothing.
    final res = await _client!.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      recursive: true,
      sortBy: const ['SortName'],
      startIndex: startIndex,
      limit: pageSize,
      searchTerm: query.isEmpty ? null : query,
    );
    final token = _client!.token!;
    final tracks = [
      for (final it in res.items)
        ServerTrack(
          id: it.id,
          title: it.name,
          artist: it.artists.isNotEmpty
              ? it.artists.join(', ')
              : (it.albumArtist ?? ''),
          album: it.album ?? '',
          // runTimeTicks are 100-ns units → microseconds = ticks / 10.
          duration: Duration(microseconds: (it.runTimeTicks ?? 0) ~/ 10),
          artUrl: _imageUrl(it.id, token),
          isFavorite: it.isFavorite,
        ),
    ];
    return TrackPage(tracks, res.totalRecordCount);
  }

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.userData.setFavorite(trackId, isFavorite);
    } catch (e) {
      debugPrint('JellyfinServer: setFavorite failed: $e');
    }
  }

  // Primary (album) image. The images API omits the token, so append it —
  // private servers reject image requests otherwise. A 404 (no art) just
  // falls through to the placeholder in the UI.
  String _imageUrl(String itemId, String token) {
    final u = _client!.images
        .url(itemId: itemId, fillWidth: 400, fillHeight: 400);
    return u.contains('?') ? '$u&api_key=$token' : '$u?api_key=$token';
  }

  @override
  String streamUrl(
    ServerTrack track,
    PlaybackMode mode, {
    String codec = 'aac',
    int bitrateKbps = 256,
    StreamTransport transport = StreamTransport.fmp4,
    // Jellyfin transcodes over HLS only; [protocol] is accepted for interface
    // parity (the picker greys DASH out on this tab) but never selects DASH.
    StreamProtocol protocol = StreamProtocol.hls,
  }) {
    if (mode == PlaybackMode.direct) {
      return _client!.audio.directStreamUrl(itemId: track.id).$1;
    }
    // Transcode over HLS; the container follows the picker — fMP4 ('mp4') by
    // default, MPEG-TS ('ts') only for MP3 (see [effectiveTransport]). fMP4 is
    // safe again: the bundled libmpv's waveform analyzer no longer opens the
    // stream a SECOND time to classify it (libmpv-scripts
    // patch_bulk_analysis.py — it now arms from mpv's own demuxer info), and it
    // was that concurrent open of the fMP4 init section that used to make
    // Jellyfin 500 the first segment. A per-track PlaySessionId is captured so
    // the playback reports can reap THIS transcode on stop (see
    // [_playSessionByItem]) instead of leaving it warm to pile up against the
    // next track's.
    final t = effectiveTransport(transport, codec);
    final session = _nextSession();
    _playSessionByItem[track.id] = session;
    if (_playSessionByItem.length > 200) {
      _playSessionByItem.remove(_playSessionByItem.keys.first);
    }
    return _client!.audio.universalStreamUrl(
      itemId: track.id,
      audioCodec: codec,
      containers: const ['aac', 'mp3', 'flac', 'ogg', 'opus'],
      transcodingProtocol: 'hls',
      transcodingContainer: t == StreamTransport.mpegts ? 'ts' : 'mp4',
      maxStreamingBitrate: bitrateKbps * 1000,
      audioBitRate: bitrateKbps * 1000,
      playSessionId: session,
    );
  }

  @override
  String? segmentContainer(
    PlaybackMode mode, {
    String codec = 'aac',
    StreamTransport transport = StreamTransport.fmp4,
    StreamProtocol protocol = StreamProtocol.hls,
  }) =>
      mode == PlaybackMode.transcode
          ? effectiveTransport(transport, codec).label
          : null;

  // `seg_max_retry=5` on the HLS demuxer (via mpv `demuxer-lavf-o`). libav
  // defaults it to 0 — a single segment error aborts the whole open. A live
  // Jellyfin transcode can briefly 500 a segment under load (e.g. a
  // just-started transcode that hasn't produced the segment yet); a few
  // retries let the demuxer re-request it a moment later instead of failing
  // the track. Light, codec-agnostic defense (the real waveform/desync fix was
  // making the libmpv analyzer stop re-opening the stream). Transcode only —
  // direct play streams the original file and needs nothing.
  @override
  Map<String, String>? demuxerLavfOptions(
    PlaybackMode mode, {
    String codec = 'aac',
    StreamTransport transport = StreamTransport.fmp4,
    StreamProtocol protocol = StreamProtocol.hls,
  }) =>
      mode == PlaybackMode.transcode ? const {'seg_max_retry': '5'} : null;

  @override
  ServerKind get kind => ServerKind.jellyfin;

  @override
  Future<void> reportStart(String itemId) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.playback
          .start(itemId: itemId, playSessionId: _playSessionByItem[itemId]);
    } catch (e) {
      debugPrint('JellyfinServer: reportStart failed: $e');
    }
  }

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool paused,
  }) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.playback.progress(
        itemId: itemId,
        position: position,
        isPaused: paused,
        playSessionId: _playSessionByItem[itemId],
      );
    } catch (e) {
      debugPrint('JellyfinServer: reportProgress failed: $e');
    }
  }

  @override
  Future<void> reportStopped(String itemId, {required Duration position}) async {
    final c = _client;
    if (c == null) return;
    try {
      // Carry the track's PlaySessionId so Jellyfin reaps THIS transcode now,
      // instead of leaving it warm to pile up against the next track's.
      await c.playback.stopped(
        itemId: itemId,
        position: position,
        playSessionId: _playSessionByItem.remove(itemId),
      );
    } catch (e) {
      debugPrint('JellyfinServer: reportStopped failed: $e');
    }
  }
}

// ── Plex ──────────────────────────────────────────────────────────────

class PlexServer implements MediaServer {
  PlexClient? _client;
  String? _musicSectionId;
  PlexTranscodeSessionManager? _transcodes;

  // Built per access so it picks up the resolved [_deviceName]. `device` /
  // `deviceName` are the machine name (shown in Now Playing); `platform` is
  // a SEPARATE field — the transcode-profile selector (see [_platform]).
  PlexCredentials get _credentials => PlexCredentials(
        clientIdentifier: _deviceId,
        product: 'MPV Studio',
        version: '0.1.0',
        device: _deviceName,
        deviceName: _deviceName,
        // Plex selects a base transcode profile by X-Plex-Platform; an
        // unrecognised value 400s the /decision with "Unable to find
        // client profile for device". So map the real OS to a
        // Plex-recognised platform name (see [_platform]).
        platform: _platform,
        // Seed a base musicProfile transcode target. The per-track
        // add-transcode-target in PlexTranscodeSessionManager.resolve only
        // *extends* an existing music profile — without this seed there is
        // no musicProfile context to extend, so Plex ignores our audioCodec
        // and the transcode never starts.
        clientProfileExtra:
            'add-transcode-target(type=musicProfile&context=streaming'
            '&protocol=hls&container=mpegts&audioCodec=aac,mp3)',
      );

  // X-Plex-Platform value Plex uses to pick the transcode client profile.
  // An unrecognised value makes /transcode/universal/decision return 400
  // ("Unable to find client profile for device"), so transcode never
  // starts. Verified against a live PMS: iOS / Android / Windows resolve to
  // a built-in profile; macOS, Linux (and anything else) do NOT — for those
  // we send 'Generic', Plex's own profile for custom/unrecognised clients,
  // which transcodes fine. This is the platform reported for profile
  // matching only; the app's real identity stays in product/deviceName.
  static String get _platform {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    // macOS, Linux, etc.: no built-in Plex profile → fall back to Generic.
    return 'Generic';
  }

  static const _kBase = 'plex.base';
  static const _kToken = 'plex.token';
  static const _kSection = 'plex.section';

  @override
  String get name => 'Plex';

  @override
  bool get isConnected => _client?.isAuthenticated ?? false;

  @override
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    final base = _normalizeBase(host, 32400);
    final client = PlexClient(credentials: _credentials);
    // Account auth goes to plex.tv; the token then authorises the local PMS.
    final user = await client.account
        .signInWithPassword(username: username, password: password);
    client.setToken(user.authToken);
    client.connect(base, accessToken: user.authToken);
    final sections = await client.library.sections();
    final music = sections.firstWhere(
      (s) => s.type == PlexLibraryType.music,
      orElse: () => sections.first,
    );
    _musicSectionId = music.id;
    _client = client;
    _transcodes = PlexTranscodeSessionManager(client);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, base);
    await p.setString(_kToken, user.authToken);
    await p.setString(_kSection, music.id);
  }

  @override
  Future<bool> tryRestore() async {
    final p = await SharedPreferences.getInstance();
    final base = p.getString(_kBase);
    final token = p.getString(_kToken);
    final section = p.getString(_kSection);
    if (base == null || token == null || section == null) return false;
    final client = PlexClient(credentials: _credentials);
    client.setToken(token);
    client.connect(base, accessToken: token);
    _musicSectionId = section;
    _client = client;
    _transcodes = PlexTranscodeSessionManager(client);
    return true;
  }

  @override
  Future<void> logout() async {
    _transcodes?.clear();
    _transcodes = null;
    _client = null;
    _musicSectionId = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBase);
    await p.remove(_kToken);
    await p.remove(_kSection);
  }

  @override
  bool isAuthError(Object error) =>
      error is PlexException && error.type == PlexErrorType.auth;

  @override
  Future<TrackPage> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    final res = await _client!.library.allByType(
      sectionId: _musicSectionId!,
      type: PlexMetadataType.track,
      start: startIndex,
      size: pageSize,
      sort: 'titleSort',
      // Substring title match — the typed form of the old `title:` argument
      // (dart_plex 0.1.1 folded it into the `filters` list).
      filters: [
        if (query.isNotEmpty) PlexFilter.titleContains(query),
      ],
    );
    final tracks = [
      for (final m in res.items)
        ServerTrack(
          id: m.ratingKey,
          title: m.title,
          artist: m.grandparentTitle ?? '',
          album: m.parentTitle ?? '',
          duration: Duration(milliseconds: m.durationMs ?? 0),
          artUrl: _imageUrl(m.parentThumb ?? m.grandparentThumb),
          isFavorite: m.isFavorite,
        ),
    ];
    return TrackPage(tracks, res.totalSize);
  }

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.playback.setFavorite(ratingKey: trackId, isFavorite: isFavorite);
    } catch (e) {
      debugPrint('PlexServer: setFavorite failed: $e');
    }
  }

  // Album/artist thumbnail through Plex's photo transcoder (token embedded).
  String? _imageUrl(String? sourcePath) {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    return _client!.images
        .transcodeUrl(sourcePath: sourcePath, width: 400, height: 400);
  }

  @override
  String streamUrl(
    ServerTrack track,
    PlaybackMode mode, {
    String codec = 'aac',
    int bitrateKbps = 256,
    StreamTransport transport = StreamTransport.fmp4,
    StreamProtocol protocol = StreamProtocol.dash,
  }) {
    final streaming = _client!.streaming;
    final directUrl = streaming.universalAudioUrl(
      ratingKey: track.id,
      protocol: 'http',
      directPlay: true,
      directStream: true,
    );
    // Protocol and container are independent on Plex: DASH (start.mpd) always
    // rides fMP4, while HLS (start.m3u8) carries fMP4 or MPEG-TS. MPEG-TS only
    // survives with MP3, and never under DASH (see [effectiveTransport]).
    final t = effectiveTransport(transport, codec, protocol: protocol);
    final wireProtocol = protocol == StreamProtocol.dash ? 'dash' : 'hls';
    // BOTH modes hand mpv a `plex-transcode://{session}` marker that the
    // global on_load hook resolves just before playback. Plex's universal
    // `start.*` URL isn't openable by mpv, so:
    //   • direct   → the hook resolves to the original media Part URL;
    //   • transcode→ /decision spins up a session → real start.mpd/m3u8 (and
    //     on a non-playable decision, falls back to the same Part URL).
    // [directUrl] is only the last-resort fallback if the Part can't be found.
    return _transcodes!.register(
      ratingKey: track.id,
      codec: codec,
      fallbackUrl: directUrl,
      bitrateKbps: bitrateKbps,
      transcode: mode == PlaybackMode.transcode,
      protocol: wireProtocol,
      container: t == StreamTransport.mpegts ? 'mpegts' : 'mp4',
    );
  }

  @override
  String? segmentContainer(
    PlaybackMode mode, {
    String codec = 'aac',
    StreamTransport transport = StreamTransport.fmp4,
    StreamProtocol protocol = StreamProtocol.dash,
  }) =>
      mode == PlaybackMode.transcode
          ? effectiveTransport(transport, codec, protocol: protocol).label
          : null;

  // Plex needs no demuxer override: its DASH/HLS segmenter is exactly what the
  // bundled ffmpeg `advanced_editlist` patch targets, so the patched path is
  // correct here (the Jellyfin-only override in [JellyfinServer] is what backs
  // that patch off for Jellyfin's incompatible HLS-fMP4 edit list).
  @override
  Map<String, String>? demuxerLavfOptions(
    PlaybackMode mode, {
    String codec = 'aac',
    StreamTransport transport = StreamTransport.fmp4,
    StreamProtocol protocol = StreamProtocol.dash,
  }) =>
      null;

  @override
  ServerKind get kind => ServerKind.plex;

  @override
  Future<void> reportStart(String itemId) =>
      _timeline(itemId, PlexPlaybackApi.statePlaying, Duration.zero);

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool paused,
  }) =>
      _timeline(
        itemId,
        paused ? PlexPlaybackApi.statePaused : PlexPlaybackApi.statePlaying,
        position,
      );

  @override
  Future<void> reportStopped(String itemId, {required Duration position}) =>
      // `continuing: true` mirrors Plex Web's track-transition report so the
      // server doesn't reap the (still-warm) transcode session when the next
      // track starts.
      _timeline(itemId, PlexPlaybackApi.stateStopped, position,
          continuing: true);

  Future<void> _timeline(
    String ratingKey,
    String state,
    Duration position, {
    bool continuing = false,
  }) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.playback.timeline(
        ratingKey: ratingKey,
        state: state,
        timeMs: position.inMilliseconds,
        durationMs: 0,
        continuing: continuing,
      );
    } catch (e) {
      debugPrint('PlexServer: timeline($state) failed: $e');
    }
  }
}
