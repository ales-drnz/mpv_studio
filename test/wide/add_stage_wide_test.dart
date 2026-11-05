import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../effects/rack_harness.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// On a wide window the stage catalog is a report: its filters in a grid
/// of a wider dialog, where one narrow list scrolled.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('a wide window lays the catalog in columns', (tester) async {
    await pumpRack(
      tester,
      FakeEngine(const [BassEffect()]),
      size: const Size(1920, 1080),
    );
    await tester.tap(find.text('Add stage').first);
    await tester.pumpAndSettle();
    final eq = tester.getRect(find.text('Equalizer').last);
    final comp = tester.getRect(find.text('Compressor').last);
    expect(comp.top, eq.top);
    expect(comp.left, greaterThan(eq.right));
  });
}
