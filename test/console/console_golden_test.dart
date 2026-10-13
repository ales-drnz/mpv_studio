import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'console_fixture.dart';

/// The Console on a phone with the keyboard up and the suggestions open,
/// on a phone in landscape and on a desktop window; and its text at 1.3
/// on a 360 wide phone.
void main() {
  setUpAll(loadStudioFonts);

  /// Raises a 300 dp soft keyboard.
  Future<void> keyboard(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    String name, {
    bool withKeyboard = false,
    double textScale = 1,
    Palette palette = Palette.dark,
  }) async {
    final s = studioSize(name);
    final input = inputFor(s);
    final player = consolePlayer();
    await pumpConsole(
      tester,
      player,
      consoleLog(player),
      size: s.size,
      input: input,
      palette: palette,
      textScale: textScale,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
    );
    if (withKeyboard) {
      await tester.tap(find.byType(TextField).last);
      await keyboard(tester);
      await tester.enterText(find.byType(TextField).last, 'get vol');
      await tester.pumpAndSettle();
    }
  }

  testWidgets('phone with the keyboard up', (tester) async {
    await pump(tester, '360x780', withKeyboard: true);
    expectNoOverflow(tester);
    // The field and the suggestions stay above the keyboard.
    final field = tester.getRect(find.byType(TextField).last);
    expect(field.bottom, lessThanOrEqualTo(780 - 300));
    expect(find.text('volume'), findsOneWidget);
    expect(tester.getRect(find.text('volume')).bottom, lessThan(field.top));
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/console_dark_360x780.png'),
    );
  }, skip: skipGoldens);

  for (final name in ['915x412', '1440x900']) {
    testWidgets('console at $name', (tester) async {
      await pump(tester, name);
      expectNoOverflow(tester, reason: name);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/console_dark_$name.png'),
      );
    }, skip: skipGoldens);
  }

  testWidgets('light console on a phone', (tester) async {
    await pump(tester, '360x780', palette: Palette.light);
    expectNoOverflow(tester);
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/console_light_360x780.png'),
    );
  }, skip: skipGoldens);

  testWidgets('text at 1.3 fits a 360 wide phone with the keyboard up', (
    tester,
  ) async {
    await pump(tester, '360x780', withKeyboard: true, textScale: 1.3);
    expectNoOverflow(tester);
  });
}
