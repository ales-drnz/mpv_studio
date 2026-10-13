import 'dart:async';

import 'package:dart_plex/dart_plex.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/studio_log.dart';

/// Owns the lifecycle of Plex audio transcode sessions.
///
/// Unlike Jellyfin (whose `/Audio/.../universal` URL is self-contained and
/// can be handed straight to mpv), Plex's transcode pipeline needs three
/// steps the client must drive itself:
///
///   1. **register** a logical session up-front and hand mpv a
///      `plex-transcode://{id}` *marker* URL (synchronous, happens in
///      [PlexServer.streamUrl]);
///   2. call `/transcode/universal/decision` **lazily**, when mpv actually
///      opens the track, through the player's source resolver
///      ([resolveSource]). This tells Plex to spin up the transcoder and
///      turns the marker into a real `start.mpd` URL;
///   3. **ping** the session every ~20 s so Plex doesn't reap it while the
///      player is paused or buffering. A reaped session makes every later
///      segment fetch 404.
///
/// When an open fails (an expired or reaped session), the resolver runs again
/// with `isRetry` set: the manager then opens a fresh Plex session for the
/// same track and hands mpv its new URL.
class PlexTranscodeSessionManager {
  PlexTranscodeSessionManager(this._client);

  final PlexClient _client;

  /// `'dash'` → `start.mpd` + fMP4 segments (sample-accurate timestamps;
  /// the path Plex documents for audio). `'hls'` → `start.m3u8` + MPEG-TS.
  static const _defaultProtocol = 'dash';

  static const _markerPrefix = 'plex-transcode://';

  /// marker id → pending entry.
  final Map<String, _PendingTranscode> _pending = {};

  /// The marker mpv most recently opened: the one the heartbeat keeps warm.
  String? _activeMarker;

  /// Pings [_activeMarker] every 20 s. Started on the first resolution,
  /// cancelled by [dispose].
  Timer? _heartbeat;

  int _seq = 0;

  String _newSessionId() =>
      'mpv-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  // ─── Registration (sync, from streamUrl) ─────────────────────────────

  /// Register a transcode session for [ratingKey] and return the
  /// `plex-transcode://{id}` marker URL to hand to mpv. The real
  /// `/decision` call is deferred to [resolveSource]. [fallbackUrl] (Plex's
  /// universal direct-play URL when null) is the last resort if the media
  /// Part cannot be found. [protocol] (`dash` → start.mpd,
  /// `hls` → start.m3u8) defaults to DASH; [container]
  /// (`mp4` → fMP4, `mpegts`) defaults to the protocol's natural one
  /// (DASH→mp4, HLS→mpegts). Both are captured per-session so different
  /// tracks can use different transports.
  String register({
    required String ratingKey,
    required String codec,
    String? fallbackUrl,
    int? bitrateKbps,
    bool transcode = true,
    String? protocol,
    String? container,
  }) {
    final marker = _newSessionId();
    _add(
      marker,
      ratingKey: ratingKey,
      codec: codec,
      fallbackUrl: fallbackUrl,
      bitrateKbps: bitrateKbps,
      transcode: transcode,
      protocol: protocol,
      container: container,
    );
    return '$_markerPrefix$marker';
  }

  /// The [Media.extras] key under which a Plex entry carries what
  /// [register] was given (see [sessionExtras]), so a session manager that
  /// never saw the marker (a new one, after the in-app player restart
  /// rebuilt the Plex client) can rebuild the session.
  static const extrasKey = 'plexSession';

  /// The extras value describing a [register] call, for [extrasKey].
  static Map<String, Object?> sessionExtras({
    required String ratingKey,
    required String codec,
    int? bitrateKbps,
    bool transcode = true,
    String? protocol,
    String? container,
  }) => {
    'ratingKey': ratingKey,
    'codec': codec,
    'bitrateKbps': ?bitrateKbps,
    'transcode': transcode,
    'protocol': ?protocol,
    'container': ?container,
  };

