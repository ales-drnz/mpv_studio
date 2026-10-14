@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/cover_art.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../../tool/showcase/showcase.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The phone Playback showcase (imgs/mobile-playback.gif): the
/// mini-player over the queue swipes to the next track and back, opens
/// Playback; a double tap on the cover skips ahead, the info sheet comes
/// up and is swiped away; the Queue tab again, where the scene began.
///
/// Rendered by `tool/showcase/render.sh mobile_playback`; skipped
/// otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('mobile playback scene', (tester) async {
    final covers = <int, Uint8List>{};
    await tester.runAsync(() async => covers[0] = await paintCover(0));
    final scene = Scene(tester, outDir: showcaseOut, touch: true);
    final album = showcaseAlbum('Night Ferry').files;
    const start = Duration(seconds: 19);
    final player = ShowcasePlayer.queue(
      album,
      covers: covers,
      index: 2,
      at: start,
    );
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
    await scene.wait(1000);
    await scene.settleImages();

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(500);

    // Swipe the mini-player to the next track, and back.
    final title = tester.getCenter(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.text('Harbour Lights'),
      ),
    );
    await scene.swipe(
      title + const Offset(40, 0),
      title - const Offset(110, 0),
    );
    await scene.settleImages();
    await scene.wait(900);
    await scene.swipe(title - const Offset(60, 0), title + const Offset(90, 0));
    await scene.settleImages();
    await scene.wait(700);

    // Open Playback from it.
    await scene.tapOn(find.text('Harbour Lights').last);
    await scene.wait(900);
    await scene.settleImages();

    // A double tap on the cover's right half skips ahead.
    final cover = tester.getRect(find.byType(CoverArtView).first);
    await scene.doubleTap(cover.centerRight - Offset(cover.width / 4, 0));
    await scene.wait(900);

    // The info sheet, swiped away.
    await scene.tapOn(find.byTooltip('Track and playback info'));
    await scene.wait(1400);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await scene.swipe(
      sheet.topCenter + const Offset(0, 12),
      sheet.topCenter + const Offset(0, 380),
      ms: 240,
    );
    await scene.wait(600);

    // Back to the queue.
    await scene.tapOn(find.text('Queue').last);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase mobile playback: $frames frames at ${scene.fps} fps');
  });
}
