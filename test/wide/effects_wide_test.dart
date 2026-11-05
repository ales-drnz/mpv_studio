import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_panel.dart';
import 'package:mpv_studio/features/effects/widgets/stage_detail.dart';
import 'package:mpv_studio/features/effects/widgets/stage_tile.dart';

import '../effects/rack_harness.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// With room for three columns, the loudness panel stands beside the
/// stage editor instead of under the chain.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> pump(WidgetTester tester, Size size) => pumpRack(
    tester,
    FakeEngine([const BassEffect(gain: 6, frequency: 120)]),
    size: size,
    footer: LoudnessPanel(
      meterOn: true,
      onMeterChanged: (_) {},
      readings: const Stream.empty(),
      scan: null,
      normalizationOn: false,
      appliedGainDb: 0,
      targetLufs: -18,
    ),
    before: (rack) => rack.open(rack.chain.stages.first.id),
  );

  testWidgets('a wide window puts loudness in a third column', (tester) async {
    await pump(tester, const Size(2560, 1080));
    final chain = tester.getRect(find.byType(StageTile).first);
    final editor = tester.getRect(find.byType(StageDetail));
    final loudness = tester.getRect(find.byType(LoudnessPanel));
    expect(editor.left, greaterThan(chain.right));
    expect(loudness.left, greaterThan(editor.right));
  });

  testWidgets('a laptop window keeps it under the chain', (tester) async {
    await pump(tester, const Size(1440, 900));
    final chain = tester.getRect(find.byType(StageTile).first);
    final loudness = tester.getRect(find.byType(LoudnessPanel));
    expect(loudness.left, chain.left);
  });
}
