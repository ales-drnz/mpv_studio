@Tags(['showcase'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/favorites_controller.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/stream/stream_actions.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../../tool/showcase/showcase.dart';
import '../stream/stream_fakes.dart';
import '../support/finders.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';
import 'showcase_servers.dart';

/// The Stream page over [player] with made-up servers, as the app builds
/// it.
class StreamSetup {
  StreamSetup(this.player, this.jellyfin, this.plex, this.resolver)
    : actions = StreamActions(player: player, guard: unguarded);

  final ShowcasePlayer player;
  final ShowcaseServer jellyfin;
  final ShowcaseServer plex;
  final SignedUrlResolver resolver;
  final StreamActions actions;

  Widget page() => StreamView(
    actions: actions,
    jellyfin: jellyfin,
    plex: plex,
    favorites: FavoritesController({
      ServerKind.jellyfin: jellyfin,
      ServerKind.plex: plex,
    }),
    resolver: resolver,
    samba: SambaTab(actions: actions, store: NoSambaLogin()),
  );
}

/// The Stream showcase (imgs/stream.gif): from the Lab's reference
/// streams to Jellyfin, a search by artist, an album opened and played,
/// the playback options and their pills; then the Resolver plays a
/// signed link that has expired, renews it and logs every call; back to
/// the Lab, where the scene began.
///
/// Rendered by `tool/showcase/render.sh stream`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('stream scene', (tester) async {
    final scene = Scene(tester, outDir: showcaseOut);
    final shelf = showcaseAlbums;
    final covers = await paintServerCovers(tester, ServerKind.jellyfin, shelf);
    await cacheNetworkCovers(tester, covers);
    final player = ShowcasePlayer.queue(
      const [],
      covers: const {},
      playing: false,
    );
    addTearDown(player.close);
    final base = DateTime(2026, 10, 14, 21, 42, 5);
    final start = tester.binding.clock.now();
    final resolver = showcaseResolver(
      () => base.add(tester.binding.clock.now().difference(start)),
    );
    final signed = SignedPlayback(player, resolver);
    player.onOpen = (m) {
      if (m.uri.startsWith('studio-signed://')) signed.open(m);
    };
    final setup = StreamSetup(
      player,
      ShowcaseServer(ServerKind.jellyfin, shelf),
      ShowcaseServer(ServerKind.plex, shelf),
      resolver,
    );

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.stream,
      page: (s) => setup.page(),
    );
    drivePlayer(scene, player);
    await scene.settleImages();

    Finder pill(String name) => find.text(name).first;
    const rest = Offset(1040, 640);

    // The warm-up plays the signed link as the scene's end does, then
    // comes back to the Lab.
    await scene.showPointer(rest);
    await tester.tap(pill('Resolver'));
    await scene.wait(500);
    await tester.tap(find.text('MP3 128k Stereo, signed'));
    await scene.wait(1700);
    await tester.tap(pill('Lab'));
    await scene.wait(1200);
    await scene.settleImages();

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(250);

    // Jellyfin: search by artist.
    await scene.moveOnto(pill('Jellyfin'));
    await scene.click();
    await scene.wait(350);
    await scene.moveOnto(
      find.widgetWithText(TextField, 'Search songs'),
      alignment: const Alignment(-0.6, 0),
    );
    await scene.click();
    await scene.type('okafor', msPerChar: 75);
    await scene.wait(550);
    await scene.settleImages();

    // Her albums; one opens beside the grid and plays.
    await scene.moveOnto(find.text('Albums').first);
    await scene.click();
    await scene.wait(350);
    await scene.settleImages();
    await scene.moveOnto(find.text('Glass Orchard').first);
    await scene.click();
    await scene.wait(450);
    await scene.settleImages();
    await scene.moveOnto(buttonWithText<FilledButton>('Play').first);
    await scene.click();
    await scene.wait(500);

    // The playback options: the pills.
    await scene.moveOnto(find.textContaining('kbps').first);
    await scene.click();
    await scene.wait(400);
    await scene.moveOnto(find.text('Opus').last);
    await scene.click();
    await scene.wait(280);
    await scene.moveOnto(find.text('160 kbps').last);
    await scene.click();
    await scene.wait(350);
    await scene.moveOnto(find.text('Done').last);
    await scene.click();
    await scene.wait(300);

    // The Resolver: a signed link that has expired is renewed.
    await scene.moveOnto(pill('Resolver'));
    await scene.click();
    await scene.wait(300);
    await scene.moveOnto(find.text('MP3 128k Stereo, signed'));
    await scene.click();
    await scene.wait(1400);

    // Back to the Lab.
    await scene.moveOnto(pill('Lab'));
    await scene.click();
    await scene.moveTo(rest);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase stream: $frames frames at ${scene.fps} fps');
  });
}
