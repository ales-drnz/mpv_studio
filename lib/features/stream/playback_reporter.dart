import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'favorites_controller.dart';
import 'media_server.dart';

/// App-level service that reports playback of media-server tracks back to
/// their server (Jellyfin / Plex): start, periodic progress, and stop. This
/// drives the server's "Now Playing", play progress and on-deck, and scrobble.
///
/// It listens to the single app [Player] and routes each report to the right
/// connected [MediaServer] using the `'server'` and `'serverId'` keys
/// embedded in the playing [Media]'s extras (see `serverMedia`). Tracks
/// without those extras (the Lab tab, local files) are ignored. All
/// reporting is best effort: the servers log their own errors.
class PlaybackReporter {
  PlaybackReporter(this._player, this._servers, this._favorites);

  final Player _player;
  final Map<ServerKind, MediaServer> _servers;
  final FavoritesController _favorites;

  /// How often a still-playing track re-reports its position.
  static const _progressInterval = Duration(seconds: 15);

  ServerKind? _kind;
  String? _itemId;
  bool _started = false;

  Timer? _progressTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Begin listening. Safe to call once at app start.
  void start() {
    _subs.add(_player.stream.playlist.listen((_) => _onPlaylist()));
    // Actual-output axis: only to detect that real playback has begun.
    _subs.add(_player.stream.playing.listen(_onPlaying));
    // Intent axis (stable across seeks/buffering): drives the server
    // pause/resume report. Binding pause to `playing` would emit a spurious
    // paused→resumed pair to Jellyfin/Plex on every scrub, since `playing`
    // toggles transiently false→true while mpv reinitializes after a seek.
    _subs.add(_player.stream.playWhenReady.listen(_onIntent));
    _subs.add(
      _player.stream.completed.listen((done) {
        if (done) _reportStop();
      }),
    );
    // OS lock-screen "like" → toggle the current server track's favourite.
    _subs.add(_player.stream.mediaSessionCommands.listen(_onSessionCommand));
    // Keep the lock-screen star in sync with in-app favourite toggles.
    _favorites.addListener(_syncSessionFavorite);
  }

  Future<void> dispose() async {
    _favorites.removeListener(_syncSessionFavorite);
    _progressTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  // ─── Stream handlers ──────────────────────────────────────────────────

  void _onPlaylist() {
    final (kind, id) = _currentTrack();
    if (id == _itemId && kind == _kind) return; // same track: nothing new
    _reportStop(); // stop the previous track (no-op if none or not started)
    _kind = kind;
    _itemId = id;
    _started = false;
    _maybeStart();
    _syncSessionFavorite(); // reflect the new track's favourite on the OS star
  }

  // ─── Favourites / OS lock-screen "like" ───────────────────────────────

  /// The favourite flag the current [Media] carried in its extras (set by
  /// the Stream tab at play time), the fallback before any live toggle.
  bool _currentFavoriteFallback() {
    final playlist = _player.state.playlist;
    final items = playlist.items;
    final i = playlist.index;
    if (i < 0 || i >= items.length) return false;
    return items[i].extras?['isFavorite'] == true;
  }

  /// Push the current track's favourite state onto the OS media session so the
  /// like control shows filled/empty (no-op when nothing changed, the session
  /// is disabled, or the current item isn't a server track).
  void _syncSessionFavorite() {
    final session = _player.state.mediaSession;
    if (session == null) return;
    final fav = (_kind != null && _itemId != null)
        ? _favorites.resolved(_kind!, _itemId!, _currentFavoriteFallback())
        : false;
    if (session.isFavorite == fav) return;
    unawaited(_pushSessionFavorite(session.copyWith(isFavorite: fav)));
  }

  Future<void> _pushSessionFavorite(MediaSession session) async {
    try {
      await _player.setMediaSession(session);
    } catch (e) {
      // The lock-screen star is cosmetic: a refused update leaves it stale
      // until the next track, never breaks playback.
      debugPrint('PlaybackReporter: media session update failed: $e');
    }
  }

  void _onSessionCommand(MediaSessionCommand command) {
    if (command is! MediaSessionCommandLike) return;
    final kind = _kind, id = _itemId;
    if (kind == null || id == null) return; // not a server track
    final current = _favorites.resolved(kind, id, _currentFavoriteFallback());
    // Flip it; the controller notifies → _syncSessionFavorite updates the star.
    unawaited(_favorites.setFavorite(kind, id, !current));
  }

  void _onPlaying(bool playing) {
    if (_itemId == null) return;
    // First real output → start the session. Pause/resume reporting is driven
    // by the intent axis in [_onIntent], not here.
    if (!_started && playing) _maybeStart();
  }

  void _onIntent(bool playWhenReady) {
    if (_itemId == null || !_started) return;
    // Reflect the user's intent on the server's Now Playing, and keep the
    // progress timer in sync, stable across the seek and buffer transients of
    // the actual-output axis.
    _reportProgress(paused: !playWhenReady);
    if (playWhenReady) {
      _restartTimer();
    } else {
      _progressTimer?.cancel();
    }
  }

  // ─── Reporting ────────────────────────────────────────────────────────

  void _maybeStart() {
    if (_started || _itemId == null) return;
    if (!_player.state.playing) return; // wait for actual playback
    final server = _servers[_kind];
    if (server == null) return;
    _started = true;
    debugPrint('PlaybackReporter: start ${_kind!.name} $_itemId');
    server.reportStart(_itemId!);
    _restartTimer();
  }

  void _reportProgress({required bool paused}) {
    if (!_started || _itemId == null) return;
    _servers[_kind]?.reportProgress(
      _itemId!,
      position: _player.state.position,
      paused: paused,
    );
  }

  void _reportStop() {
    if (!_started || _itemId == null) return;
    debugPrint(
      'PlaybackReporter: stop ${_kind!.name} $_itemId '
      '@ ${_player.state.position}',
    );
    _servers[_kind]?.reportStopped(_itemId!, position: _player.state.position);
    _started = false;
    _progressTimer?.cancel();
  }

  void _restartTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressInterval, (_) {
      if (_started && _player.state.playing) _reportProgress(paused: false);
    });
  }

  // ─── Current track resolution ─────────────────────────────────────────

  /// The currently-playing track's (server kind, server item id), or
  /// (null, null) when there is no current item or it isn't a server track.
  (ServerKind?, String?) _currentTrack() {
    final playlist = _player.state.playlist;
    final items = playlist.items;
    final i = playlist.index;
    if (i < 0 || i >= items.length) return (null, null);
    final extras = items[i].extras;
    if (extras == null) return (null, null);
    final id = extras['serverId'];
    final serverName = extras['server'];
    if (id is! String || serverName is! String) return (null, null);
    final kind = ServerKind.values
        .where((k) => k.name == serverName)
        .firstOrNull;
    if (kind == null) {
      debugPrint('PlaybackReporter: unknown server "$serverName"');
      return (null, null);
    }
    return (kind, id);
  }
}
