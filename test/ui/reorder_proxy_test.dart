import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../effects/rack_harness.dart';
import '../queue/queue_fixture.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// While a drag holds it, the item keeps its own rounded shape, lifted by
/// the token shadow: no Material box (a rectangle of the canvas colour
/// with an elevation, which read as a dark box around the row).
Future<void> _expectLiftedInShape(
  WidgetTester tester,
  Finder handle,
) async {
  final drag = await tester.startGesture(
    tester.getCenter(handle),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump(const Duration(milliseconds: 100));
  for (var i = 0; i < 6; i++) {
    await drag.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));

  final boxes = find.byWidgetPredicate(
    (w) => w is Material && (w.elevation > 0 || w.type == MaterialType.canvas),
  );
  final lifted = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is ShapeDecoration &&
        ((w.decoration as ShapeDecoration).shadows?.isNotEmpty ?? false) &&
        (w.decoration as ShapeDecoration).shape is RoundedRectangleBorder,
  );
  expect(lifted, findsOneWidget);
  final overlay = find.descendant(
    of: find.byType(Overlay).first,
    matching: boxes,
  );
  for (final e in overlay.evaluate()) {
    final m = e.widget as Material;
    // Only the dragged item's own elevation would matter; none is left.
    expect(m.elevation, 0, reason: 'a Material box behind the dragged item');
  }
  await drag.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadStudioFonts);

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette.isDark ? 'dark' : 'light';

    testWidgets('$theme a queue row lifts in its own shape', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, palette: palette);
      await _expectLiftedInShape(
        tester,
        find.byIcon(Icons.drag_indicator_rounded).first,
      );
    });

    testWidgets('$theme a rack stage lifts in its own shape', (tester) async {
      await pumpRack(
        tester,
        FakeEngine([
          const BassEffect(gain: 6),
          const AcompressorEffect(ratio: 4),
          kMeterStage,
        ]),
        palette: palette,
      );
      await _expectLiftedInShape(
        tester,
        find.byIcon(Icons.drag_indicator_rounded).first,
      );
    });
  }
}
