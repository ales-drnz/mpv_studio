import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/resize_handle.dart';

import '../support/layout_harness.dart';

void main() {
  late List<double> deltas;

  Future<void> pumpSplit(WidgetTester tester) async {
    deltas = [];
    await pumpStudio(
      tester,
      Scaffold(
        body: SizedBox(
          height: 400,
          child: Stack(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 200),
                  SizedBox(height: 24),
                  Expanded(child: SizedBox()),
                ],
              ),
              ResizeHandle.overlay(
                offset: 212,
                hit: 48,
                handle: ResizeHandle(
                  axis: Axis.horizontal,
                  hitThickness: 48,
                  label: 'Waveform height',
                  onDelta: deltas.add,
                ),
              ),
            ],
          ),
        ),
      ),
      size: const Size(400, 600),
      input: InputMode.touch,
    );
  }

  testWidgets('on touch the grip catches a full 48 dp target', (tester) async {
    await pumpSplit(tester);
    final grip = find.byType(GestureDetector).last;
    expect(tester.getSize(grip).height, greaterThanOrEqualTo(48));
    // 20 above the seam's centre: over the pane above, still the grip.
    await tester.dragFrom(const Offset(200, 192), const Offset(0, 30));
    expect(deltas.fold<double>(0, (a, b) => a + b), greaterThan(0));
  });

  testWidgets('screen readers and the keyboard can move the seam', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSplit(tester);
    final node = tester.getSemantics(find.bySemanticsLabel('Waveform height'));
    expect(
      node,
      // isSemantics replaces it from Flutter 3.40; the app still supports 3.38.
      // ignore: deprecated_member_use
      containsSemantics(
        label: 'Waveform height',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    final seam = find.semantics.byLabel('Waveform height');
    tester.semantics.increase(seam);
    tester.semantics.decrease(seam);
    expect(deltas, [16, -16]);

    deltas.clear();
    Focus.of(tester.element(find.byType(GestureDetector).last)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(deltas, [16, -16]);
    handle.dispose();
  });
}