  /// Registers [marker] from the [sessionExtras] in [extras]; null when they
  /// do not describe a session.
  _PendingTranscode? _restore(String marker, Map<String, Object?>? extras) {
    final e = extras?[extrasKey];
    if (e is! Map) return null;
    final ratingKey = e['ratingKey'], codec = e['codec'];
    if (ratingKey is! String || codec is! String) return null;
    StudioLog.write(
      'PlexTranscode: rebuilding session $marker from its entry',
      level: LogLevel.v,
    );
    return _add(
      marker,
      ratingKey: ratingKey,
      codec: codec,
      bitrateKbps: e['bitrateKbps'] as int?,
      transcode: e['transcode'] as bool? ?? true,
      protocol: e['protocol'] as String?,
      container: e['container'] as String?,
    );
  }

  _PendingTranscode _add(
    String marker, {
    required String ratingKey,
    required String codec,
    String? fallbackUrl,
    int? bitrateKbps,
    required bool transcode,
    String? protocol,
    String? container,
  }) {
    final sessionProtocol = protocol ?? _defaultProtocol;
    final sessionContainer =
        container ?? (sessionProtocol == 'hls' ? 'mpegts' : 'mp4');
    _pending[marker] = _PendingTranscode(
      transcode: transcode,
      protocol: sessionProtocol,
      container: sessionContainer,
      session: marker,
      params: <String, dynamic>{
        'path': '/library/metadata/$ratingKey',
        'mediaIndex': 0,
        'partIndex': 0,
        'protocol': sessionProtocol,
        'directPlay': 0,
        'directStream': 0,
        'audioCodec': codec,
        if (bitrateKbps != null) ...{
          'maxAudioBitrate': bitrateKbps,
          'musicBitrate': bitrateKbps,
        },
      },
      fallbackUrl: fallbackUrl ?? _fallbackFor(ratingKey),
    );
    final pending = _pending[marker]!;
    if (_pending.length > 200) {
      _pending.remove(_pending.keys.first);
    }
    return pending;
  }

  /// Plex's universal direct-play URL for [ratingKey]: the last resort when
  /// the media Part cannot be found.
  String _fallbackFor(String ratingKey) => _client.streaming.universalAudioUrl(
    ratingKey: ratingKey,
    protocol: 'http',
    directPlay: true,
    directStream: true,
  );

  // ─── Source resolver ─────────────────────────────────────────────────

