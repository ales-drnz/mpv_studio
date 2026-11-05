import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/controls/dropdown.dart';

import '../support/layout_harness.dart';

/// The hover of a menu item takes the item's pill, on desktop too: the
/// items of Flutter's own menu lit a rectangle across the menu.
void main() {
  setUpAll(loadStudioFonts);

  Finder anyItem() => find.byWidgetPredicate((w) => w is PopupMenuItem);

  List<InkWell> inksIn(WidgetTester tester) => [
    for (final e in anyItem().evaluate())
      ...tester.widgetList<InkWell>(
        find.descendant(
          of: find.byWidget(e.widget),
          matching: find.byType(InkWell),
        ),
      ),
  ];

  void expectPills(WidgetTester tester) {
    final inks = inksIn(tester);
    expect(inks, isNotEmpty);
    for (final ink in inks) {
      expect(ink.customBorder, isA<StadiumBorder>());
    }
  }

  testWidgets('a dropdown lights its items as pills', (tester) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: AppDropdown<int>(
              value: 1,
              onChanged: (_) {},
              items: const [
                DropdownMenuItem(value: 1, child: Text('Automatic')),
                DropdownMenuItem(value: 2, child: Text('16-bit integer')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppDropdown<int>));
    await tester.pumpAndSettle();
    expectPills(tester);
  });

  testWidgets('a context menu lights its items as pills', (tester) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showStudioMenu<int>(
                context,
                position: const Offset(200, 200),
                items: const [
                  StudioMenuItem(value: 1, label: 'Play next'),
                  StudioMenuItem(value: 2, label: 'Remove', destructive: true),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expectPills(tester);
  });
}
