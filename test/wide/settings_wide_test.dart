import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/settings_catalog.dart';
import 'package:mpv_studio/ui/widgets/section_body.dart';

import '../settings/settings_page_test.dart' show drain, pumpSettings;
import '../support/layout_harness.dart';

/// With room for three columns, Settings puts the group's cards in two
/// columns beside the list of groups, instead of one stretched column.
void main() {
  setUpAll(loadStudioFonts);

  Rect card(WidgetTester tester, String label) => tester.getRect(
    find.byWidgetPredicate((w) => w is SettingsGroup && w.label == label),
  );

  testWidgets('a wide window shows the cards in two columns', (tester) async {
    await pumpSettings(tester, size: '2560x1080');
    final first = card(tester, SettingsSections.playback);
    final later = card(tester, SettingsSections.visualizer);
    expect(later.left, greaterThan(first.right));
    expect(later.top, lessThan(first.bottom + 400));
    await drain(tester);
  });

  testWidgets('a laptop window keeps one column', (tester) async {
    await pumpSettings(tester, size: '1440x900');
    final first = card(tester, SettingsSections.playback);
    final later = card(tester, SettingsSections.visualizer);
    expect(later.left, first.left);
    await drain(tester);
  });

  testWidgets('Tab reads down the first column, then the second', (
    tester,
  ) async {
    await pumpSettings(tester, size: '2560x1080');
    final split = card(tester, SettingsSections.visualizer).left;
    final cardsLeft = card(tester, SettingsSections.playback).left;
    final columns = <int>[];
    for (var i = 0; i < 60; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ctx = FocusManager.instance.primaryFocus?.context;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final x = box.localToGlobal(Offset.zero).dx;
      if (x < cardsLeft - 1) continue; // the list of groups
      columns.add(x >= split - 1 ? 2 : 1);
    }
    final firstTwo = columns.indexOf(2);
    expect(firstTwo, greaterThan(0));
    expect(columns.sublist(firstTwo), isNot(contains(1)));
    await drain(tester);
  });
}
