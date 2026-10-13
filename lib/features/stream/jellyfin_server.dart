import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_identity.dart';
import 'media_server.dart';

/// A Jellyfin library through `dart_jellyfin`.
class JellyfinServer extends MediaServer {
  JellyfinClient? _client;

  // Built per access so it picks up the resolved device name. `client` is
  // the app (shown as the Jellyfin "Client"); `device` is the machine name
  // (shown as the "Device").
  JellyfinCredentials get _credentials => JellyfinCredentials(
    client: DeviceIdentity.product,
    device: DeviceIdentity.deviceName,
    deviceId: DeviceIdentity.deviceId,
    version: DeviceIdentity.version,
  );

  static const _kBase = 'jellyfin.base';
  static const _kToken = 'jellyfin.token';
  static const _kUserId = 'jellyfin.userId';

  // The PlaySessionId minted for each track's transcode (itemId to
  // session), captured when [streamUrl] builds the URL so the playback
  // reports carry the SAME id. That link is what lets Jellyfin reap a
  // track's transcode the moment we report it stopped: without it the
  // server keeps old transcodes alive across track changes and the pile-up
  // fails the next track's first segment with a 500. Bounded so a long
  // queue cannot grow it without limit.
  final Map<String, String> _playSessionByItem = {};
  int _sessionSeq = 0;
  String _nextSession() =>
      'mpv-${DateTime.now().microsecondsSinceEpoch}-${_sessionSeq++}';

  @override
  String get name => 'Jellyfin';

  @override
  ServerKind get kind => ServerKind.jellyfin;

  @override
  bool get isConnected => _client?.token != null;

  /// Jellyfin transcodes over HLS only.
  @override
  List<StreamProtocol> get protocols => const [StreamProtocol.hls];

  @override
  String get hostHint => '192.168.1.10:8096';

  @override
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    final base = normalizeServerBase(host, 8096);
    final client = JellyfinClient(baseUrl: base, credentials: _credentials);
    final auth = await client.user.authenticateByName(
      username: username,
      password: password,
    );
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
  FailureKind classify(Object error) {
    if (error is JellyfinException) {
      if (error.type.isAuthError) return FailureKind.auth;
      if (error.type.isRetriable) return FailureKind.network;
    }
    return commonFailureKind(error) ?? FailureKind.other;
  }

  JellyfinClient get _connected {
    final c = _client;
    if (c == null) throw NotConnectedException(name);
    return c;
  }

