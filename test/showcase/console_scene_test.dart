@Tags(['showcase'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/features/console/console_page.dart';
import 'package:mpv_studio/shell/sections.dart';

import '../../tool/showcase/showcase.dart';
import '../support/finders.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// The Console showcase (imgs/console.gif): the engine logs as a track
/// starts; a property is read with completion, set, read again from the
/// history; the level filter shows the verbose lines and goes back; the
/// log is cleared, which is where the scene started.
///
/// Rendered by `tool/showcase/render.sh console`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('console scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintCover(3));
    final scene = Scene(tester, outDir: showcaseOut);
    final album = showcaseAlbum('Quiet Machines').files;
    final player = ShowcasePlayer.queue(
      album,
      covers: {3: cover},
      index: 1,
      at: const Duration(minutes: 1, seconds: 12),
    );
    addTearDown(player.close);
    player.rawProperties
      ..['property-list'] =
          'volume,volume-max,pause,playlist-pos,playlist-count,'
          'audio-device,audio-params,demuxer-cache-duration,speed,mute'
      ..['options'] = 'volume,audio-device,cache,cache-secs,gapless-audio'
      ..['option-info/mute/type'] = 'Flag'
      ..['volume'] = '80';
    final log = ConsoleLog()..attach(player);
    addTearDown(log.dispose);

    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
      section: Section.console,
      page: (s) => ConsoleView(player: player, log: log),
    );
    drivePlayer(scene, player);

    void engine(LogLevel level, String prefix, String text) =>
        player.log.add(MpvLogEntry(prefix: prefix, level: level, text: text));
    final input = find.byType(TextField).last;
    final rest = Offset(tester.getRect(input).right - 140, 640);

    scene.keyAlignment = const Alignment(1, 0.62);
    await scene.showPointer(rest);
    await scene.wait(1500);

    scene.record();
    final first = player.playhead + scene.step;
    await scene.wait(300);

    // The engine reports a track starting, a line every few frames.
    final track = album[1];
    const lines = [
      (
        LogLevel.info,
        'cplayer',
        'Playing: /music/Lumen Hollow/Quiet Machines/02 Copper Wire.flac',
      ),
      (LogLevel.v, 'demux', 'Trying demuxers for level=normal.'),
      (
        LogLevel.v,
        'demux',
        'Detected file format: flac (FLAC (Free Lossless Audio Codec))',
      ),
      (LogLevel.info, 'cplayer', ' (+) Audio --aid=1 (flac 2ch 44100Hz)'),
      (
        LogLevel.v,
        'ad',
        'Selected decoder: flac - FLAC (Free Lossless Audio Codec)',
      ),
      (LogLevel.info, 'cplayer', 'AO: [pipewire] 48000Hz stereo 2ch floatp'),
      (
        LogLevel.v,
        'af',
        'User filter list: lavfi-equalizer, lavfi-acompressor',
      ),
      (LogLevel.info, 'cplayer', 'title: Copper Wire'),
    ];
    for (final (level, prefix, text) in lines) {
      engine(level, prefix, text.replaceAll('Copper Wire', track.title));
      await scene.wait(80);
    }

    // Read the volume: completion offers the property after "get vol".
    await scene.moveOnto(input, alignment: const Alignment(-0.6, 0));
    await scene.click();
    await scene.wait(250);
    await scene.type('get vol', msPerChar: 70);
    await scene.wait(250);
    await scene.press(LogicalKeyboardKey.tab, label: 'Tab');
    await scene.wait(200);
    await scene.submit();
    await scene.wait(400);

    // Set it.
    await scene.type('set volume 65', msPerChar: 55);
    player.rawProperties['volume'] = '65';
    await scene.wait(150);
    await scene.submit();
    await scene.wait(400);

    // The history brings the first command back.
    await scene.press(LogicalKeyboardKey.arrowUp, label: '↑', holdMs: 300);
    await scene.press(LogicalKeyboardKey.arrowUp, label: '↑', holdMs: 300);
    await scene.wait(200);
    await scene.submit();
    await scene.wait(400);

    // Back in the track, so the scene ends where it began: what has
    // played so far, and what is still to come.
    final back = ((player.playhead - first).inMilliseconds / 1000 + 7.4).ceil();
    await scene.type('seek -$back', msPerChar: 65);
    await scene.wait(120);
    await scene.submit();
    await scene.wait(350);

    // The level filter: verbose lines too, then back to info.
    Future<void> level(String from, String to) async {
      await scene.moveOnto(buttonWithText<OutlinedButton>(from));
      await scene.click();
      await scene.wait(350);
      await scene.moveOnto(find.text(to).last);
      await scene.click();
    }

    await level('Info', 'Verbose');
    await scene.wait(850);
    await level('Verbose', 'Info');
    await scene.wait(350);

    // Clear the log: back to the first frame.
    await scene.moveOnto(find.byTooltip('Clear the log'));
    await scene.click();
    await scene.wait(250);
    await scene.moveTo(rest);
    await playUntilLoop(scene, player, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase console: $frames frames at ${scene.fps} fps');
  });
}
