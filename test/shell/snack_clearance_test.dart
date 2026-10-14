import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/desktop_shell.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/mobile_shell.dart';
import 'package:mpv_studio/shell/rail_shell.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/snack_clearance.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/studio_snack.dart';

import '../support/demo_page.dart';
import '../support/layout_harness.dart';

/// Shows a toast from the section body and returns its rect (the snack
/// bar's surface, without the margin).
Future<Rect> _showToast(WidgetTester tester) async {
  showStudioSnack(
    tester.element(find.byType(DemoPage)),
    'A-B loop cleared',
    actionLabel: 'Undo',
    onAction: () {},
  );
  await tester.pumpAndSettle();
  return tester.getRect(
    find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first,
  );
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on the bottom bar a toast floats above the mini-player and '
      'the tab bar', (tester) async {
    final size = studioSize('360x780');
    await pumpShell(
      tester,
      size: size.size,
      input: InputMode.touch,
      padding: phoneInsets(size.size),
    );
    expect(find.byType(MobileShell), findsOneWidget);
    final toast = await _showToast(tester);
    final mini = tester.getRect(find.byType(MiniPlayer));
    expect(toast.bottom, lessThanOrEqualTo(mini.top));
    // The tab bar sits under the mini-player, so it is clear too.
    expect(mini.bottom, lessThanOrEqualTo(size.height));
    await _dismiss(tester);
  });

  testWidgets('on the sidebar layout a toast floats above the mini-player', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 900));
    expect(find.byType(DesktopShell), findsOneWidget);
    final toast = await _showToast(tester);
    final mini = tester.getRect(find.byType(MiniPlayer));
    expect(toast.bottom, lessThanOrEqualTo(mini.top));
    await _dismiss(tester);
  });

  testWidgets('on a tall rail a toast floats above the mini-player bar', (
    tester,
  ) async {
    await pumpShell(
      tester,
      size: const Size(800, 1280),
      input: InputMode.touch,
    );
    expect(find.byType(RailShell), findsOneWidget);
    final toast = await _showToast(tester);
    final mini = tester.getRect(find.byType(MiniPlayer));
    expect(toast.bottom, lessThanOrEqualTo(mini.top));
    await _dismiss(tester);
  });

  testWidgets('on a low rail a toast floats beside the rail mini-player', (
    tester,
  ) async {
    final size = studioSize('780x360');
    await pumpShell(
      tester,
      size: size.size,
      input: InputMode.touch,
      padding: phoneInsets(size.size),
    );
    expect(find.byType(RailShell), findsOneWidget);
    final toast = await _showToast(tester);
    final mini = tester.getRect(find.byType(MiniPlayer));
    expect(toast.overlaps(mini), isFalse);
    expect(toast.left, greaterThanOrEqualTo(mini.right));
    await _dismiss(tester);
  });

  testWidgets('without a mini-player the toast keeps its base margin', (
    tester,
  ) async {
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      section: Section.nowPlaying,
    );
    expect(find.byType(MiniPlayer), findsNothing);
    final toast = await _showToast(tester);
    expect(toast.bottom, 900 - 8);
    await _dismiss(tester);
  });

  testWidgets('chrome that moves to another edge rebuilds its host after '
      'the frame', (tester) async {
    var edge = SnackEdge.bottom;
    late StateSetter setShell;
    late EdgeInsetsGeometry margin;
    await tester.pumpWidget(
      MaterialApp(
        home: SnackClearanceHost(
          child: StatefulBuilder(
            builder: (context, setState) {
              setShell = setState;
              margin = Theme.of(context).snackBarTheme.insetPadding!;
              return Align(
                alignment: Alignment.bottomLeft,
                child: SnackObstacle(
                  edge: edge,
                  child: const SizedBox(width: 80, height: 64),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      margin,
      SnackClearanceHost.baseMargin + const EdgeInsets.only(bottom: 64),
    );

    setShell(() => edge = SnackEdge.left);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(
      margin,
      SnackClearanceHost.baseMargin + const EdgeInsets.only(left: 80),
    );
  });
}
