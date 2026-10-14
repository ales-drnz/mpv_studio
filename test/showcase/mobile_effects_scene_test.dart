@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/widgets/equalizer.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/loudness_normalizer.dart';

import '../../tool/showcase/showcase.dart';
import '../settings/studio_fakes.dart';
import '../support/layout_harness.dart';
import 'effects_scene_test.dart' show effectsPage;
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The scene's length, and of the A-B loop under it.
const Duration _loop = Duration(seconds: 13);

/// The phone Effects showcase (imgs/mobile-effects.gif): the equalizer's
/// quick editor shaped with a finger, its curve and meters live, then
/// reset; back on the chain, a stage's handle drags it up and back down.
///
/// Under the hood an A-B loop as long as the scene replays the same
/// stretch of the track, so the last frame runs into the first.
///
/// Rendered by `tool/showcase/render.sh mobile_effects`; skipped
/// otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('mobile effects scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintCover(9));
    final scene = Scene(tester, outDir: showcaseOut, touch: true);
    const a = Duration(minutes: 1, seconds: 2);
    final player = ShowcasePlayer.queue(
      showcaseAlbum('Casa Azul').files,
      covers: {9: cover},
      at: a,
    )..pcmBlocks = true;
    addTearDown(player.close);
    player
      ..emit(
        (s) => s.copyWith(
          abLoopA: a,
          abLoopB: a + _loop,
          audioEffects: const [
            SuperequalizerEffect(),
            AcompressorEffect(ratio: 4, threshold: 0.125),
            kMeterStage,
          ],
        ),
      )
      ..stageTone[AudioFilter.superequalizer] = (1.15, 1.4)
      ..stageTone[AudioFilter.acompressor] = (0.72, 0.95);
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    final normalizer = LoudnessNormalizer(player, await loadSettings())
      ..restore();
    addTearDown(normalizer.dispose);

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: phoneShowcaseSize,
      section: Section.effects,
      rack: rack,
      page: (s) => effectsPage(player, rack, normalizer),
    );
    drivePlayer(scene, player);
    await scene.settleImages();

    // Starts where the loop does.
    while (player.playhead != a) {
      await scene.frame();
    }
    final frames = (_loop.inMicroseconds / scene.step.inMicroseconds).round();
    scene.record();
    await scene.wait(500);

    // The equalizer's quick editor: a finger lifts the lows and the
    // highs, the curve and the meters follow.
    await scene.tapOn(find.byKey(const ValueKey('quick-superequalizer')));
    await scene.wait(900);
    final eq = tester.getRect(find.byType(Equalizer));
    Offset at(double x, double y) =>
        Offset(eq.left + eq.width * x, eq.top + eq.height * y);
    // Band i of 18 sits at this fraction of the width; 0 dB at half the
    // height, about 3.4 % of it a decibel.
    Offset band(int i, double db) =>
        at(0.12 + 0.0493 * (i - 1), 0.5 - db * 0.034);
    for (final (i, db) in [(1, 6.0), (2, 4.0), (15, 3.0), (16, 5.0)]) {
      await scene.fingerDrag(band(i, 0), band(i, db), ms: 300);
      await scene.wait(120);
    }
    await scene.wait(900);
    await scene.tapOn(find.text('Reset'));
    await scene.wait(600);

    // Back on the chain: the compressor's handle, held, drags it first,
    // then back.
    await scene.tapOn(find.byTooltip('Back').first);
    await scene.wait(700);
    Offset handle(String title) {
      final y = tester.getCenter(find.text(title).last).dy;
      final x = tester
          .getCenter(find.byIcon(Icons.drag_indicator_rounded).first)
          .dx;
      return Offset(x, y);
    }

    final eqRow = handle('Equalizer');
    final compRow = handle('Compressor');
    await scene.longPress(
      compRow,
      holdMs: 550,
      then: eqRow - const Offset(0, 14),
      ms: 600,
    );
    await scene.wait(700);
    await scene.longPress(
      eqRow,
      holdMs: 550,
      then: compRow + const Offset(0, 14),
      ms: 600,
    );
    await scene.wait(500);

    debugPrint('frames so far ${scene.written} of $frames');
    expect(scene.written, lessThan(frames));
    while (scene.written < frames) {
      await scene.frame();
    }
    expect(player.playhead, a, reason: 'the loop must close');
    await scene.finish();
    debugPrint('showcase mobile effects: $frames frames at ${scene.fps} fps');
  });
}
