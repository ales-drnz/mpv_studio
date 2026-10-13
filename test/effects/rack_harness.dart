import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// Records which stage taps the rack opens; every tap is silent.
class RecordingTaps {
  final opened = <(AudioFilter, int, TapSide)>[];
  Stream<PcmFrame> call(AudioFilter f, int instance, TapSide side) {
    opened.add((f, instance, side));
    return const Stream.empty();
  }
}

/// Pumps the rack page over [engine] at [size], laid out for [input], and
/// returns its controller. [footer] goes under the chain output.
Future<RackController> pumpRack(
  WidgetTester tester,
  FakeEngine engine, {
  Size size = const Size(800, 2400),
  InputMode input = InputMode.pointer,
  Palette palette = Palette.dark,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  RecordingTaps? taps,
  Widget? footer,
  void Function(RackController rack)? before,
}) async {
  final rack = RackController(engine);
  addTearDown(rack.dispose);
  before?.call(rack);
  await pumpStudio(
    tester,
    Scaffold(
      body: RackEnvironment(
        taps: (taps ?? RecordingTaps()).call,
        pcm: const Stream.empty(),
        spectrum: const SpectrumSettings(),
        loudness: const Stream.empty(),
        child: SignalChainView(rack: rack, footer: footer),
      ),
    ),
    size: size,
    input: input,
    palette: palette,
    textScale: textScale,
    padding: padding,
  );
  return rack;
}
