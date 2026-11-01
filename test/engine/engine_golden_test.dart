import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/engine/engine_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/fake_player.dart';
import '../support/layout_harness.dart';

/// A stream playing from the network, its next entry queued, half the
/// waveform decoded and the loudness scan done.
FakePlayer _playing() =>
    FakePlayer(
        PlayerState(
          playWhenReady: true,
          playing: true,
          position: const Duration(seconds: 40),
          duration: const Duration(minutes: 4),
          percentPos: 16.7,
          playtimeRemaining: const Duration(minutes: 3, seconds: 20),
          streamPath: 'https://example.test/music/one.flac',
          streamOpenFilename: 'https://cdn.example.test/r/one.flac',
          demuxerViaNetwork: true,
          demuxerCacheState: const DemuxerCacheState(
            seekableRanges: [
              CacheRange(Duration(seconds: 20), Duration(seconds: 75)),
            ],
          ),
          buffer: const Duration(seconds: 75),
          bufferDuration: const Duration(seconds: 35),
          cacheSpeed: 1.8e6,
          cache: const CacheSettings(
            secs: Duration(seconds: 60),
            pause: true,
            pauseWait: Duration(seconds: 3),
          ),
          prefetchPlaylist: true,
          playlist: const Playlist([
            Media('https://example.test/music/one.flac'),
            Media(
              'https://example.test/music/two.flac',
              extras: {'title': 'Kveld'},
            ),
          ]),
          audioOutputState: AudioOutputState.active,
          currentAo: 'pipewire',
          audioDevice: const Device(name: 'pipewire', description: 'Speakers'),
          audioParams: const AudioParams(
            codecName: 'flac',
            format: Format.s32,
            sampleRate: 96000,
            hrChannels: 'stereo',
          ),
          audioOutParams: const AudioParams(
            format: Format.float32Planar,
            sampleRate: 48000,
            hrChannels: 'stereo',
          ),
          audioEffects: const [BassEffect(gain: 4), LoudnormEffect()],
          mpvVersion: 'mpv v0.41.0+r16',
          ffmpegVersion: '8.1.1',
        ),
      )
      ..playbackState = MpvPlaybackState.playing
      ..waveform = WaveformData(
        duration: const Duration(minutes: 4),
        min: Float32List.fromList([
          for (var i = 0; i < 96; i++) -0.3 - 0.4 * ((i * 7) % 10) / 10,
        ]),
        max: Float32List.fromList([
          for (var i = 0; i < 96; i++) 0.3 + 0.4 * ((i * 3) % 10) / 10,
        ]),
        rms: Float32List.fromList([
          for (var i = 0; i < 96; i++) 0.2 + 0.2 * ((i * 5) % 10) / 10,
        ]),
        filled: Uint8List.fromList([
          for (var i = 0; i < 96; i++) i < 48 ? 1 : 0,
        ]),
      )
      ..loudnessScan = const LoudnessScan(
        state: LoudnessScanState.ready,
        integrated: -11.2,
        range: 6.4,
        truePeak: 0.9,
        samplePeak: 0.8,
      );

/// The Engine page at every size of the responsive contract: dark
/// everywhere, light on a phone, a laptop and a desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> pumpEngine(
    WidgetTester tester,
    StudioSize s,
    Palette palette, {
    double textScale = 1,
  }) async {
    final input = inputFor(s);
    await pumpStudio(
      tester,
      Scaffold(
        // No sampling during the test: the charts stay as first drawn.
        body: EnginePanel(
          player: _playing(),
          interval: const Duration(hours: 1),
        ),
      ),
      size: s.size,
      input: input,
      palette: palette,
      textScale: textScale,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
    );
    expectNoOverflow(tester, reason: s.name);
  }

  for (final s in studioSizes) {
    testWidgets('dark engine at $s', (tester) async {
      await pumpEngine(tester, s, Palette.dark);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/engine_dark_${s.name}.png'),
      );
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '1024x700', '1920x1080']) {
    testWidgets('light engine at $name', (tester) async {
      await pumpEngine(tester, studioSize(name), Palette.light);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/engine_light_$name.png'),
      );
    }, skip: skipGoldens);
  }

  testWidgets('text at 1.3x fits a 360 wide phone, scrolled to the end', (
    tester,
  ) async {
    await pumpEngine(
      tester,
      studioSize('360x780'),
      Palette.dark,
      textScale: 1.3,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
  });
}
