import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/demo_page.dart';
import '../support/layout_harness.dart';

/// A section page with a row that opens the app's touch menu on long
/// press, as a queue row does.
Widget _page(Section section) => section == Section.queue
    ? Center(
        child: StudioMenuRegion<int>(
          title: 'Blue in Green',
          items: () => const [
            StudioMenuItem(value: 1, label: 'Play next'),
            StudioMenuItem(value: 2, label: 'Remove', destructive: true),
          ],
          onSelected: (_) {},
          child: const SizedBox(width: 200, height: 48, child: Text('row')),
        ),
      )
    : DemoPage(section: section);

void main() {
  testWidgets('a touch sheet dims the whole screen and back closes it first', (
    tester,
  ) async {
    final size = studioSize('412x915');
    final shell = await pumpShell(
      tester,
      size: size.size,
      input: InputMode.touch,
      padding: phoneInsets(size.size),
      page: _page,
    );
    await tester.longPress(find.text('row'));
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsOneWidget);

    // The barrier spans the screen, over the mini-player and the tab bar.
    final barrier = find.byWidgetPredicate(
      (w) => w is ModalBarrier && w.dismissible,
    );
    expect(barrier, findsOneWidget);
    expect(tester.getRect(barrier), Offset.zero & size.size);
    final mini = tester.getRect(find.byType(MiniPlayer));
    final tabs = tester.getRect(find.text('Queue').last);
    expect(tester.getRect(barrier).contains(mini.center), isTrue);
    expect(tester.getRect(barrier).contains(tabs.center), isTrue);
    // A tap on the tab bar hits the barrier, not the tab.
    await tester.tapAt(tabs.center);
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsNothing);
    expect(
      shell.router.routerDelegate.currentConfiguration.uri.path,
      Section.queue.path,
    );

    // Android back closes the sheet and stays on the section.
    await tester.longPress(find.text('row'));
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsNothing);
    expect(find.text('row'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.text('row'))).state.uri.path,
      Section.queue.path,
    );
  });
}