  @override
  Future<LibraryPage<ServerTrack>> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    // `fields` stays at its default (the server's own projection): the
    // music field set is opt-in since dart_jellyfin 0.1.1 and none of it is
    // used here. Title, Artists, Album, AlbumArtist and RunTimeTicks are
    // always sent, and the favourite flag rides on UserData.
    final res = await _connected.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      recursive: true,
      sortBy: const ['SortName'],
      startIndex: startIndex,
      limit: pageSize,
      searchTerm: query.isEmpty ? null : query,
    );
    return LibraryPage([
      for (final it in res.items) _track(it),
    ], res.totalRecordCount);
  }

  @override
  Future<LibraryPage<ServerAlbum>> fetchAlbums({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    final res = await _connected.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      recursive: true,
      sortBy: const ['SortName'],
      startIndex: startIndex,
      limit: pageSize,
      searchTerm: query.isEmpty ? null : query,
    );
    return LibraryPage([
      for (final it in res.items)
        ServerAlbum(
          id: it.id,
          title: it.name,
          artist: it.albumArtist ?? it.artists.join(', '),
          year: it.productionYear,
          artUrl: _imageUrl(it.id),
        ),
    ], res.totalRecordCount);
  }

  @override
  Future<List<ServerTrack>> fetchAlbumTracks(ServerAlbum album) async {
    final res = await _connected.items.list(
      parentId: album.id,
      includeItemTypes: const [JellyfinItemKind.audio],
      recursive: true,
      sortBy: const ['ParentIndexNumber', 'IndexNumber', 'SortName'],
    );
    return [for (final it in res.items) _track(it)];
  }

  ServerTrack _track(JellyfinItem it) => ServerTrack(
    id: it.id,
    title: it.name,
    artist: it.artists.isNotEmpty
        ? it.artists.join(', ')
        : (it.albumArtist ?? ''),
    album: it.album ?? '',
    // runTimeTicks are 100 ns units: microseconds = ticks / 10.
    duration: Duration(microseconds: (it.runTimeTicks ?? 0) ~/ 10),
    artUrl: _imageUrl(it.id),
    isFavorite: it.isFavorite,
  );

  // Primary image. The images API omits the token, so append it: private
  // servers reject image requests otherwise. The parameter is `ApiKey`:
  // Jellyfin 12 only reads the older `api_key` spelling when legacy
  // authorization is on, which it no longer is by default. A 404 (no art)
  // falls through to the placeholder in the UI.
  String _imageUrl(String itemId) {
    final c = _connected;
    final u = c.images.url(itemId: itemId, fillWidth: 400, fillHeight: 400);
    final token = c.token ?? '';
    return u.contains('?') ? '$u&ApiKey=$token' : '$u?ApiKey=$token';
  }

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) async {
    await _connected.userData.setFavorite(trackId, isFavorite);
  }

  @override
  String streamUrl(ServerTrack track, StreamOptions options) {
    final c = _connected;
    if (!options.transcodes) {
      return c.audio.directStreamUrl(itemId: track.id).$1;
    }
    // Transcode over HLS; the container follows the picker: fMP4 ('mp4') by
    // default, MPEG-TS ('ts') only for MP3. fMP4 is safe: the bundled
    // libmpv's waveform analyzer no longer opens the stream a second time
    // to classify it, and it was that concurrent open of the fMP4 init
    // section that used to make Jellyfin fail the first segment. A
    // per-track PlaySessionId is captured so the playback reports can reap
    // THIS transcode on stop instead of leaving it warm.
    final session = _nextSession();
    _playSessionByItem[track.id] = session;
    if (_playSessionByItem.length > 200) {
      _playSessionByItem.remove(_playSessionByItem.keys.first);
    }
    final transport = _hls(options).effectiveTransport;
    return c.audio.universalStreamUrl(
      itemId: track.id,
      audioCodec: options.codec.value,
      containers: const ['aac', 'mp3', 'flac', 'ogg', 'opus'],
      transcodingProtocol: 'hls',
      transcodingContainer: transport == StreamTransport.mpegts ? 'ts' : 'mp4',
      maxStreamingBitrate: options.bitrateKbps * 1000,
      audioBitRate: options.bitrateKbps * 1000,
      playSessionId: session,
    );
  }

  /// [options] on the only protocol Jellyfin transcodes over.
  static StreamOptions _hls(StreamOptions options) =>
      options.copyWith(protocol: StreamProtocol.hls);

  @override
  String? segmentContainer(StreamOptions options) =>
      super.segmentContainer(_hls(options));

  // `seg_max_retry=5` on the HLS demuxer (through mpv `demuxer-lavf-o`).
  // libav defaults it to 0: a single segment error aborts the whole open. A
  // live Jellyfin transcode can briefly fail a segment with a 500 under
  // load (a just-started transcode that has not produced it yet); a few
  // retries let the demuxer request it again a moment later instead of
  // failing the track. Transcode only: direct play needs nothing.
  @override
  Map<String, String>? demuxerLavfOptions(StreamOptions options) =>
      options.transcodes ? const {'seg_max_retry': '5'} : null;

  @override
  Future<void> reportStart(String itemId) => _report(
    'reportStart',
    (c) => c.playback.start(
      itemId: itemId,
      playSessionId: _playSessionByItem[itemId],
    ),
  );

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required bool paused,
  }) => _report(
    'reportProgress',
    (c) => c.playback.progress(
      itemId: itemId,
      position: position,
      isPaused: paused,
      playSessionId: _playSessionByItem[itemId],
    ),
  );

  // Carries the track's PlaySessionId so Jellyfin reaps THIS transcode now,
  // instead of leaving it warm to pile up against the next track's.
  @override
  Future<void> reportStopped(String itemId, {required Duration position}) =>
      _report(
        'reportStopped',
        (c) => c.playback.stopped(
          itemId: itemId,
          position: position,
          playSessionId: _playSessionByItem.remove(itemId),
        ),
      );

  Future<void> _report(
    String what,
    Future<void> Function(JellyfinClient c) call,
  ) async {
    final c = _client;
    if (c == null) return;
    try {
      await call(c);
    } catch (e) {
      debugPrint('JellyfinServer: $what failed: $e');
    }
  }
}
