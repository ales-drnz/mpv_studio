import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../settings/settings_page_test.dart' show pumpSettings;
import '../support/demo_page.dart';
import '../support/layout_harness.dart';

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('Ctrl+2 opens the Queue and Tab goes into it', (tester) async {
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      section: Section.nowPlaying,
    );
    await _ctrl(tester, LogicalKeyboardKey.digit2);
    expect(find.text('page queue'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!.context!;
    final page = focused.findAncestorWidgetOfExactType<DemoPage>();
    expect(page?.section, Section.queue);
  });

  testWidgets('Ctrl+7 opens the Console', (tester) async {
    await pumpShell(tester, size: const Size(1440, 900));
    await _ctrl(tester, LogicalKeyboardKey.digit7);
    expect(find.text('page console'), findsOneWidget);
  });

  testWidgets('Escape closes a group pushed over the settings list', (
    tester,
  ) async {
    await pumpSettings(tester, size: '800x1280', input: InputMode.pointer);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
  });
}
