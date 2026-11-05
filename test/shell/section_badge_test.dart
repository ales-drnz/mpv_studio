import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/section_badge.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';

/// The Console's error count reads on its red badge and to screen
/// readers.
void main() {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) /
        (la > lb ? lb + 0.05 : la + 0.05);
  }

  for (final palette in [Palette.dark, Palette.light]) {
    testWidgets(
      'the count reads on the red (${palette.isDark ? 'dark' : 'light'})',
      (tester) async {
        usePalette(palette);
        final count = ValueNotifier(3);
        addTearDown(count.dispose);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorCountBadge(
                count: count,
                child: const Icon(Icons.terminal),
              ),
            ),
          ),
        );
        final badge = tester.widget<Badge>(find.byType(Badge));
        final text = badge.textColor ?? palette.onAccent;
        expect(
          contrast(text, badge.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          find.bySemanticsLabel(RegExp('3 unseen errors')),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );
  }
}
