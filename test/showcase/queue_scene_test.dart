@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../../tool/showcase/showcase.dart';
import '../support/finders.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The Queue showcase (imgs/queue.gif): an album playing, two tracks
/// played; a played one opens in the details pane; two files are added,
/// one is opened
/// in the details pane, dragged up the queue, sent back down from its
/// menu, then both are removed and the playing track starts over, which
/// brings the scene back to its first frame.
///
/// Rendered by `tool/showcase/render.sh queue`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('queue scene', (tester) async {
    final covers = <int, Uint8List>{};
    await tester.runAsync(() async {
      for (final c in [0, 7]) {
        covers[c] = await paintCover(c);
      }
    });
    final scene = Scene(tester, outDir: showcaseOut);
    final album = showcaseAlbum('Night Ferry').files;
    final player = ShowcasePlayer.queue([
      ...album,
      ...showcaseAlbum('Fjord Sessions').files.take(1),
      ...showcaseAlbum('Casa Azul').files.take(1),
    ], covers: covers);
    addTearDown(player.close);
    final details = player.details();
    addTearDown(details.dispose);

    // The history the badges show: two tracks played to the end. The
    // playlist reaches the details a microtask later than the end events,
    // so each step settles first.
    Future<void> at(int index) async {
      player.emit(
        (s) => s.copyWith(playlist: s.playlist.copyWith(index: index)),
      );
      await tester.pump();
    }

    for (final i in [0, 1]) {
      await at(i);
      player.loaded.add(null);
      player.endFile.add(
        const MpvFileEndedEvent(reason: MpvEndFileReason.eof, error: 0),
      );
    }
    await at(2);

    const added = [
      '/music/Mira Okafor/Glass Orchard/Sundial.flac',
      '/music/Mira Okafor/Glass Orchard/Orchard Light.flac',
    ];
    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.queue,
      page: (s) => QueueView(
        player: player,
        guard: unguarded,
        details: details,
        pickFiles: () async => added,
      ),
    );
    drivePlayer(scene, player);

    // A row of the queue list (the title also shows in the details pane
    // and the mini-player).
    Finder row(String title) => find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.text(title),
    );

    // The control of [tooltip] on the row of [title].
    Finder onRow(String title, Finder candidates) {
      final y = tester.getCenter(row(title)).dy;
      final hits = candidates.evaluate().toList();
      var best = 0;
      for (var i = 1; i < hits.length; i++) {
        final d = (tester.getCenter(candidates.at(i)).dy - y).abs();
        if (d < (tester.getCenter(candidates.at(best)).dy - y).abs()) best = i;
      }
      return candidates.at(best);
    }

    // The warm-up ends the way the scene does: a double click starts the
    // playing track and selects its row, then the pointer goes home.
    const rest = Offset(1090, 800);
    await scene.showPointer(rest);
    await scene.settleImages();
    await scene.moveOnto(row('Harbour Lights'));
    await scene.doubleClick();
    await scene.moveTo(rest, ms: 600);
    await scene.wait(900);
    await scene.settleImages();

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(450);

    // A played track in the details pane.
    await scene.moveOnto(
      row('Paper Lanterns'),
      alignment: const Alignment(-0.6, 0),
    );
    await scene.click();
    await scene.wait(900);

    // Add two files: they land at the end of the queue.
    await scene.moveOnto(buttonWithText<FilledButton>('Add files'));
    await scene.click();
    await scene.wait(500);

    // Open one in the details pane.
    await scene.moveOnto(row('Sundial'), alignment: const Alignment(-0.6, 0));
    await scene.click();
    await scene.wait(650);

    // Drag it up, to play after the current track.
    await scene.moveOnto(
      onRow('Sundial', find.byIcon(Icons.drag_indicator_rounded)),
    );
    final lowtide = tester.getCenter(row('Lowtide')).dy;
    await scene.drag(Offset(scene.pointer.dx, lowtide - 8), ms: 900);
    await scene.wait(600);

    // Its menu sends it back to the bottom.
    await scene.moveOnto(row('Sundial'), alignment: const Alignment(-0.2, 0));
    await scene.rightClick();
    await scene.wait(380);
    await scene.moveOnto(find.text('Move to bottom').last);
    await scene.click();
    await scene.wait(500);

    // Remove both added files with their row buttons.
    for (final title in ['Orchard Light', 'Sundial']) {
      await scene.moveOnto(row(title), alignment: const Alignment(-0.2, 0));
      await scene.wait(120);
      await scene.moveOnto(onRow(title, find.byTooltip('Remove')));
      await scene.click();
      await scene.wait(380);
    }

    // A double click starts the playing track over.
    await scene.moveOnto(row('Harbour Lights'));
    await scene.doubleClick();
    await scene.moveTo(rest, ms: 600);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase queue: $frames frames at ${scene.fps} fps');
  });
}
