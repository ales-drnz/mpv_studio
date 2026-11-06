import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';
import 'queue_fixture.dart';

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('on touch a long press on the handle drags, not the menu', (
    tester,
  ) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(
      tester,
      player,
      details,
      size: const Size(412, 915),
      input: InputMode.touch,
    );
    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(player.calls.where((c) => c.startsWith('move')), isNotEmpty);
  });
}
