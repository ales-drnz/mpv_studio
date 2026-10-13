import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/features/effects/widgets/rack_parts.dart';
import 'package:mpv_studio/features/effects/widgets/stage_editor.dart';
import 'package:mpv_studio/generated/filter_catalog.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/tokens.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// Every graphic editor of the featured stages, a stage with presets and
/// the raw entry, each in its card, dark and light: the curves, the
/// diagrams and the gauges in the accent over tonal fills.
void main() {
  setUpAll(loadStudioFonts);

  final pan = kFilterCatalog.firstWhere((d) => d.name == 'pan');
  final stages = <AudioEffect>[
    const SuperequalizerEffect(params: {'2b': 2.0, '3b': 1.6, '15b': 0.5}),
    const AcompressorEffect(ratio: 4, threshold: 0.125),
    const BassEffect(gain: 6, frequency: 120),
    const TrebleEffect(gain: -4, frequency: 4000),
    const AsubboostEffect(),
    const ExtrastereoEffect(),
    const CrossfeedEffect(strength: 0.4),
    const CrystalizerEffect(),
    const LoudnormEffect(),
    pan.create(),
    const RawAudioEffect('lavfi-aecho=0.8:0.9:500:0.3'),
  ];

  for (final palette in [Palette.dark, Palette.light]) {
    final name = palette.isDark ? 'dark' : 'light';
    testWidgets('$name graphic editors', (tester) async {
      final rack = RackController(FakeEngine(stages));
      addTearDown(rack.dispose);
      await pumpStudio(
        tester,
        Scaffold(
          body: RackEnvironment(
            taps: (_, _, _) => const Stream.empty(),
            pcm: const Stream.empty(),
            spectrum: const SpectrumSettings(),
            loudness: const Stream.empty(),
            child: ListenableBuilder(
              listenable: rack,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(Tokens.s24),
                child: Wrap(
                  spacing: Tokens.s16,
                  children: [
                    for (final s in rack.chain.stages)
                      SizedBox(
                        width: 528,
                        child: RackCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(stageTitle(s.effect), style: Tokens.heading),
                              const SizedBox(height: Tokens.s8),
                              StageEditor(rack: rack, id: s.id),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        size: const Size(1680, 3000),
        input: InputMode.pointer,
        palette: palette,
      );
      expectNoOverflow(tester);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/editors_$name.png'),
      );
    }, skip: skipGoldens);
  }
}
