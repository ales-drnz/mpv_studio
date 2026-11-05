import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/widgets/focus_ring.dart';
import 'package:mpv_studio/ui/widgets/round_icon_button.dart';

/// A control focused from the keyboard shows the focus ring; one clicked
/// with the mouse does not.
void main() {
  Finder ring() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
  );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RoundIconButton(icon: Icons.add, tooltip: 'Add', onTap: () {}),
        ),
      ),
    ),
  );

  testWidgets('Tab shows the ring on a RoundIconButton', (tester) async {
    await pump(tester);
    expect(ring(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(), findsOneWidget);
  });

  testWidgets('a click focuses without the ring', (tester) async {
    await pump(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(find.byType(RoundIconButton)));
    await mouse.up();
    await tester.pump();
    expect(ring(), findsNothing);
  });
}
