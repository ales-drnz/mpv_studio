import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/stream_actions.dart';
import 'package:mpv_studio/features/stream/widgets/choice_row.dart';
import 'package:mpv_studio/features/stream/widgets/stream_row.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/focus_ring.dart';

import '../support/layout_harness.dart';

void main() {
  setUpAll(loadStudioFonts);

  Future<void> pumpRow(WidgetTester tester, List<RowAction> picked) =>
      pumpStudio(
        tester,
        Scaffold(
          body: StreamRow(
            title: 'Radio Paradise',
            onTap: () {},
            menu: () => [for (final a in RowAction.queueActions) a.item],
            onMenu: picked.add,
          ),
        ),
      );

  for (final (name, press) in [
    (
      'the Menu key',
      (WidgetTester t) => t.sendKeyEvent(LogicalKeyboardKey.contextMenu),
    ),
    (
      'Shift+F10',
      (WidgetTester t) async {
        await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.f10);
        await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      },
    ),
  ]) {
    testWidgets('$name opens a stream row\'s menu', (tester) async {
      final picked = <RowAction>[];
      await pumpRow(tester, picked);
      Focus.of(tester.element(find.text('Radio Paradise'))).requestFocus();
      await tester.pumpAndSettle();
      await press(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play next'));
      await tester.pumpAndSettle();
      expect(picked, [RowAction.playNext]);
    });
  }

  testWidgets('a stream row shows the focus ring', (tester) async {
    await pumpRow(tester, []);
    expect(
      find.ancestor(of: find.byType(InkWell), matching: find.byType(FocusRing)),
      findsWidgets,
    );
  });

  testWidgets('the choice pills show the focus ring', (tester) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: ChoiceRow<int>(
          label: 'Quality',
          choices: const [Choice(1, 'Low'), Choice(2, 'High')],
          selected: 1,
          onSelected: (_) {},
        ),
      ),
    );
    expect(
      find.ancestor(of: find.text('High'), matching: find.byType(FocusRing)),
      findsOneWidget,
    );
  });

  testWidgets('the rows of a menu sheet show the focus ring', (tester) async {
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
      size: const Size(412, 915),
      input: InputMode.touch,
    );
    showStudioMenu<int>(
      host,
      items: const [StudioMenuItem(value: 1, label: 'Play next')],
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Play next'),
        matching: find.byType(FocusRing),
      ),
      findsOneWidget,
    );
  });
}
