import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'queue_fixture.dart';

/// The Queue page with three entries (a local file, the current tagged
/// stream and a failed server track) at every size, dark, and light on a
/// phone, a phone in landscape and a desktop window; the empty queue on a
/// phone and a desktop window.
void main() {
  setUpAll(loadStudioFonts);

  EdgeInsets insets(StudioSize s) =>
      inputFor(s) == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero;

  Future<void> golden(
    WidgetTester tester,
    StudioSize s,
    Palette palette, {
    bool empty = false,
  }) async {
    final (player, details) = empty
        ? emptyQueue()
        : await threeEntries(() => tester.pump());
    await pumpQueue(
      tester,
      player,
      details,
      size: s.size,
      input: inputFor(s),
      palette: palette,
      padding: insets(s),
    );
    expectNoOverflow(tester, reason: s.name);
    final theme = palette.isDark ? 'dark' : 'light';
    final kind = empty ? 'queue_empty' : 'queue';
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/${kind}_${theme}_${s.name}.png'),
    );
  }

  for (final s in studioSizes) {
    testWidgets('dark queue at $s', (tester) async {
      await golden(tester, s, Palette.dark);
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '915x412', '1440x900']) {
    testWidgets('light queue at $name', (tester) async {
      await golden(tester, studioSize(name), Palette.light);
    }, skip: skipGoldens);
  }

  for (final name in ['360x780', '1440x900']) {
    testWidgets('empty queue at $name', (tester) async {
      await golden(tester, studioSize(name), Palette.dark, empty: true);
    }, skip: skipGoldens);
  }

  for (final empty in [false, true]) {
    testWidgets('text at 1.3 fits a 360 wide phone (empty: $empty)', (
      tester,
    ) async {
      final s = studioSize('360x780');
      final (player, details) = empty
          ? emptyQueue()
          : await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        size: s.size,
        input: InputMode.touch,
        textScale: 1.3,
        padding: insets(s),
      );
      expectNoOverflow(tester);
    });
  }
}
