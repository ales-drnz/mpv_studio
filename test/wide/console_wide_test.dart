import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/features/console/widgets/console_side_panel.dart';

import '../console/console_fixture.dart';
import '../queue/queue_fake.dart';
import '../support/layout_harness.dart';

/// With room for three columns, the Console keeps its log at a reading
/// width and lists the commands run beside it, which a tap brings back.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> pump(WidgetTester tester, Size size) async {
    final player = QueueFakePlayer();
    final log = ConsoleLog()..attach(player);
    addTearDown(log.dispose);
    await pumpConsole(tester, player, log, size: size);
  }

  testWidgets('a wide window lists the commands run', (tester) async {
    await pump(tester, const Size(2560, 1080));
    expect(find.byType(ConsoleSidePanel), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'help');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    final ran = find.descendant(
      of: find.byType(ConsoleSidePanel),
      matching: find.text('help'),
    );
    expect(ran, findsOneWidget);
    await tester.tap(ran);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller?.text, 'help');
  });

  testWidgets('a laptop window has no side panel', (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(find.byType(ConsoleSidePanel), findsNothing);
  });
}
