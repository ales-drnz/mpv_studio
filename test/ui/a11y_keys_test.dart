import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../support/layout_harness.dart';

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('the arrows move a segmented control, not the playback', (
    tester,
  ) async {
    final picked = <int>[];
    final leaked = <LogicalKeyboardKey>[];
    await pumpStudio(
      tester,
      Scaffold(
        body: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) leaked.add(event.logicalKey);
            return KeyEventResult.ignored;
          },
          child: SegmentedControl<int>(
            options: const [
              SegmentOption(0, 'Off'),
              SegmentOption(1, 'Track'),
              SegmentOption(2, 'Queue'),
            ],
            selected: 1,
            onSelect: picked.add,
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.text('Track'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(picked, [2]);
    expect(leaked, isEmpty);
  });

  testWidgets('a segment says its visible label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpStudio(
      tester,
      Scaffold(
        body: SegmentedControl<int>(
          options: const [
            SegmentOption(0, 'A-B', tooltip: 'Loop between two points'),
          ],
          selected: 0,
          onSelect: (_) {},
        ),
      ),
    );
    final node = tester.getSemantics(find.text('A-B'));
    expect(node.label, startsWith('A-B'));
    handle.dispose();
  });

  testWidgets('a dialog names its route for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
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
    );
    showStudioDialog<void>(
      host,
      title: 'Clear the log?',
      builder: (_) => const Text('All lines go.'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Clear the log?')),
      isSemantics(namesRoute: true, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('the tab bar says where each tab is and what More holds', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final size = studioSize('412x915');
    await pumpShell(
      tester,
      size: size.size,
      section: Section.console,
      input: InputMode.touch,
      padding: phoneInsets(size.size),
    );
    expect(
      tester.getSemantics(find.text('Queue').last),
      isSemantics(value: 'Tab 2 of 5'),
    );
    expect(
      tester.getSemantics(find.text('More')),
      isSemantics(value: 'Console, tab 5 of 5'),
    );
    handle.dispose();
  });

  testWidgets('tab labels stay apart at twice the text size', (tester) async {
    final size = studioSize('360x780');
    await pumpShell(
      tester,
      size: size.size,
      input: InputMode.touch,
      padding: phoneInsets(size.size),
      textScale: 2,
    );
    final queue = tester.getRect(find.text('Queue').last);
    final stream = tester.getRect(find.text('Stream').last);
    // A label at most 1.3 times its size fits its own tab.
    expect(tester.getSize(find.text('Queue').last).height, lessThan(24));
    expect(queue.right, lessThanOrEqualTo(stream.left));
  });

  testWidgets('the sidebar name keeps its words at twice the text size', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 900), textScale: 2);
    final name = tester.widget<Text>(find.text('MPV Studio'));
    final scaler =
        name.textScaler ??
        MediaQuery.textScalerOf(tester.element(find.text('MPV Studio')));
    expect(scaler.scale(10), lessThanOrEqualTo(13));
  });
}
