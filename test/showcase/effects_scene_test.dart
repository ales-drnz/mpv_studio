@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_panel.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/loudness_normalizer.dart';

import '../../tool/showcase/showcase.dart';
import '../settings/studio_fakes.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The Effects page as the app wires it, on [player] and [rack].
Widget effectsPage(
  ShowcasePlayer player,
  RackController rack,
  LoudnessNormalizer normalizer,
) {
  return RackEnvironment(
    taps: (f, instance, side) =>
        player.stream.tap(f, instance: instance, side: side),
    pcm: player.stream.pcm,
    spectrum: player.state.spectrum,
    loudness: player.stream.loudnessMeter,
    child: SignalChainView(
      rack: rack,
      footer: ListenableBuilder(
        listenable: Listenable.merge([rack, normalizer]),
        builder: (context, _) => LoudnessPanel(
          meterOn: rack.meterOn,
          onMeterChanged: rack.setMeter,
          readings: player.stream.loudnessMeter,
          scan: normalizer.lastScan,
          normalizationOn: normalizer.enabled,
          appliedGainDb: normalizer.appliedGainDb,
          targetLufs: normalizer.targetLufs,
          bypassed: rack.bypass,
        ),
      ),
    ),
  );
}

/// A chain to start from: an equalizer, a compressor and the meter.
const List<AudioEffect> showcaseChain = [
  SuperequalizerEffect(
    params: {
      '1b': 1.5,
      '2b': 1.8,
      '3b': 1.4,
      '9b': 0.8,
      '15b': 1.3,
      '16b': 1.5,
    },
  ),
  AcompressorEffect(ratio: 4, threshold: 0.125, attack: 12, release: 180),
  kMeterStage,
];

/// The Effects showcase (imgs/effects.gif): the compressor's quick editor
/// opens with its live curve and meters; a bass stage comes from the
/// catalog and is dragged up the chain; the global bypass goes on and
/// off; the loudness panel reads the meter; the bass stage goes again
/// and the compressor folds, which is where the scene began.
///
/// Rendered by `tool/showcase/render.sh effects`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('effects scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintCover(2));
    final scene = Scene(tester, outDir: showcaseOut);
    final player = ShowcasePlayer.queue(
      showcaseAlbum('Static Bloom').files,
      covers: {2: cover},
      at: const Duration(minutes: 1, seconds: 40),
    )..pcmBlocks = true;
    addTearDown(player.close);
    player
      ..emit((s) => s.copyWith(audioEffects: showcaseChain))
      ..stageTone[AudioFilter.acompressor] = (0.72, 0.95)
      ..stageTone[AudioFilter.superequalizer] = (1.1, 1.35)
      ..stageTone[AudioFilter.bass] = (1.15, 0.8);
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    final settings = await loadSettings();
    final normalizer = LoudnessNormalizer(player, settings)..restore();
    addTearDown(normalizer.dispose);

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.effects,
      rack: rack,
      page: (s) => effectsPage(player, rack, normalizer),
    );
    drivePlayer(scene, player);
    await scene.settleImages();

    // A stage row's drag handle and menu, by its title.
    Finder onStage(String title, Finder candidates) {
      // The title in the chain column, not the chip or the editor's.
      final titles = find.text(title);
      final y = [
        for (var i = 0; i < titles.evaluate().length; i++)
          tester.getCenter(titles.at(i)),
      ].firstWhere((c) => c.dx < 600 && c.dy > 180).dy;
      final hits = candidates.evaluate().length;
      var best = 0;
      for (var i = 1; i < hits; i++) {
        final d = (tester.getCenter(candidates.at(i)).dy - y).abs();
        if (d < (tester.getCenter(candidates.at(best)).dy - y).abs()) best = i;
      }
      return candidates.at(best);
    }

    const rest = Offset(1000, 720);
    await scene.showPointer(rest);
    await scene.wait(1500);

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(400);

    // The compressor's quick editor: its curve and meters, live.
    await scene.moveOnto(find.byKey(const ValueKey('quick-acompressor')));
    await scene.click();
    await scene.wait(1500);

    // A bass stage from the catalog.
    await scene.moveOnto(find.byKey(const ValueKey('rack-add')));
    await scene.click();
    await scene.wait(450);
    await scene.moveOnto(
      find.byKey(const ValueKey('add-acompressor')),
      ms: 350,
    );
    await scene.moveOnto(find.byKey(const ValueKey('add-bass')), ms: 300);
    await scene.click();
    await scene.wait(1000);

    // Dragged up, before the compressor.
    await scene.moveOnto(
      onStage('Bass', find.byIcon(Icons.drag_indicator_rounded)),
    );
    final target =
        tester
            .getCenter(onStage('Compressor', find.byTooltip('Stage actions')))
            .dy -
        12;
    await scene.drag(Offset(scene.pointer.dx, target), ms: 700);
    await scene.wait(600);

    // The global bypass, on and off.
    await scene.moveOnto(find.byKey(const ValueKey('rack-bypass')));
    await scene.click();
    await scene.wait(1100);
    await scene.click();
    await scene.wait(600);

    // The bass stage goes again.
    await scene.moveOnto(onStage('Bass', find.byTooltip('Stage actions')));
    await scene.click();
    await scene.wait(350);
    await scene.moveOnto(find.text('Remove').last);
    await scene.click();
    await scene.wait(300);
    await scene.moveTo(rest);
    await rewindToLoop(scene, player, first, tailMs: 300);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase effects: $frames frames at ${scene.fps} fps');
  });
}
