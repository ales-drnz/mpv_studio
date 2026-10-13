import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'studio_fakes.dart';

/// Settings on fakes at every size of the responsive contract: the landing
/// view (the group list, beside Listening where it fits) and the Network
/// group, dark everywhere and light on a phone, phone landscape and a
/// desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    StudioSize s,
    Palette palette, {
    required bool network,
  }) async {
    final h = await SettingsHarness.create();
    final input = inputFor(s);
    await pumpStudio(
      tester,
      h.wrap(const Scaffold(body: SettingsPage())),
      size: s.size,
      input: input,
      palette: palette,
      padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
    );
    if (network) {
      await tester.tap(find.text('Network').first);
      await tester.pumpAndSettle();
    }
    expectNoOverflow(tester, reason: s.name);
    final theme = palette.isDark ? 'dark' : 'light';
    final view = network ? 'network' : 'groups';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_${view}_${theme}_${s.name}.png'),
    );
    // The Output driver scan and the debounced save finish.
    await tester.pump(const Duration(seconds: 1));
  }

  for (final s in studioSizes) {
    for (final network in [false, true]) {
      testWidgets('dark ${network ? 'network' : 'groups'} at $s', (
        tester,
      ) async {
        await golden(tester, s, Palette.dark, network: network);
      }, skip: skipGoldens);
    }
  }

  for (final name in ['360x780', '915x412', '1440x900']) {
    for (final network in [false, true]) {
      testWidgets('light ${network ? 'network' : 'groups'} at $name', (
        tester,
      ) async {
        await golden(tester, studioSize(name), Palette.light, network: network);
      }, skip: skipGoldens);
    }
  }

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette == Palette.dark ? 'dark' : 'light';
    testWidgets('$theme search results at 412x915', (tester) async {
      final h = await SettingsHarness.create();
      final s = studioSize('412x915');
      await pumpStudio(
        tester,
        h.wrap(const Scaffold(body: SettingsPage())),
        size: s.size,
        input: InputMode.touch,
        palette: palette,
        padding: phoneInsets(s.size),
      );
      await tester.enterText(find.byType(TextField).first, 'cache');
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_search_${theme}_412x915.png'),
      );
      await tester.pump(const Duration(seconds: 1));
    }, skip: skipGoldens);
  }
}
