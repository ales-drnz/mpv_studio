import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/engine/engine_page.dart';
import 'package:mpv_studio/features/engine/widgets/analysis_view.dart';
import 'package:mpv_studio/features/engine/widgets/cache_view.dart';
import 'package:mpv_studio/features/engine/widgets/output_view.dart';
import 'package:mpv_studio/features/engine/widgets/status_view.dart';

import '../support/fake_player.dart';
import '../support/layout_harness.dart';

/// With room for three columns, Engine lays its cards in four.
void main() {
  setUpAll(loadStudioFonts);

  Future<Set<double>> columns(WidgetTester tester, Size size) async {
    final player = FakePlayer(const PlayerState());
    await pumpStudio(
      tester,
      Scaffold(body: EnginePanel(player: player)),
      size: size,
    );
    await tester.pump();
    return {
      for (final t in [StatusView, CacheView, AnalysisView, OutputView])
        tester.getRect(find.byType(t)).left.roundToDouble(),
    };
  }

  testWidgets('a wide window shows four columns', (tester) async {
    expect(await columns(tester, const Size(2560, 1080)), hasLength(4));
  });

  testWidgets('a laptop window shows two', (tester) async {
    expect(await columns(tester, const Size(1440, 900)), hasLength(2));
  });
}
