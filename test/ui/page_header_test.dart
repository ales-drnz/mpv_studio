import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';

void main() {
  for (final input in InputMode.values) {
    for (final back in [true, false]) {
      testWidgets('the subtitle starts under the title, ${input.name}, '
          '${back ? 'pushed' : 'top level'}', (tester) async {
        await pumpStudio(
          tester,
          Scaffold(
            body: PageFrame(
              title: 'Bass',
              subtitle: 'Stage 1 of 3. Low shelf',
              onBack: back ? () {} : null,
              body: const SizedBox(),
            ),
          ),
          size: const Size(360, 780),
          input: input,
        );
        expect(
          tester.getTopLeft(find.text('Stage 1 of 3. Low shelf')).dx,
          tester.getTopLeft(find.text('Bass')).dx,
        );
      });
    }
  }
}
