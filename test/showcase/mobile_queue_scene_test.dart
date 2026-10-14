@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../../tool/showcase/showcase.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The phone Queue showcase (imgs/mobile-queue.gif): the list flicks by
/// behind the mini-player and back; a long press opens a track's actions;
/// a swipe removes a track and Undo brings it back; a tap starts the
/// playing track over, which is where the scene began.
///
/// Rendered by `tool/showcase/render.sh mobile_queue`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('mobile queue scene', (tester) async {
    final covers = <int, Uint8List>{};
    await tester.runAsync(() async {
      for (final c in [0, 5, 2]) {
        covers[c] = await paintCover(c);
      }
    });
    final scene = Scene(tester, outDir: showcaseOut, touch: true);
    final queue = [
      ...showcaseAlbum('Night Ferry').files,
      ...showcaseAlbum('Glass Orchard').files,
      ...showcaseAlbum('Static Bloom').files,
    ];
    final player = ShowcasePlayer.queue(queue, covers: covers, index: 1);
    addTearDown(player.close);
    final details = player.details();
    addTearDown(details.dispose);

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: phoneShowcaseSize,
      section: Section.queue,
      page: (s) =>
          QueueView(player: player, guard: unguarded, details: details),
    );
    drivePlayer(scene, player);

    Finder row(String title) => find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.text(title),
    );

    // The warm-up starts the playing track as the scene's end does.
    await scene.wait(300);
    await scene.tapOn(row('Paper Lanterns'));
    await scene.wait(2500);
    await scene.settleImages();

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(500);

    // A flick down the list, behind the mini-player, and back up.
    final list = tester.getRect(find.byType(ReorderableListView));
    await scene.swipe(
      list.center + const Offset(40, 160),
      list.center + const Offset(40, -120),
      ms: 220,
    );
    await scene.wait(1300);
    await scene.swipe(
      list.center + const Offset(40, -160),
      list.center + const Offset(40, 160),
      ms: 220,
    );
    await scene.wait(1300);

    // A long press opens a track's actions; the scrim closes them.
    await scene.longPress(tester.getCenter(row('Salt and Cedar')));
    await scene.wait(1200);
    await scene.tap(const Offset(206, 120));
    await scene.wait(600);

    // A swipe removes a track; Undo brings it back.
    final lowtide = tester.getCenter(row('Lowtide'));
    await scene.swipe(
      lowtide + const Offset(80, 0),
      lowtide - const Offset(260, 0),
      ms: 260,
    );
    await scene.wait(900);
    await scene.tapOn(find.text('Undo'));
    await scene.wait(900);

    // A tap starts the playing track over.
    await scene.tapOn(row('Paper Lanterns'));
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase mobile queue: $frames frames at ${scene.fps} fps');
  });
}
