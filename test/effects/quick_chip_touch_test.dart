import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/fake_engine.dart';
import 'rack_harness.dart';

void main() {
  testWidgets('on touch the quick chips carry no tooltip over the header', (
    tester,
  ) async {
    await pumpRack(
      tester,
      FakeEngine(),
      size: const Size(412, 915),
      input: InputMode.touch,
    );
    final chip = find.byKey(const ValueKey('quick-superequalizer'));
    expect(chip, findsOneWidget);
    expect(
      find.ancestor(of: chip, matching: find.byType(Tooltip)),
      findsNothing,
    );
  });
}
