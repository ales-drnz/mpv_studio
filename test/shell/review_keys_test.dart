// The review of wip/0.5.0-ux-keys: one test per finding fixed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../now_playing/playback_fake.dart';
import '../settings/studio_fakes.dart';
import '../support/demo_page.dart';
import '../support/layout_harness.dart';

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

bool _searchFocused(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).focusNode!.hasFocus;

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('Ctrl+F works in Settings on every visit', (tester) async {
    final h = await SettingsHarness.create();
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      section: Section.nowPlaying,
      page: (s) => s == Section.settings
          ? h.wrap(const SettingsPage())
          : DemoPage(section: s),
    );
    await _ctrl(tester, LogicalKeyboardKey.digit6);
    await _ctrl(tester, LogicalKeyboardKey.keyF);
    expect(_searchFocused(tester), isTrue);
    await _ctrl(tester, LogicalKeyboardKey.digit1);
    await _ctrl(tester, LogicalKeyboardKey.digit6);
    await _ctrl(tester, LogicalKeyboardKey.keyF);
    expect(_searchFocused(tester), isTrue);
  });

  testWidgets('a switch from the mini-player puts the focus in the page', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 900));
    await tester.tap(find.text('Paper Lanterns').first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      focused.findAncestorWidgetOfExactType<DemoPage>()?.section,
      Section.nowPlaying,
    );
  });

  testWidgets('Right from an unpicked segment moves from that segment', (
    tester,
  ) async {
    final picked = <int>[];
    await pumpStudio(
      tester,
      Scaffold(
        body: Row(
          children: [
            Expanded(
              child: SegmentedControl<int>(
                options: const [
                  SegmentOption(0, 'Off'),
                  SegmentOption(1, 'Track'),
                  SegmentOption(2, 'Queue'),
                ],
                selected: 0,
                onSelect: picked.add,
              ),
            ),
            const TextButton(onPressed: null, child: Text('next')),
          ],
        ),
      ),
    );
    Focus.of(tester.element(find.text('Track'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(picked, [2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // At the end it stays in the control.
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      focused.findAncestorWidgetOfExactType<SegmentedControl<int>>(),
      isNotNull,
    );
  });

  testWidgets('Escape with nothing to close reaches a tooltip', (tester) async {
    await pumpShell(tester, size: const Size(1440, 900));
    final escapes = <KeyEventResult>[];
    final root = FocusManager.instance.rootScope;
    root.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        escapes.add(KeyEventResult.handled);
      }
      return KeyEventResult.ignored;
    };
    addTearDown(() => root.onKeyEvent = null);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(escapes, hasLength(1), reason: 'the shell let Escape through');
  });

  testWidgets('Page Down on a sideways list steps the chapters', (
    tester,
  ) async {
    final fake = playingTrack();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackShortcuts(
            player: fake,
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(
                      width: 80,
                      child: Focus(autofocus: i == 0, child: Text('pill $i')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('pill 0'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(fake.calls, ['setChapter 2']);
  });

  test('the help on the web says the section keys are the app ones', () {
    expect(sectionKeysLabel(web: true), contains('app'));
    expect(sectionKeysLabel(web: false), 'Ctrl+1 to 7');
  });
}