  /// The player's source resolver for Plex entries. Returns the URL to open
  /// for a `plex-transcode://` entry, or null for any other entry (Jellyfin,
  /// files, streams), which keeps its URL as is.
  ///
  /// On a retry (`request.isRetry`, the first open failed) the transcode is
  /// renewed: a fresh Plex session id and a new `/decision`, so mpv gets a
  /// different, live URL instead of the expired one.
  Future<String?> resolveSource(SourceResolveRequest request) async {
    final marker = extractMarker(request.media.uri);
    if (marker == null) return null;
    final pending = _pending[marker] ?? _restore(marker, request.media.extras);
    if (pending == null) {
      StudioLog.write(
        'PlexTranscode: no pending session for $marker',
        level: LogLevel.v,
      );
      return null;
    }
    if (request.isRetry) {
      StudioLog.write(
        'PlexTranscode: open failed, renewing session for $marker',
        level: LogLevel.v,
      );
      pending.renew(_newSessionId());
    }
    _activeMarker = marker;
    _heartbeat ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pingActive(),
    );
    return _resolve(pending);
  }

  // ─── Lazy resolution ─────────────────────────────────────────────────

  /// Runs `/decision` for [pending], then builds the real manifest URL.
  /// Memoised so a re-open (prefetch + play) doesn't re-hit `/decision`;
  /// [_PendingTranscode.renew] clears the memo for a retry.
  Future<String> _resolve(_PendingTranscode pending) async {
    final session = pending.session;
    final cached = pending.resolved;
    if (cached != null) return cached;

    // Direct-play session: skip /decision entirely and stream the original
    // media Part (the universal-transcoder start.* URL isn't openable by mpv).
    if (!pending.transcode) {
      final direct = await _directPlayUrl(
        pending.params['path'] as String,
        pending.fallbackUrl,
      );
      StudioLog.write(
        'PlexTranscode: direct play $session → ${redactUri(direct)}',
        level: LogLevel.v,
      );
      return pending.resolved = direct;
    }

    final params = pending.sessionParams(_client.credentials.clientIdentifier);
    final codec = params['audioCodec'] as String? ?? 'aac';
    final token = _client.token ?? '';
    final isHls = pending.protocol == 'hls';
    final container = pending.container;
    final manifestExt = isHls ? 'm3u8' : 'mpd';

    // Bitrate, when requested, must be enforced via add-limitation: the
    // maxAudioBitrate query param alone is ignored by Plex for music.
    final bitrate = params['maxAudioBitrate'] as int?;
    final bitrateLimit = bitrate != null
        ? '+add-limitation(scope=musicCodec&scopeName=$codec'
              '&type=upperBound&name=audio.bitrate&value=$bitrate'
              '&isRequired=false&reason=)'
        : '';
    // Override the global client profile so Plex emits the codec/container
    // we want instead of the profile's first target.
    final profileValue =
        'add-transcode-target(type=musicProfile&context=streaming'
        '&protocol=${pending.protocol}&container=$container&audioCodec=$codec)'
        '$bitrateLimit';

    try {
      final decision = await _client.streaming.decisionUniversal(
        params: params,
        extraHeaders: {'X-Plex-Client-Profile-Extra': profileValue},
      );
      // Accept any playable decision. With directPlay=0 and directStream=0
      // Plex can't direct-play, so a successful decision comes back as a
      // 1xxx code (e.g. 1001 "Direct play not available; Conversion OK"),
      // which spins up a transcode session and a valid start.mpd. As of
      // dart_plex 0.1.0 isPlayable is true for any 1xxx decision; only a
      // genuinely non-playable decision (an error code) falls through to
      // the direct part URL.
      if (!decision.isPlayable) {
        StudioLog.write(
          'PlexTranscode: decision=${decision.code} not playable '
          '→ direct play',
          level: LogLevel.v,
        );
        final direct = await _directPlayUrl(
          params['path'] as String,
          pending.fallbackUrl,
        );
        return pending.resolved = direct;
      }
      StudioLog.write(
        'PlexTranscode: decision=${decision.code} → transcode',
        level: LogLevel.v,
      );

      // ffmpeg/lavf opens the manifest directly and does NOT inherit the
      // Dio request's X-Plex-* base headers, so we embed the full client
      // identity + profile in the query string, otherwise Plex returns
      // 400 "Unable to find client profile for device".
      final queryString = params.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}',
          )
          .join('&');
      final creds = _client.credentials;
      final manifestUrl =
          '${_client.baseUrl}/music/:/transcode/universal/start.$manifestExt?$queryString'
          '&X-Plex-Token=${Uri.encodeQueryComponent(token)}'
          '&X-Plex-Client-Profile-Extra=${Uri.encodeQueryComponent(profileValue)}'
          '&X-Plex-Platform=${Uri.encodeQueryComponent(creds.platform)}'
          '&X-Plex-Device=${Uri.encodeQueryComponent(creds.deviceName)}'
          '&X-Plex-Device-Name=${Uri.encodeQueryComponent(creds.deviceName)}'
          '&X-Plex-Product=${Uri.encodeQueryComponent(creds.product)}'
          '&X-Plex-Version=${Uri.encodeQueryComponent(creds.version)}';
      StudioLog.write(
        'PlexTranscode: resolved $session (decision=${decision.code})',
        level: LogLevel.v,
      );
      return pending.resolved = manifestUrl;
    } catch (e) {
      // Network/auth failure: degrade to direct play and memoise so we
      // don't hammer /decision on every re-open.
      StudioLog.write(
        'PlexTranscode: resolve error for $session: $e → direct play',
        level: LogLevel.warn,
      );
      final direct = await _directPlayUrl(
        params['path'] as String,
        pending.fallbackUrl,
      );
      return pending.resolved = direct;
    }
  }

  /// Resolve a track to a *direct-play* URL mpv can actually open.
  ///
  /// On a direct-play or direct-stream decision (or any /decision failure)
  /// the universal-transcoder `start.*` URL is not openable by mpv: Plex
  /// serves the original file from its media Part instead. So we fetch the
  /// item metadata, take the first media Part's key and build
  /// `{baseUrl}{partKey}?download=0&X-Plex-Token=…` (the form a working Plex
  /// client uses). [metadataPath] is `/library/metadata/{ratingKey}`;
  /// [lastResort] is returned only if no part can be resolved.
  Future<String> _directPlayUrl(String metadataPath, String lastResort) async {
    final ratingKey = metadataPath.split('/').last;
    try {
      final meta = await _client.library.item(ratingKey);
      final media = (meta?.media.isNotEmpty ?? false)
          ? meta!.media.first
          : null;
      final part = (media?.parts.isNotEmpty ?? false)
          ? media!.parts.first
          : null;
      final partKey = part?.key;
      if (partKey == null) return lastResort;
      final token = _client.token ?? '';
      return '${_client.baseUrl}$partKey?download=0'
          '&X-Plex-Token=${Uri.encodeQueryComponent(token)}';
    } catch (e) {
      StudioLog.write(
        'PlexTranscode: directPlayUrl fetch failed for $ratingKey: $e',
        level: LogLevel.warn,
      );
      return lastResort;
    }
  }

  /// Keep the session mpv is playing alive (Plex reaps stagnant ones in
  /// ~2 min).
  Future<void> _pingActive() async {
    final marker = _activeMarker;
    if (marker == null || _client.baseUrl == null) return;
    final session = _pending[marker]?.session;
    if (session == null) return;
    try {
      await _client.streaming.pingUniversal(session);
    } catch (_) {
      // Silent: the next tick retries; logging would spam on hiccups.
    }
  }

  /// Stops the heartbeat and forgets every session. The manager is not
  /// used again afterwards.
  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _pending.clear();
    _activeMarker = null;
  }

  /// Parse the marker id out of a `plex-transcode://…` URL, or null if
  /// [url] isn't a marker (plain http or file URLs).
  static String? extractMarker(String url) {
    if (!url.startsWith(_markerPrefix)) return null;
    final id = url.substring(_markerPrefix.length);
    return id.isEmpty ? null : id;
  }
}

