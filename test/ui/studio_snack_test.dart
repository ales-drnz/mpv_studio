import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/widgets/studio_snack.dart';

import '../support/layout_harness.dart';

void main() {
  testWidgets('a toast floats in the theme colours with its action', (
    tester,
  ) async {
    var undone = 0;
    late BuildContext host;
    await pumpStudio(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
      palette: Palette.light,
    );
    showStudioSnack(
      host,
      'Removed',
      actionLabel: 'Undo',
      onAction: () => undone++,
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    // No per-call colours: the theme's snack bar tone applies.
    expect(bar.backgroundColor, isNull);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, Palette.light.surface4);
    await tester.tap(find.text('Undo'));
    expect(undone, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('a new toast replaces the one on screen', (tester) async {
    late BuildContext host;
    await pumpStudio(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    showStudioSnack(host, 'First');
    await tester.pumpAndSettle();
    showStudioSnack(host, 'Second');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
