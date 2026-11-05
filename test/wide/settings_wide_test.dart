import 'package:flutter/material.dart';
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
}
