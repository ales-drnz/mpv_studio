import 'dart:io' show Platform;

import 'package:dart_plex/dart_plex.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:mpv_audio_kit/mpv_audio_kit.dart'
    show LogLevel, SourceResolveRequest;
import 'package:shared_preferences/shared_preferences.dart';

import '../../studio/studio_log.dart';
import 'device_identity.dart';
import 'media_server.dart';
import 'plex_transcode_session_manager.dart';

/// A Plex library through `dart_plex`. Every track plays through a
/// `plex-transcode://` marker that [resolveSource] turns into the real URL
/// right before mpv opens it (see [PlexTranscodeSessionManager]).
class PlexServer extends MediaServer {
  PlexServer();

  /// A server already signed in through [client] on the music section
  /// [musicSectionId], for tests that answer its requests with a fake.
  @visibleForTesting
  PlexServer.withClient(PlexClient client, String musicSectionId) {
    _attach(client, musicSectionId);
  }

  PlexClient? _client;
  String? _musicSectionId;
  PlexTranscodeSessionManager? _transcodes;

  // Built per access so it picks up the resolved device name. `device` and
  // `deviceName` are the machine name (shown in Now Playing); `platform` is
  // a SEPARATE field, the transcode profile selector (see [_platform]).
  PlexCredentials get _credentials => PlexCredentials(
    clientIdentifier: DeviceIdentity.deviceId,
    product: DeviceIdentity.product,
    version: DeviceIdentity.version,
    device: DeviceIdentity.deviceName,
    deviceName: DeviceIdentity.deviceName,
    platform: _platform,
    // Seed a base musicProfile transcode target. The per-track
    // add-transcode-target in PlexTranscodeSessionManager only *extends* an
    // existing music profile: without this seed there is no musicProfile
    // context to extend, so Plex ignores our audioCodec and the transcode
    // never starts.
    clientProfileExtra:
        'add-transcode-target(type=musicProfile&context=streaming'
        '&protocol=hls&container=mpegts&audioCodec=aac,mp3)',
  );

  // X-Plex-Platform, which Plex uses to pick the transcode client profile.
  // An unrecognised value makes /transcode/universal/decision answer 400
  // ("Unable to find client profile for device"), so the transcode never
  // starts. Verified against a live PMS: iOS, Android and Windows resolve
  // to a built-in profile; macOS, Linux and anything else do NOT, so those
  // send 'Generic', Plex's own profile for custom clients. This is only the
  // platform reported for profile matching; the app's identity stays in
  // product and deviceName.
  static String get _platform {
    if (kIsWeb) return 'Generic';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    return 'Generic';
  }

  static const _kBase = 'plex.base';
  static const _kToken = 'plex.token';
  static const _kSection = 'plex.section';

  @override
  String get name => 'Plex';

  @override
  ServerKind get kind => ServerKind.plex;

  @override
  bool get isConnected => _client?.isAuthenticated ?? false;

  /// DASH first: the path Plex documents for audio.
  @override
  List<StreamProtocol> get protocols => const [
    StreamProtocol.dash,
    StreamProtocol.hls,
  ];

  @override
  String get hostHint => '192.168.1.10:32400';

