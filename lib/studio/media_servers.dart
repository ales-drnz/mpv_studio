import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/stream/favorites_controller.dart';
import '../features/stream/media_server.dart';
import '../features/stream/playback_reporter.dart';

/// Brings up the app-level media servers (Jellyfin / Plex), restores any
/// saved sessions, resolves the real device name for Now Playing, and starts
/// playback reporting + the shared favourites store.
///
/// These live at app scope — not inside the Stream page — so their sessions,
/// playback reporting and favourite state survive navigating away from that
/// page. Returns the connected servers + the [FavoritesController] for the
/// running [MpvStudio].
Future<
  ({
    Map<ServerKind, MediaServer> servers,
    FavoritesController favorites,
    void Function() dispose,
  })
>
connectMediaServers(Player player) async {
  // Resolve the real device name (for Now Playing) and the stable per-install
  // device id (so Jellyfin doesn't invalidate the saved session) before the
  // servers build their credentials.
  await Future.wait([
    resolveDeviceName().then(setMediaDeviceName),
    resolveDeviceId(),
  ]);

  final jellyfin = JellyfinServer();
  final plex = PlexServer();
  final servers = <ServerKind, MediaServer>{
    ServerKind.jellyfin: jellyfin,
    ServerKind.plex: plex,
  };
  await Future.wait([jellyfin.tryRestore(), plex.tryRestore()]);

  // Plex hands mpv `plex-transcode://` marker URLs; the source resolver turns
  // each one into the real URL right before it opens. A refused install
  // only costs Plex playback, so it never stops the launch.
  try {
    await player.setSourceResolver(plex.resolveSource);
  } on PlayerException catch (e) {
    debugPrint('Plex source resolver not installed: $e');
  }

  final favorites = FavoritesController(servers);

  // Report playback (start / progress / stop) of server tracks back to their
  // server, and bridge the OS lock-screen "like" to favourites. Lives until
  // the studio shuts down (dispose).
  final reporter = PlaybackReporter(player, servers, favorites)..start();

  return (
    servers: servers,
    favorites: favorites,
    dispose: () {
      unawaited(reporter.dispose());
      plex.dispose();
    },
  );
}