class _PendingTranscode {
  _PendingTranscode({
    required this.params,
    required this.fallbackUrl,
    required this.transcode,
    required this.protocol,
    required this.container,
    required this.session,
  });

  /// The `/decision` parameters, without the session identifiers (see
  /// [sessionParams]).
  final Map<String, dynamic> params;
  final String fallbackUrl;

  /// Plex transcode protocol for this session: `dash` (start.mpd) or `hls`
  /// (start.m3u8).
  final String protocol;

  /// Segment container Plex packages each chunk in: `mp4` (fMP4) or `mpegts`.
  /// Independent of [protocol] except that DASH only carries fMP4.
  final String container;

  /// Whether this session should transcode (`/decision` → `start.mpd`) or
  /// just direct-play the original media Part. Direct play skips `/decision`
  /// (the universal-transcoder `start.*` URL is not openable by mpv, so we
  /// always resolve to the Part URL instead).
  final bool transcode;

  /// The Plex session id currently in use. Starts as the marker id and
  /// changes on [renew].
  String session;

  /// The memoised URL for [session].
  String? resolved;

  /// [params] with this entry's session identifiers.
  Map<String, dynamic> sessionParams(String clientId) => {
    ...params,
    'session': session,
    'X-Plex-Client-Identifier': clientId,
    'X-Plex-Session-Identifier': session,
  };

  /// Switches to a fresh Plex session and drops the memoised URL, so the
  /// next resolution runs `/decision` again.
  void renew(String newSession) {
    session = newSession;
    resolved = null;
  }
}
