import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/setting_anchor.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';

import '../support/layout_harness.dart';
import 'settings_page_test.dart' show pumpSettings;

Finder _row(SettingEntry entry) =>
    find.byWidgetPredicate((w) => w is SettingAnchor && w.entry == entry);

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('Enter opens the first result and focuses its control', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'proxy');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.tlsVerify.title), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: _row(SettingsCatalog.httpProxy),
        matching: find.byElementPredicate((e) => e == focused),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a result found by a keyword says so', (tester) async {
    await pumpSettings(tester);
    await tester.enterText(find.byType(TextField).first, 'chipmunk');
    await tester.pumpAndSettle();
    expect(find.text('Found by: chipmunk'), findsOneWidget);
  });

  testWidgets('a misspelt search suggests the word it was close to', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.enterText(find.byType(TextField).first, 'gaplss');
    await tester.pumpAndSettle();
    expect(find.text('Search for "gapless"'), findsOneWidget);
    await tester.tap(find.text('Search for "gapless"'));
    await tester.pumpAndSettle();
    expect(find.text(SettingsCatalog.gapless.title), findsWidgets);
    expect(find.textContaining('No setting matches'), findsNothing);
  });
}
