import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';

/// The shell on the Queue section (so the mini-player shows) at every
/// size of the responsive contract: dark everywhere, light on a phone in
/// both orientations, a laptop and a desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    StudioSize s,
    Palette palette,
  ) async {
    final input = inputFor(s);
    await pumpShell(
      tester,
      size: s.size,
      input: input,
      palette: palette,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
    );
    expectNoOverflow(tester, reason: s.name);
    final theme = palette.isDark ? 'dark' : 'light';
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/shell_${theme}_${s.name}.png'),
    );
  }

  for (final s in studioSizes) {
    testWidgets('dark shell at $s', (tester) async {
      await golden(tester, s, Palette.dark);
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '915x412', '1024x700', '1920x1080']) {
    testWidgets('light shell at $name', (tester) async {
      await golden(tester, studioSize(name), Palette.light);
    }, skip: skipGoldens);
  }
}
