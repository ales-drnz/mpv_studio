import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../support/fake_engine.dart';
import 'rack_harness.dart';

void main() {
  testWidgets('Enter in the catalog search adds the first match', (
    tester,
  ) async {
    final engine = FakeEngine();
    await pumpRack(tester, engine);
    await tester.tap(find.byKey(const ValueKey('rack-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-stage-search')),
      'chorus',
    );
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(engine.current.single, isA<ChorusEffect>());
  });

  testWidgets('a stage that waits for an option says which', (tester) async {
    final engine = FakeEngine([const AevalEffect(exprs: '', enabled: false)]);
    final rack = await pumpRack(tester, engine);
    await tester.tap(
      find.byKey(ValueKey('stage-header-${rack.chain.stages.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Off until exprs is filled in.'), findsOneWidget);
  });
}
