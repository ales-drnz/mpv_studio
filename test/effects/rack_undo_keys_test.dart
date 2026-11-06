import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'package:mpv_studio/features/effects/widgets/rack_parts.dart';

import '../support/fake_engine.dart';
import 'rack_harness.dart';

void main() {
  const bass = BassEffect(gain: 4);
  const comp = AcompressorEffect(ratio: 4);

  Future<void> focusHeader(WidgetTester tester, int id) async {
    final header = find.byKey(ValueKey('stage-header-$id'));
    Focus.of(
      tester.element(
        find.descendant(of: header, matching: find.byType(Row)).first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
  }

  Future<void> alt(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('removing a stage can be undone, open as it was', (tester) async {
    final engine = FakeEngine([bass, comp]);
    final rack = await pumpRack(tester, engine);
    final id = rack.chain.stages.first.id;
    await tester.tap(find.byKey(ValueKey('stage-header-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('stage-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(engine.current, [comp]);
    expect(find.text('Removed "Bass"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(engine.current, [bass, comp]);
    expect(rack.isExpanded(rack.chain.stages.first.id), isTrue);
  });

  testWidgets('resetting a stage can be undone', (tester) async {
    final engine = FakeEngine([bass]);
    final rack = await pumpRack(tester, engine);
    final id = rack.chain.stages.single.id;
    await tester.tap(find.byKey(ValueKey('stage-header-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(engine.current.single, isNot(bass));
    expect(find.text('Bass reset'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(engine.current, [bass]);
  });

  testWidgets('an error goes once a later chain is accepted', (tester) async {
    final engine = FakeEngine([bass])
      ..refuse = (fx) => fx.any((e) => e is AcompressorEffect);
    final rack = await pumpRack(tester, engine);
    rack.add(comp);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rack-error')), findsOneWidget);
    rack.setEnabled(rack.chain.stages.first.id, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rack-error')), findsNothing);
  });

  group('keyboard on a stage', () {
    testWidgets('Alt+Down and Alt+Up move it', (tester) async {
      final engine = FakeEngine([bass, comp]);
      final rack = await pumpRack(tester, engine);
      final id = rack.chain.stages.first.id;
      await focusHeader(tester, id);
      await alt(tester, LogicalKeyboardKey.arrowDown);
      expect(engine.current, [comp, bass]);
      await alt(tester, LogicalKeyboardKey.arrowUp);
      expect(engine.current, [bass, comp]);
    });

    testWidgets('Delete removes it, with an undo', (tester) async {
      final engine = FakeEngine([bass, comp]);
      final rack = await pumpRack(tester, engine);
      await focusHeader(tester, rack.chain.stages.last.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(engine.current, [bass]);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  testWidgets('the bypass is off for an empty chain', (tester) async {
    await pumpRack(tester, FakeEngine());
    final bypass = tester.widget<RackHeaderButton>(
      find.byKey(const ValueKey('rack-bypass')),
    );
    expect(bypass.onTap, isNull);
  });
}
