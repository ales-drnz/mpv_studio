import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/stream/device_identity.dart';
import '../features/stream/favorites_controller.dart';
import '../features/stream/jellyfin_server.dart';
import '../features/stream/media_server.dart';
import '../features/stream/playback_reporter.dart';
import '../features/stream/plex_server.dart';
import '../features/stream/signed_url_resolver.dart';
import 'app_settings.dart';
import 'source_resolvers.dart';

/// Brings up the app-level media servers (Jellyfin and Plex), restores any
/// saved sessions, resolves the real device name for Now Playing, installs
/// the source resolvers, and starts playback reporting and the shared
/// favourites store.
///
/// These live at app scope, not inside the Stream page, so their sessions,
/// playback reporting and favourite state survive navigating away from that
/// page. Returns the servers and the [FavoritesController] for the running
/// `MpvStudio`.
Future<
  ({
    Map<ServerKind, MediaServer> servers,
    FavoritesController favorites,
    void Function() dispose,
    List<SettingFailure> failures,
  })
>
connectMediaServers(Player player) async {
  // The device name (for Now Playing) and the stable per-install device id
  // (so Jellyfin keeps the saved session) come before the servers build
  // their credentials.
  await DeviceIdentity.resolve();

  final jellyfin = JellyfinServer();
  final plex = PlexServer();
  final servers = <ServerKind, MediaServer>{
    ServerKind.jellyfin: jellyfin,
    ServerKind.plex: plex,
  };
  await Future.wait([jellyfin.tryRestore(), plex.tryRestore()]);

  // The player has one resolver slot. Plex hands mpv `plex-transcode://`
  // markers and the Resolver tab plays `studio-signed://` links; the chain
  // turns each into the real URL right before it opens. A refused install
  // only costs those links, so it never stops the launch: it joins the
  // launch's failures.
  final refused = await SourceResolverChain([
    plex.resolveSource,
    SignedUrlResolver.shared.resolve,
  ]).installOn(player);

  final favorites = FavoritesController(servers);

  // Report playback (start, progress, stop) of server tracks back to their
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
    failures: [?refused],
  );
}
