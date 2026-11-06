import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/widgets/controls/control_metrics.dart';
import 'package:mpv_studio/ui/widgets/round_icon_button.dart';

import '../support/layout_harness.dart';

/// Every button is one tap target tall: 40 with a pointer (the control
/// height, the same as the fields beside it) and 48 on touch, whatever
/// the theme's density.
void main() {
  for (final (input, expected) in [
    (InputMode.pointer, 40.0),
    (InputMode.touch, 48.0),
  ]) {
    testWidgets('buttons are $expected tall on ${input.name}', (tester) async {
      await pumpStudio(
        tester,
        Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  key: const ValueKey('filled'),
                  onPressed: () {},
                  child: const Text('Play'),
                ),
                OutlinedButton(
                  key: const ValueKey('outlined'),
                  onPressed: () {},
                  child: const Text('Open'),
                ),
                TextButton(
                  key: const ValueKey('text'),
                  onPressed: () {},
                  child: const Text('Retry'),
                ),
                IconButton(
                  key: const ValueKey('icon'),
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                ),
                RoundIconButton(
                  key: const ValueKey('round'),
                  icon: Icons.close,
                  tooltip: 'Close',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        input: input,
      );
      for (final key in ['filled', 'outlined', 'text', 'icon', 'round']) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          expected,
          reason: key,
        );
      }
    });
  }

  // A scaled label must not fill its pill from edge to edge: buttons and
  // field-like controls grow with the text instead.
  testWidgets('buttons and controls grow with a 2x text scale', (tester) async {
    late double control;
    await pumpStudio(
      tester,
      Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              control = controlHeightOf(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const ValueKey('filled'),
                    onPressed: () {},
                    child: const Text('Add files'),
                  ),
                  TextButton(
                    key: const ValueKey('text'),
                    onPressed: () {},
                    child: const Text('Remove'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      textScale: 2,
    );
    for (final (key, label) in [('filled', 'Add files'), ('text', 'Remove')]) {
      final pill = tester.getSize(find.byKey(ValueKey(key))).height;
      final text = tester.getSize(find.text(label)).height;
      expect(pill - text, greaterThanOrEqualTo(16), reason: key);
    }
    expect(control, greaterThanOrEqualTo(52));
  });
}
