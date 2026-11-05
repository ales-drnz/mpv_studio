import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/widgets/controls/slider_row.dart';

/// The slider's scale (where a value sits along the track) and its
/// keyboard steps.
void main() {
  /// Pumps an [AppSlider] 300 wide that reports every change into the
  /// returned list and rebuilds with it, like a parent holding the value.
  Future<List<double>> pump(
    WidgetTester tester, {
    required double value,
    required double min,
    required double max,
    SliderScale scale = SliderScale.linear,
    double? step,
    int? divisions,
  }) async {
    final changes = <double>[];
    var current = value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => AppSlider(
                  value: current,
                  min: min,
                  max: max,
                  scale: scale,
                  step: step,
                  divisions: divisions,
                  onChanged: (v) => setState(() {
                    current = v;
                    changes.add(v);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  /// Focuses the slider from the keyboard (a tap would also move it).
  Future<void> focus(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }

  group('log scale', () {
    testWidgets('the middle of the track is the geometric mean', (
      tester,
    ) async {
      final changes = await pump(
        tester,
        value: 20,
        min: 20,
        max: 20000,
        scale: SliderScale.log,
      );
      final rect = tester.getRect(find.byType(AppSlider));
      await tester.tapAt(rect.center);
      await tester.pump();
      // sqrt(20 * 20000) = 632.5: a linear track would give 10010.
      expect(changes.last, closeTo(632.5, 40));
    });

    testWidgets('a speed of 1x sits in the middle of 0.25x to 4x', (
      tester,
    ) async {
      final changes = await pump(
        tester,
        value: 0.25,
        min: 0.25,
        max: 4,
        scale: SliderScale.log,
      );
      final rect = tester.getRect(find.byType(AppSlider));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(changes.last, closeTo(1, 0.06));
    });

    testWidgets('an arrow key steps by a ratio, to a round value', (
      tester,
    ) async {
      final changes = await pump(
        tester,
        value: 1000,
        min: 20,
        max: 20000,
        scale: SliderScale.log,
      );
      await focus(tester);
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      // A hundredth of the track: x1.07.
      expect(changes.single, inInclusiveRange(1050, 1100));
      expect(changes.single, changes.single.roundToDouble());
    });
  });

  group('keyboard steps', () {
    testWidgets('an arrow key moves by a round step', (tester) async {
      final changes = await pump(tester, value: 0, min: -24, max: 24);
      await focus(tester);
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      // A hundredth of 48 dB is 0.48, rounded to 0.5.
      expect(changes.single, 0.5);
    });

    testWidgets('shift and an arrow key move by a tenth of the step', (
      tester,
    ) async {
      final changes = await pump(tester, value: 0, min: -24, max: 24);
      await focus(tester);
      changes.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(changes.single, 0.05);
    });

    testWidgets('page up and page down move by ten steps', (tester) async {
      final changes = await pump(tester, value: 0, min: -24, max: 24);
      await focus(tester);
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(changes, [5, 0, -5]);
    });

    testWidgets('an explicit step wins', (tester) async {
      final changes = await pump(
        tester,
        value: 120,
        min: 20,
        max: 500,
        step: 10,
      );
      await focus(tester);
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes.single, 130);
    });

    testWidgets('divisions still step one at a time', (tester) async {
      final changes = await pump(
        tester,
        value: 0,
        min: -12,
        max: 12,
        divisions: 24,
      );
      await focus(tester);
      changes.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(changes, [1, 11]);
    });
  });
}