  @override
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    final base = normalizeServerBase(host, 32400);
    final client = PlexClient(credentials: _credentials);
    // Account auth goes to plex.tv; the token then authorises the local PMS.
    final user = await client.account.signInWithPassword(
      username: username,
      password: password,
    );
    client.setToken(user.authToken);
    client.connect(base, accessToken: user.authToken);
    final sections = await client.library.sections();
    if (sections.isEmpty) {
      throw StateError('This Plex server has no libraries.');
    }
    final music = sections.firstWhere(
      (s) => s.type == PlexLibraryType.music,
      orElse: () => sections.first,
    );
    _attach(client, music.id);
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
    _attach(client, section);
    return true;
  }

  void _attach(PlexClient client, String musicSectionId) {
    _musicSectionId = musicSectionId;
    _client = client;
    _transcodes?.dispose();
    _transcodes = PlexTranscodeSessionManager(client);
  }

  @override
  Future<void> logout() async {
    dispose();
    _client = null;
    _musicSectionId = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBase);
    await p.remove(_kToken);
    await p.remove(_kSection);
  }

  /// The player's source resolver for Plex entries: turns a
  /// `plex-transcode://` marker into the URL to open, right before mpv opens
  /// it, and renews the transcode session when that open fails. Returns null
  /// for every other entry, and when no account is connected.
  Future<String?> resolveSource(SourceResolveRequest request) async =>
      _transcodes?.resolveSource(request);

  /// Stops the transcode heartbeat and forgets the sessions. Called on
  /// logout and on app shutdown.
  void dispose() {
    _transcodes?.dispose();
    _transcodes = null;
  }

  @override
  FailureKind classify(Object error) {
    if (error is PlexException) {
      if (error.type.isAuthError) return FailureKind.auth;
      if (error.isNetworkFailure) return FailureKind.network;
    }
    return commonFailureKind(error) ?? FailureKind.other;
  }

  PlexClient get _connected {
    final c = _client;
    if (c == null) throw NotConnectedException(name);
    return c;
  }

  String get _section {
    final s = _musicSectionId;
    if (s == null) throw NotConnectedException(name);
    return s;
  }

  final _trackSearch = MergedSearch<ServerTrack>((t) => t.id);
  final _albumSearch = MergedSearch<ServerAlbum>((a) => a.id);

  @override
  Future<LibraryPage<ServerTrack>> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    if (query.isNotEmpty) {
      return _trackSearch.page(
        query,
        startIndex: startIndex,
        pageSize: pageSize,
        load: () => _searchTracks(query),
      );
    }
    final res = await _connected.library.allByType(
      sectionId: _section,
      type: PlexMetadataType.track,
      start: startIndex,
      size: pageSize,
      sort: 'titleSort',
    );
    return LibraryPage([for (final m in res.items) _track(m)], res.totalSize);
  }

  // The title filter matches the item's own title only, so a song search
  // also looks up the artists and albums whose title matches and adds
  // their tracks (allLeaves and children, plain metadata routes every PMS
  // serves). Title matches come first; [MergedSearch] drops repeats.
  Future<List<Iterable<ServerTrack>>> _searchTracks(String query) async {
    final c = _connected;
    final found = await Future.wait([
      _byTitle(PlexMetadataType.track, query, MergedSearch.maxResults),
      _byTitle(PlexMetadataType.artist, query, MergedSearch.maxOwners),
      _byTitle(PlexMetadataType.album, query, MergedSearch.maxOwners),
    ]);
    final owned = await Future.wait([
      for (final a in found[1]) c.library.allLeaves(ratingKey: a.ratingKey),
      for (final a in found[2]) c.library.children(ratingKey: a.ratingKey),
    ]);
    return [
      for (final group in [found[0], ...owned])
        [
          for (final m in group)
            if (m.type == PlexMetadataType.track) _track(m),
        ],
    ];
  }

  Future<List<PlexMetadata>> _byTitle(
    PlexMetadataType type,
    String query,
    int size,
  ) async {
    final res = await _connected.library.allByType(
      sectionId: _section,
      type: type,
      size: size,
      sort: 'titleSort',
      filters: [PlexFilter.titleContains(query)],
    );
    return res.items;
  }

  @override
  Future<LibraryPage<ServerAlbum>> fetchAlbums({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    if (query.isNotEmpty) {
      return _albumSearch.page(
        query,
        startIndex: startIndex,
        pageSize: pageSize,
        load: () => _searchAlbums(query),
      );
    }
    final res = await _connected.library.allByType(
      sectionId: _section,
      type: PlexMetadataType.album,
      start: startIndex,
      size: pageSize,
      sort: 'titleSort',
    );
    return LibraryPage([for (final m in res.items) _album(m)], res.totalSize);
  }

  // Albums by title, then the albums of the artists whose title matches.
  Future<List<Iterable<ServerAlbum>>> _searchAlbums(String query) async {
    final found = await Future.wait([
      _byTitle(PlexMetadataType.album, query, MergedSearch.maxResults),
      _byTitle(PlexMetadataType.artist, query, MergedSearch.maxOwners),
    ]);
    final owned = await Future.wait([
      for (final a in found[1])
        _connected.library.children(ratingKey: a.ratingKey),
    ]);
    return [
      for (final group in [found[0], ...owned])
        [
          for (final m in group)
            if (m.type == PlexMetadataType.album) _album(m),
        ],
    ];
  }

  ServerAlbum _album(PlexMetadata m) => ServerAlbum(
    id: m.ratingKey,
    title: m.title,
    artist: m.parentTitle ?? '',
    year: m.year,
    artUrl: _imageUrl(m.thumb),
  );

  @override
  Future<List<ServerTrack>> fetchAlbumTracks(ServerAlbum album) async {
    final children = await _connected.library.children(ratingKey: album.id);
    return [
      for (final m in children)
        if (m.type == PlexMetadataType.track) _track(m),
    ];
  }

  ServerTrack _track(PlexMetadata m) => ServerTrack(
    id: m.ratingKey,
    title: m.title,
    artist: m.grandparentTitle ?? '',
    album: m.parentTitle ?? '',
    duration: Duration(milliseconds: m.durationMs ?? 0),
    artUrl: _imageUrl(m.parentThumb ?? m.grandparentThumb),
    isFavorite: m.isFavorite,
  );

  // Album or artist thumbnail through Plex's photo transcoder (token
  // embedded).
  String? _imageUrl(String? sourcePath) {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    return _connected.images.transcodeUrl(
      sourcePath: sourcePath,
      width: 400,
      height: 400,
    );
  }

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) async {
    await _connected.playback.setFavorite(
      ratingKey: trackId,
      isFavorite: isFavorite,
    );
  }

  /// What [streamUrl] registers for [track], as the named arguments of
  /// [PlexTranscodeSessionManager.register].
  static ({
    String codec,
    int bitrateKbps,
    bool transcode,
    String protocol,
    String container,
  })
  _session(StreamOptions options) => (
    codec: options.codec.value,
    bitrateKbps: options.bitrateKbps,
    transcode: options.transcodes,
    protocol: options.protocol == StreamProtocol.dash ? 'dash' : 'hls',
    container: options.effectiveTransport == StreamTransport.mpegts
        ? 'mpegts'
        : 'mp4',
  );

  // BOTH modes hand mpv a `plex-transcode://{session}` marker that the
  // player's source resolver resolves just before playback. Plex's
  // universal `start.*` URL is not openable by mpv, so direct play resolves
  // to the original media Part URL, and a transcode runs /decision to start
  // a session and get the real start.mpd or start.m3u8 (falling back to the
  // same Part URL on a non-playable decision). Protocol and container are
  // independent on Plex, except that DASH always rides fMP4 (see
  // [StreamOptions.effectiveTransport]).
  @override
  String streamUrl(ServerTrack track, StreamOptions options) {
    final transcodes = _transcodes;
    if (transcodes == null) throw NotConnectedException(name);
    final s = _session(options);
    return transcodes.register(
      ratingKey: track.id,
      codec: s.codec,
      bitrateKbps: s.bitrateKbps,
      transcode: s.transcode,
      protocol: s.protocol,
      container: s.container,
    );
  }

  /// The session [streamUrl] registered, so a later session manager can
  /// rebuild it (the in-app player restart builds a new [PlexServer] while
  /// the queue keeps its markers).
  @override
  Map<String, Object?> mediaExtras(ServerTrack track, StreamOptions options) {
    final s = _session(options);
    return {
      PlexTranscodeSessionManager.extrasKey:
          PlexTranscodeSessionManager.sessionExtras(
            ratingKey: track.id,
            codec: s.codec,
            bitrateKbps: s.bitrateKbps,
            transcode: s.transcode,
            protocol: s.protocol,
            container: s.container,
          ),
    };
  }

  // Plex needs no demuxer override (the inherited null): its DASH and HLS
  // segmenter is exactly what the bundled ffmpeg `advanced_editlist` patch
  // targets.

  @override
  Future<void> reportStart(String itemId, {required Duration duration}) =>
      _timeline(itemId, PlexPlayState.playing, Duration.zero, duration);

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required Duration duration,
    required bool paused,
  }) => _timeline(
    itemId,
    paused ? PlexPlayState.paused : PlexPlayState.playing,
    position,
    duration,
  );

  // `continuing: true` mirrors Plex Web's track-transition report so the
  // server does not reap the still-warm transcode session when the next
  // track starts.
  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    required Duration duration,
  }) => _timeline(
    itemId,
    PlexPlayState.stopped,
    position,
    duration,
    continuing: true,
  );

  // PMS counts no play reported without the track's length, and
  // dart_plex refuses one: while the length is unknown nothing is sent.
  Future<void> _timeline(
    String ratingKey,
    PlexPlayState state,
    Duration position,
    Duration duration, {
    bool continuing = false,
  }) async {
    final c = _client;
    if (c == null || duration <= Duration.zero) return;
    try {
      await c.playback.timeline(
        ratingKey: ratingKey,
        playState: state,
        timeMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        continuing: continuing,
      );
    } catch (e) {
      StudioLog.write(
        'PlexServer: timeline(${state.name}) failed: $e',
        level: LogLevel.warn,
      );
    }
  }
}
