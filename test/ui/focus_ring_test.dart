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

  testWidgets('a touch hides the ring the keyboard showed', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(), findsOneWidget);
    // A touch anywhere puts the focus highlight in touch mode.
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(const Offset(5, 5));
    await touch.up();
    await tester.pump();
    expect(ring(), findsNothing);
  });
}
