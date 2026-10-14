@Tags(['showcase'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_meter.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_painter.dart';

import '../../tool/showcase/showcase.dart';
import '../support/layout_harness.dart';
import 'showcase_app.dart';
import 'showcase_player.dart';
import 'showcase_covers.dart';

/// The Playback showcase (imgs/playback.gif): the song plays with its
/// spectrum, waveform and meters; the pointer seeks on the waveform,
/// zooms in and scrolls it, sets an A-B loop (A from the waveform's menu,
/// B with the L key), opens the track info, then clears the loop, zooms
/// back out and seeks so the last frame runs into the first.
///
/// Rendered by `tool/showcase/render.sh playback`; skipped otherwise.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('playback scene', (tester) async {
    late final Uint8List cover;
    await tester.runAsync(() async => cover = await paintShowcaseCover());
    final scene = Scene(tester, outDir: showcaseOut);
    final step = scene.step;
    // The warm-up runs the meters in, so the first frame looks like the
    // middle of a song and the last one can match it.
    const warmUp = Duration(milliseconds: 1500);
    final start = _onGrid(const Duration(minutes: 1, seconds: 52), step);
    final hz = showcaseUpdateHz;
    final every = hz == null
        ? null
        : Duration(microseconds: (1e6 / hz).round());
    final grid = every ?? step;
    final player = ShowcasePlayer.playing(at: start - warmUp, cover: cover)
      ..seekGrid = grid
      ..updateInterval = every;
    addTearDown(player.close);
    await pumpShowcaseApp(
      tester,
      player,
      scene: scene,
      size: desktopShowcaseSize,
    );
    scene.onFrame = (_, dt) => player.advance(dt);

    // Places on the waveform, from its painter's view.
    final meter = scene.rectOf(find.byType(WaveformMeter));
    final waveTop = meter.top + WaveformMeter.rulerHeight;
    final waveBottom = meter.bottom - 16;
    final mid = (waveTop + waveBottom) / 2;
    WaveformPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<WaveformPainter>()
        .single;
    Offset waveAt(Duration t, {double dy = 0}) =>
        Offset(meter.left + painter().view.xOf(t, meter.width), mid + dy);

    // Home: over the spectrum, where nothing reacts to the pointer.
    final rest = Offset(meter.left + meter.width * 0.6, meter.bottom + 330);
    await scene.showPointer(rest);
    await scene.wait(warmUp.inMilliseconds);

    scene.record();
    final first = player.playhead + step;
    await scene.wait(400);

    // Hover the waveform (the time follows the pointer), click to seek.
    await scene.moveTo(
      waveAt(const Duration(minutes: 3, seconds: 27), dy: -16),
    );
    await scene.moveTo(
      waveAt(const Duration(minutes: 3, seconds: 21), dy: -12),
      ms: 300,
    );
    await scene.click();
    await scene.wait(500);

    // Zoom in twice around the playhead, then scroll a little later.
    await scene.moveOnto(find.byTooltip('Zoom in'));
    await scene.click();
    await scene.wait(260);
    await scene.click();
    await scene.wait(380);
    await scene.moveTo(Offset(meter.left + meter.width * 0.55, mid + 40));
    await scene.scroll(const Offset(0, 84), steps: 3, ms: 360);
    await scene.wait(220);

    // Loop A from the waveform's menu, a little behind the playhead.
    final a = player.state.position - const Duration(milliseconds: 2400);
    await scene.moveTo(waveAt(a, dy: 26));
    await scene.rightClick();
    await scene.wait(320);
    await scene.moveOnto(
      find.textContaining('Set loop A'),
      alignment: const Alignment(-0.4, 0),
    );
    await scene.click();
    await scene.wait(450);

    // Loop B at the playhead with the L key: playback goes back to A.
    await scene.press(LogicalKeyboardKey.keyL, label: 'L');
    await scene.wait(600);

    // The track info, a moment, then Close.
    await scene.moveOnto(find.byTooltip('Track and playback info'));
    await scene.click();
    await scene.wait(1000);
    await scene.moveOnto(find.text('Close'));
    await scene.click();
    await scene.wait(300);

    // L again clears the loop; zoom back out to the whole track.
    await scene.press(LogicalKeyboardKey.keyL, label: 'L');
    await scene.wait(200);
    await scene.moveOnto(find.byTooltip('Zoom out'));
    await scene.click();
    await scene.wait(260);
    await scene.click();
    await scene.wait(250);

    // Seek so that, once the pointer is home, the playhead reaches the
    // first frame's position on the frame after the last one.
    const home = 560;
    const settle = 300;
    final lead = step * (scene.framesFor(home) + scene.framesFor(settle) + 1);
    final target = _onGrid(first - lead - grid ~/ 2, grid);
    await scene.moveTo(waveAt(target, dy: -10));
    await scene.click();
    await scene.moveTo(rest, ms: home);
    while (player.playhead + step < first) {
      await scene.frame();
    }
    expect(player.playhead + step, first);

    final frames = scene.written;
    await scene.finish();
    debugPrint('showcase playback: $frames frames at ${scene.fps} fps');
  });
}

Duration _onGrid(Duration d, Duration step) =>
    step * (d.inMicroseconds / step.inMicroseconds).round();
