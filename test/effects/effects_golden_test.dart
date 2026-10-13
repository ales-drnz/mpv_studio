import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_panel.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';
import 'rack_harness.dart';

/// The Effects page with a chain of three stages, the bass stage open, at
/// every size of the responsive contract (dark everywhere, light on a
/// phone, a laptop and a desktop window) and in a medium pointer window.
/// Phones, touch screens and low windows show the open stage on its own;
/// wide windows at least 600 high edit it beside the chain; the medium
/// pointer window (800x560) unfolds it in the chain.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    StudioSize s,
    Palette palette, {
    double textScale = 1,
    bool open = true,
    InputMode? input,
  }) async {
    input ??= inputFor(s);
    await pumpRack(
      tester,
      FakeEngine([
        const BassEffect(gain: 6, frequency: 120),
        const AcompressorEffect(ratio: 4),
        kMeterStage,
      ]),
      size: s.size,
      input: input,
      palette: palette,
      textScale: textScale,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
      footer: LoudnessPanel(
        meterOn: true,
        onMeterChanged: (_) {},
        readings: const Stream.empty(),
        scan: const LoudnessScan(
          state: LoudnessScanState.ready,
          integrated: -11.2,
          range: 6.4,
          truePeak: 0.9,
        ),
        normalizationOn: true,
        appliedGainDb: -6.8,
        targetLufs: -18,
      ),
      before: open ? (rack) => rack.open(rack.chain.stages.first.id) : null,
    );
    expectNoOverflow(tester, reason: s.name);
  }

  for (final s in studioSizes) {
    testWidgets('dark effects at $s', (tester) async {
      await golden(tester, s, Palette.dark);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/effects_dark_${s.name}.png'),
      );
    }, skip: skipGoldens);
  }

  testWidgets('dark effects inline at 800x560', (tester) async {
    await golden(
      tester,
      const StudioSize('800x560', 800, 560),
      Palette.dark,
      input: InputMode.pointer,
    );
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/effects_dark_800x560.png'),
    );
  }, skip: skipGoldens);

  for (final name in ['360x780', '1024x700', '1920x1080']) {
    testWidgets('light effects at $name', (tester) async {
      await golden(tester, studioSize(name), Palette.light);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/effects_light_$name.png'),
      );
    }, skip: skipGoldens);
  }

  testWidgets('text at 1.3x fits a 360 wide phone, stage open', (tester) async {
    await golden(tester, studioSize('360x780'), Palette.dark, textScale: 1.3);
  });

  testWidgets('text at 1.3x fits a 360 wide phone, whole chain', (
    tester,
  ) async {
    await golden(
      tester,
      studioSize('360x780'),
      Palette.dark,
      textScale: 1.3,
      open: false,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
  });
}
