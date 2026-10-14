@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/engine/engine_page.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/shell/sections.dart';

import '../../tool/showcase/showcase.dart';
import '../support/layout_harness.dart';
import 'effects_scene_test.dart' show showcaseChain;
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The scene's length: the A-B loop under it repeats the playback
/// exactly, so every chart and readout is the same one loop later.
const Duration _loop = Duration(seconds: 13);

/// The Engine showcase (imgs/engine.gif): a track streaming over the
/// network, the demuxer cache draining and refilling in bursts on the
/// bar and the chart, the analysis done, the next entry prefetched; the
/// effects chain goes dry with the mini-player's FX button and back.
///
/// Under the hood an A-B loop as long as the scene replays the same
/// stretch of the track, so the last frame runs into the first.
///
/// Rendered by `tool/showcase/render.sh engine`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('engine scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintCover(7));
    final scene = Scene(tester, outDir: showcaseOut);
    const server = 'https://music.example.test/stream';
    final tracks = [
      for (final (i, t) in showcaseAlbum('Fjord Sessions').files.indexed)
        t.streamedFrom('$server/fjord-sessions/${i + 1}.flac'),
    ];
    const a = Duration(minutes: 2, seconds: 10);
    final player = ShowcasePlayer.queue(
      tracks,
      covers: {7: cover},
      index: 1,
      at: a,
    );
    addTearDown(player.close);
    final b = a + _loop;
    player
      ..emit(
        (s) => s.copyWith(
          abLoopA: a,
          abLoopB: b,
          audioEffects: showcaseChain,
          streamOpenFilename: '${tracks[1].url}?token=…',
          demuxerViaNetwork: true,
          cache: const CacheSettings(
            secs: Duration(seconds: 60),
            pause: true,
            pauseWait: Duration(seconds: 3),
          ),
          prefetchPlaylist: true,
          audioOutputState: AudioOutputState.active,
          currentAo: 'pipewire',
          audioDevice: const Device(
            name:
                'pipewire/alsa_output.usb-Studio_Interface_2x2-00.analog-stereo',
            description: 'Studio Interface 2x2',
          ),
          mpvVersion: 'mpv v0.41.0',
          ffmpegVersion: '8.1.1',
        ),
      )
      ..emitExtra(
        (p) => p
          ..prefetchState = PrefetchState.ready
          ..prefetchCacheDuration = const Duration(seconds: 14),
      );
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);

    EnginePanel.debugStopwatch = () =>
        ClockStopwatch(() => tester.binding.clock.now());
    addTearDown(() => EnginePanel.debugStopwatch = Stopwatch.new);

    // The cache as a function of where the loop is: twice a loop it
    // drains as the track plays, then refills in a burst.
    void cache() {
      final into = player.playhead - a;
      final half = _loop.inMicroseconds / 2;
      final phase = (into.inMicroseconds % half) / half;
      const full = 52.0;
      final drained = half / 1e6 * 0.72;
      final ahead = phase < 0.72
          ? full - phase * half / 1e6
          : full - drained + (phase - 0.72) / 0.28 * drained;
      final aheadD = Duration(microseconds: (ahead * 1e6).round());
      final pos = player.playhead;
      player.emit(
        (s) => s.copyWith(
          demuxerCacheState: DemuxerCacheState(
            seekableRanges: [
              CacheRange(pos - const Duration(seconds: 24), pos + aheadD),
            ],
          ),
          buffer: pos + aheadD,
          bufferDuration: aheadD,
          cacheSpeed: phase < 0.72 ? 0 : 3.1e6 + 0.4e6 * (phase - 0.72),
          percentPos: pos.inMilliseconds / s.duration.inMilliseconds * 100,
          playtimeRemaining: s.duration - pos,
        ),
      );
    }

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.engine,
      rack: rack,
      page: (s) => EnginePanel(player: player, rack: rack),
    );
    drivePlayer(scene, player);
    final drive = scene.onFrame!;
    scene.onFrame = (t, dt) {
      drive(t, dt);
      cache();
    };
    const rest = Offset(1010, 650);
    await scene.showPointer(rest);

    // The warm-up fills the charts' last minute, and stops where the loop
    // starts over.
    await scene.wait(63000);
    while (player.playhead != a) {
      await scene.frame();
    }
    final frames = (_loop.inMicroseconds / scene.step.inMicroseconds).round();

    scene.record();
    await scene.wait(500);

    // Down to the cache chart, three wheel notches.
    await scene.moveTo(const Offset(520, 640));
    await scene.scroll(const Offset(0, 120), steps: 3, ms: 450);
    await scene.wait(900);

    // A stage of the chain says which filter it is.
    await scene.moveOnto(find.text('Compressor').last);
    await scene.wait(1000);

    // The mini-player's FX button plays the track dry, then the chain
    // again.
    await scene.moveOnto(find.text('FX'));
    await scene.click();
    await scene.wait(1500);
    await scene.click();
    await scene.wait(600);

    // Back up, and home.
    await scene.moveTo(const Offset(520, 560));
    await scene.scroll(const Offset(0, -120), steps: 3, ms: 450);
    await scene.wait(300);
    await scene.moveTo(rest);
    expect(scene.written, lessThan(frames));
    while (scene.written < frames) {
      await scene.frame();
    }
    expect(player.playhead, a, reason: 'the loop must close');

    await scene.finish();
    debugPrint('showcase engine: $frames frames at ${scene.fps} fps');
  });
}
