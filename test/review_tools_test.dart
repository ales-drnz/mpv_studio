// The review of wip/0.5.0-ux-tools: one test per finding fixed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_runner.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/saved_chains.dart';
import 'package:mpv_studio/features/console/console_page.dart';

import 'console/console_fixture.dart';
import 'effects/rack_harness.dart';
import 'queue/queue_fake.dart';
import 'support/fake_engine.dart';
import 'support/finders.dart';
import 'support/layout_harness.dart';

class _Refusing extends QueueFakePlayer {
  @override
  Future<void> sendRawCommand(List<String> args) async {
    throw MpvCommandException(
      name: args.first,
      code: -4,
      message: 'invalid parameter',
    );
  }
}

void main() {
  setUpAll(loadStudioFonts);

  test('a prefixed command is explained by the command', () async {
    final runner = ConsoleRunner(_Refusing());
    expect(
      (await runner.run('no-osd seek')).single.text,
      startsWith('seek did not take those arguments'),
    );
    expect(
      (await runner.run('show_text')).single.text,
      isNot(startsWith('Unknown command')),
    );
  });

  test('a chain text with an unreadable stage is refused', () {
    final good = chainToText([const BassEffect(gain: 4)]);
    final mixed = good.replaceFirst('"chain":[', '"chain":[5,');
    expect(chainFromText(mixed), isNull);
  });

  testWidgets('the Console follows a level changed in Settings', (
    tester,
  ) async {
    final player = consolePlayer();
    final log = consoleLog(player);
    Future<void> pumpAt(LogLevel level) => pumpStudio(
      tester,
      Scaffold(
        body: ConsoleView(player: player, log: log, level: level),
      ),
    );
    await pumpAt(LogLevel.info);
    await tester.pumpAndSettle();
    expect(find.textContaining('Detected file format'), findsNothing);
    await pumpAt(LogLevel.v);
    await tester.pumpAndSettle();
    expect(find.textContaining('Detected file format'), findsOneWidget);
  });

  testWidgets('Tab leaves an empty Console field', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    final field = tester.widget<TextField>(find.byType(TextField).last);
    field.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isFalse);
  });

  testWidgets('saving over a name can be undone', (tester) async {
    final library = MemoryChainLibrary()..save('Warm', [const BassEffect()]);
    await pumpRack(
      tester,
      FakeEngine([const AcompressorEffect(ratio: 4)]),
      chains: library,
    );
    await tester.tap(find.byKey(const ValueKey('rack-chains')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Warm');
    await tester.tap(buttonWithText<FilledButton>('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Replaced "Warm"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(library.chains['Warm'], [const BassEffect()]);
  });

  test('undoing a meter removal after the meter came back adds none', () {
    final engine = FakeEngine([const BassEffect(gain: 4), kMeterStage]);
    final rack = RackController(engine);
    addTearDown(rack.dispose);
    final meter = rack.chain.stages.last;
    rack.remove(meter.id);
    rack.setMeter(true);
    rack.putBack(meter.effect, 1);
    expect(rack.chain.effects.where(isMeterStage), hasLength(1));
  });

  testWidgets('Ctrl+Delete on a stage header removes nothing', (tester) async {
    final engine = FakeEngine([const BassEffect(gain: 4)]);
    final rack = await pumpRack(tester, engine);
    final header = find.byKey(
      ValueKey('stage-header-${rack.chain.stages.single.id}'),
    );
    Focus.of(
      tester.element(
        find.descendant(of: header, matching: find.byType(Row)).first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(engine.current, hasLength(1));
  });
}
