import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/spectrum_curve.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The spectrum's header shows only where it has room; hidden, the
/// keyboard does not reach its settings button either.
void main() {
  bool focusOnSettings(WidgetTester tester) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    var inside = false;
    focused.visitAncestorElements((e) {
      final w = e.widget;
      if (w is Tooltip && w.message == 'Spectrum settings') inside = true;
      return !inside && w is! SpectrumCurve;
    });
    return inside;
  }

  testWidgets('a short strip keeps the keyboard out of its settings', (
    tester,
  ) async {
    await pumpPlayback(tester, playingTrack(), size: studioSize('412x915'));
    final strip = tester.getSize(find.byType(SpectrumCurve));
    expect(strip.height, lessThan(SpectrumCurve.labelledHeight));
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusOnSettings(tester), isFalse, reason: 'after $i tabs');
    }
  });

  testWidgets('a tall strip offers them', (tester) async {
    await pumpPlayback(tester, playingTrack(), size: studioSize('1440x900'));
    var reached = false;
    for (var i = 0; i < 60 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached = focusOnSettings(tester);
    }
    expect(reached, isTrue);
  });
}
