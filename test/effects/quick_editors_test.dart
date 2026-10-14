import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/widgets/quick_editors.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// The quick editor chips' tops, one per chip.
Set<double> _rows(WidgetTester tester) => {
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('quick-'),
          )
          .evaluate())
    tester.getTopLeft(find.byWidget(e.widget)).dy,
};

Future<void> _pump(WidgetTester tester, Size size, InputMode input) async {
  final rack = RackController(FakeEngine(const []));
  addTearDown(rack.dispose);
  await pumpStudio(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: QuickEditors(rack: rack, onOpen: (_) {}),
      ),
    ),
    size: size,
    input: input,
  );
}

void main() {
  for (final name in ['780x360', '915x412']) {
    testWidgets('on a low touch screen at $name the chips scroll in one row', (
      tester,
    ) async {
      await _pump(tester, studioSize(name).size, InputMode.touch);
      expect(_rows(tester), hasLength(1));
      expect(
        find.descendant(
          of: find.byType(QuickEditors),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a tall wide window wraps the chips over several rows', (
    tester,
  ) async {
    await _pump(tester, const Size(800, 1280), InputMode.touch);
    expect(_rows(tester).length, greaterThan(1));
  });
}
