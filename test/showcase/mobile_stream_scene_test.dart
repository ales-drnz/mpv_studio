@Tags(['showcase'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../../tool/showcase/showcase.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';
import 'showcase_servers.dart';
import 'stream_scene_test.dart' show StreamSetup;

/// The phone Stream showcase (imgs/mobile-stream.gif), in the light
/// theme: a reference stream plays from the Lab; on Jellyfin an album
/// opens over the grid and a track plays with its cover; back to the
/// albums and the Lab, where the same stream starts again, which is
/// where the scene began.
///
/// Rendered by `tool/showcase/render.sh mobile_stream`; skipped
/// otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('mobile stream scene', (tester) async {
    final scene = Scene(tester, outDir: showcaseOut, touch: true);
    final shelf = showcaseAlbums;
    final covers = await paintServerCovers(tester, ServerKind.jellyfin, shelf);
    await cacheNetworkCovers(tester, covers);
    final player = ShowcasePlayer.queue(
      const [],
      covers: const {},
      playing: false,
    );
    addTearDown(player.close);
    final start = tester.binding.clock.now();
    final setup = StreamSetup(
      player,
      ShowcaseServer(ServerKind.jellyfin, shelf),
      ShowcaseServer(ServerKind.plex, shelf),
      showcaseResolver(
        () => DateTime(
          2026,
          10,
          14,
          21,
          42,
        ).add(tester.binding.clock.now().difference(start)),
      ),
    );

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: phoneShowcaseSize,
      section: Section.stream,
      palette: Palette.light,
      page: (s) => setup.page(),
    );
    drivePlayer(scene, player);
    await scene.settleImages();

    const lab = 'MP3 128k Stereo (standard)';

    // The warm-up starts the reference stream as the scene's end does.
    await scene.wait(300);
    await scene.tapOn(find.text(lab));
    await scene.wait(2900);

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(800);

    // Jellyfin's albums; one opens over the grid.
    await scene.tapOn(find.text('Jellyfin').first);
    await scene.wait(700);
    await scene.settleImages();
    await scene.tapOn(find.text('Albums').first);
    await scene.wait(700);
    await scene.settleImages();
    await scene.tapOn(find.text('Night Ferry').first);
    await scene.wait(1200);
    await scene.settleImages();

    // A track plays, its cover in the mini-player.
    await scene.tapOn(find.text('Harbour Lights').last);
    await scene.wait(1900);
    await scene.settleImages();

    // Back to the albums, and to the Lab.
    await scene.tapOn(find.byTooltip('Back to albums'));
    await scene.wait(600);
    final pills = tester.getCenter(find.text('Jellyfin').first);
    await scene.swipe(
      Offset(60, pills.dy),
      Offset(300, pills.dy),
      ms: 300,
      fling: false,
    );
    await scene.wait(300);
    await scene.tapOn(find.text('Lab').first);
    await scene.wait(700);

    // The stream again.
    await scene.tapOn(find.text(lab));
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase mobile stream: $frames frames at ${scene.fps} fps');
  });
}
