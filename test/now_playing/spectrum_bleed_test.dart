import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/widgets/spectrum_curve.dart';
import 'package:mpv_studio/features/now_playing/widgets/volume_control.dart';
import 'package:mpv_studio/shell/mobile_shell.dart';
import 'package:mpv_studio/shell/nav_parts.dart';
import 'package:mpv_studio/shell/snack_clearance.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The Playback spectrum runs full bleed: out of the page gutters to the
/// left, right and bottom edges of the stage panel, or of the screen
/// sides and the top of the bottom chrome on a phone. Phones in
/// landscape show no spectrum, nor does the empty page.
void main() {
  setUpAll(loadStudioFonts);

  /// The page's container: the inside of the stage panel, or the screen
  /// above the mini-player and tab bar on a phone.
  Rect containerOf(WidgetTester tester) {
    final mobile = find.byType(MobileShell);
    if (mobile.evaluate().isNotEmpty) {
      final chrome = tester.getRect(
        find.descendant(of: mobile, matching: find.byType(SnackObstacle)),
      );
      return Rect.fromLTRB(0, 0, tester.view.physicalSize.width, chrome.top);
    }
    return tester.getRect(
      find
          .descendant(
            of: find.byType(StagePanel),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
  }

  for (final s in studioSizes) {
    final landscapePhone = s.height < 480;
    testWidgets(
      landscapePhone
          ? 'no spectrum at ${s.name}'
          : 'the spectrum meets the edges at ${s.name}',
      (tester) async {
        await pumpPlayback(tester, playingTrack(), size: s);
        if (landscapePhone) {
          expect(find.byType(SpectrumCurve), findsNothing);
          return;
        }
        // A phone column scrolls: to its end, where the spectrum is.
        final scroll = find.ancestor(
          of: find.byType(SpectrumCurve, skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
        );
        if (scroll.evaluate().isNotEmpty) {
          final state = tester.state<ScrollableState>(scroll.first);
          state.position.jumpTo(state.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        final box = containerOf(tester);
        final spectrum = tester.getRect(find.byType(SpectrumCurve));
        expect(spectrum.left, moreOrLessEquals(box.left, epsilon: 0.5));
        expect(spectrum.right, moreOrLessEquals(box.right, epsilon: 0.5));
        expect(spectrum.bottom, moreOrLessEquals(box.bottom, epsilon: 0.5));
        expect(spectrum.height, greaterThan(40));
        // The rest keeps to the gutters: the volume control sits inside.
        final volume = tester.getRect(find.byType(VolumeControl));
        expect(volume.left, greaterThan(box.left + 8));
        expect(volume.right, lessThan(box.right - 8));
      },
    );
  }

  testWidgets('the empty page has no spectrum', (tester) async {
    await pumpPlayback(
      tester,
      PlaybackFake(const PlayerState()),
      size: studioSize('1440x900'),
    );
    expect(find.byType(SpectrumCurve), findsNothing);
  });
}
