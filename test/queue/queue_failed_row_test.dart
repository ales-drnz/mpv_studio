import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import '../ui/palette_contrast_test.dart' show contrast;
import 'queue_fixture.dart';

/// A failed row says so with a red dot and a dim "Failed" (no red on a
/// red pill, no second line of red): the label reads at 4.5:1 or more on
/// the row in both themes, and the row keeps the width of the others.
void main() {
  setUpAll(loadStudioFonts);

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette.isDark ? 'dark' : 'light';

    testWidgets('$theme failed label reads on its row', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, palette: palette);
      final label = tester.widget<Text>(find.text('Failed'));
      expect(
        contrast(label.style!.color!, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('failed-dot')),
      );
      expect((dot.decoration! as ShapeDecoration).color, palette.red);
    });

    testWidgets('$theme every row has one width', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, palette: palette);
      final rows = find.byWidgetPredicate(
        (w) =>
            w is Ink &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is RoundedRectangleBorder,
      );
      final widths = {
        for (final e in rows.evaluate())
          (e.renderObject! as RenderBox).size.width,
      };
      expect(widths, hasLength(1));
    });
  }
}
