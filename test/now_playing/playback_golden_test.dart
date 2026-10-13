import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The Playback page in the shell with a track playing, at every size of
/// the responsive contract in dark and at four in light, plus the empty
/// page on a phone and a desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    PlaybackFake player,
    StudioSize s,
    Palette palette,
    String name,
  ) async {
    await pumpPlayback(tester, player, size: s, palette: palette);
    expectNoOverflow(tester, reason: s.name);
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  for (final s in studioSizes) {
    testWidgets('dark playback at $s', (tester) async {
      await golden(tester, playingTrack(), s, Palette.dark, 'playback_dark_$s');
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '915x412', '1440x900']) {
    testWidgets('light playback at $name', (tester) async {
      await golden(
        tester,
        playingTrack(),
        studioSize(name),
        Palette.light,
        'playback_light_$name',
      );
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '1440x900']) {
    testWidgets('empty playback at $name', (tester) async {
      await golden(
        tester,
        PlaybackFake(const PlayerState()),
        studioSize(name),
        Palette.dark,
        'playback_empty_$name',
      );
    }, skip: skipGoldens);
  }
}
