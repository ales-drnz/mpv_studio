import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

void main() {
  testWidgets('a tablet with a keyboard plays with Space and bypasses with B', (
    tester,
  ) async {
    final rack = RackController(FakeEngine([const BassEffect(gain: 4)]));
    addTearDown(rack.dispose);
    final h = await pumpShell(
      tester,
      size: const Size(800, 1280),
      input: InputMode.touch,
      rack: rack,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(h.player.calls, contains('play'));
    expect(rack.bypass, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
