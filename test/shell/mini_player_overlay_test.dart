import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/demo_page.dart';
import '../support/layout_harness.dart';

/// On a phone the mini-player floats over the page: the page runs on
/// under it to the tab bar, so rows show around and behind its card, and
/// still ends its content the gutter above it.
void main() {
  setUpAll(loadStudioFonts);

  const rows = 60;

  Widget longList(Section section) => PageFrame(
    title: 'Long',
    scrollable: false,
    body: Builder(
      builder: (context) => ListView(
        padding: PageEnd.padding(context),
        children: [
          for (var i = 0; i < rows; i++)
            SizedBox(
              key: ValueKey('row $i'),
              height: 56,
              child: ColoredBox(
                color: Colors.transparent,
                child: Text('Row $i'),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> pumpPhone(WidgetTester tester, {Section? page}) async {
    final s = studioSize('412x915');
    await pumpShell(
      tester,
      size: s.size,
      input: InputMode.touch,
      padding: phoneInsets(s.size),
      section: page ?? Section.queue,
      page: (sec) => sec == (page ?? Section.queue)
          ? longList(sec)
          : DemoPage(section: sec),
    );
  }

  ScrollableState listOf(WidgetTester tester) => tester.state(
    find.descendant(
      of: find.byType(PageFrame),
      matching: find.byType(Scrollable),
    ),
  );

  testWidgets('rows scroll behind the mini-player and end above it', (
    tester,
  ) async {
    await pumpPhone(tester);
    final mini = tester.getRect(find.byType(MiniPlayer));
    final list = listOf(tester);

    // Scrolled to the middle, a row is laid out and painted under the
    // mini-player, inside the list's viewport.
    list.position.jumpTo(list.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byWidget(list.widget));
    expect(viewport.bottom, greaterThanOrEqualTo(mini.bottom));
    final under = [
      for (var i = 0; i < rows; i++)
        if (find.byKey(ValueKey('row $i')).evaluate().isNotEmpty)
          tester.getRect(find.byKey(ValueKey('row $i'))),
    ].where((r) => r.overlaps(mini));
    expect(under, isNotEmpty, reason: 'no row runs under the mini-player');

    // At the end, the last row ends one gutter above the mini-player.
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final last = tester.getRect(find.byKey(const ValueKey('row ${rows - 1}')));
    final gutter = tester.element(find.byType(PageFrame)).layout.gutter;
    expect(mini.top - last.bottom, moreOrLessEquals(gutter, epsilon: 1));
  });

  testWidgets('centred content sits in the part above the mini-player', (
    tester,
  ) async {
    await pumpPhone(tester);
    final context = tester.element(find.text('Row 0'));
    final centred = PageEnd.centred(context);
    final floating = PageEnd.floatingOf(context);
    expect(floating, tester.getRect(find.byType(MiniPlayer)).height);
    expect(centred.bottom - centred.top, floating);
  });

  testWidgets('with the keyboard up nothing floats over the page', (
    tester,
  ) async {
    await pumpPhone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Row 0'));
    expect(PageEnd.floatingOf(context), 0);
  });

  testWidgets('on Playback, with no mini-player, nothing floats', (
    tester,
  ) async {
    await pumpPhone(tester, page: Section.nowPlaying);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(PageEnd.floatingOf(tester.element(find.text('Row 0'))), 0);
  });
}
