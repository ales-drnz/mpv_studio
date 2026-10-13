import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The Playback page in the shell with a track playing, at every size of
/// the responsive contract in dark and light; a track with the A-B loop,
/// shuffle, repeat and a speed set, and the info sheet, on a phone and a
/// desktop window in both themes; and the empty page on a phone and a
/// desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    PlaybackFake player,
    StudioSize s,
    Palette palette,
    String name, {
    bool info = false,
  }) async {
    await pumpPlayback(tester, player, size: s, palette: palette);
    if (info) {
      await tester.tap(find.byTooltip('Track and playback info'));
      await tester.pumpAndSettle();
    }
    expectNoOverflow(tester, reason: s.name);
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  String theme(Palette p) => p.isDark ? 'dark' : 'light';

  for (final palette in [Palette.dark, Palette.light]) {
    for (final s in studioSizes) {
      testWidgets('${theme(palette)} playback at $s', (tester) async {
        await golden(
          tester,
          playingTrack(),
          s,
          palette,
          'playback_${theme(palette)}_$s',
        );
      }, skip: skipGoldens);
    }

    for (final name in ['412x915', '1440x900']) {
      testWidgets('${theme(palette)} playback with modes at $name', (
        tester,
      ) async {
        final player = playingTrack()
          ..emit(
            (s) => s.copyWith(
              abLoopA: const Duration(minutes: 1, seconds: 40),
              abLoopB: const Duration(minutes: 2, seconds: 30),
              abLoopCount: 3,
              remainingAbLoops: 2,
              shuffle: true,
              loop: Loop.playlist,
              rate: 1.5,
            ),
          );
        await golden(
          tester,
          player,
          studioSize(name),
          palette,
          'playback_modes_${theme(palette)}_$name',
        );
      }, skip: skipGoldens);

      testWidgets('${theme(palette)} info sheet at $name', (tester) async {
        final player = playingTrack()
          ..emit(
            (s) => s.copyWith(
              audioParams: const AudioParams(
                format: Format.s16,
                sampleRate: 44100,
                channelCount: 2,
                hrChannels: 'stereo',
                codec: 'FLAC',
              ),
              audioOutParams: const AudioParams(
                format: Format.float32,
                sampleRate: 48000,
                channelCount: 2,
                hrChannels: 'stereo',
              ),
              fileFormat: 'flac',
              audioBitrate: 912000.0,
              streamPath: 'https://example.test/one.flac',
              path: 'https://example.test/one.flac',
              filename: 'one.flac',
              fileSize: 38535168,
              audioPts: const Duration(minutes: 2, seconds: 3),
              timeRemaining: const Duration(minutes: 3, seconds: 34),
              seekable: true,
            ),
          );
        await golden(
          tester,
          player,
          studioSize(name),
          palette,
          'playback_info_${theme(palette)}_$name',
          info: true,
        );
      }, skip: skipGoldens);
    }
  }

  for (final name in ['360x780', '1440x900']) {
    for (final palette in [Palette.dark, Palette.light]) {
      testWidgets('${theme(palette)} empty playback at $name', (tester) async {
        await golden(
          tester,
          PlaybackFake(const PlayerState()),
          studioSize(name),
          palette,
          'playback_empty_${theme(palette)}_$name',
        );
      }, skip: skipGoldens);
    }
  }
}
