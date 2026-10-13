import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/widgets/equalizer.dart';
import 'package:mpv_studio/features/effects/widgets/stage_editor.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';
import 'rack_harness.dart';

/// Defect 3: with a stage open, its main control (the first slider, the
/// first parameter of a generic stage, the equalizer curve) is fully on
/// screen without scrolling, in low desktop windows, phones in landscape
/// and every size of the responsive contract.
void main() {
  final sizes = <(String, Size, InputMode)>[
    ('715x430', const Size(715, 430), InputMode.pointer),
    ('800x450', const Size(800, 450), InputMode.pointer),
    ('1280x500', const Size(1280, 500), InputMode.pointer),
    // 1280x500 with the desktop sidebar beside the page.
    ('1080x500', const Size(1080, 500), InputMode.pointer),
    for (final s in studioSizes) (s.name, s.size, inputFor(s)),
  ];

  Finder within(Type type) => find
      .descendant(of: find.byType(StageEditor), matching: find.byType(type))
      .first;

  final stages = <(String, AudioEffect, Finder Function())>[
    ('bass', const BassEffect(gain: 6), () => within(AppSlider)),
    ('compressor', const AcompressorEffect(ratio: 4), () => within(AppSlider)),
    ('equalizer', const SuperequalizerEffect(), () => within(Equalizer)),
    (
      'generic',
      descriptorNamed('alimiter')!.create(),
      () => within(SettingTile),
    ),
  ];

  for (final (name, size, input) in sizes) {
    for (final (label, effect, control) in stages) {
      testWidgets('the main control of an open $label stage fits $name', (
        tester,
      ) async {
        final touch = input == InputMode.touch;
        await pumpRack(
          tester,
          FakeEngine([effect, const AcompressorEffect(), kMeterStage]),
          size: size,
          input: input,
          padding: touch ? phoneInsets(size) : EdgeInsets.zero,
          before: (rack) => rack.open(rack.chain.stages.first.id),
        );
        expectNoOverflow(tester, reason: name);
        final r = tester.getRect(control());
        final view = Offset.zero & size;
        expect(
          r.top >= view.top &&
              r.left >= view.left &&
              r.bottom <= view.bottom &&
              r.right <= view.right,
          isTrue,
          reason: '$label at $name: control at $r',
        );
      });
    }
  }
}
