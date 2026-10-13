import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import 'support/fake_player.dart';

Future<void> _pump(
  WidgetTester tester,
  FakePlayer player, {
  bool enabled = true,
  CallGuard guard = unguarded,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlaybackShortcuts(
          player: player,
          enabled: enabled,
          guard: guard,
          child: const Column(
            children: [
              TextField(key: ValueKey('field')),
              Text('page'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late FakePlayer player;
  setUp(() => player = FakePlayer());

  testWidgets('space, arrows, M, N and P drive playback', (tester) async {
    await _pump(tester, player);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);

    expect(player.calls, [
      'play',
      'pause',
      'seek +5000',
      'seek -5000',
      'setMute true',
      'next',
      'previous',
    ]);
  });

  testWidgets('the calls run through the guard', (tester) async {
    var guarded = 0;
    await _pump(
      tester,
      player,
      guard: (call) async {
        guarded++;
        await call();
      },
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    expect(guarded, 3);
    expect(player.calls, ['play', 'seek +5000', 'next']);
  });

  testWidgets('holding an arrow keeps seeking', (tester) async {
    await _pump(tester, player);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(player.calls, ['seek +5000', 'seek +5000']);
  });

  testWidgets('keys typed in a text field are left alone', (tester) async {
    await _pump(tester, player);
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(player.calls, isEmpty);
  });

  testWidgets('modifier combinations are left alone', (tester) async {
    await _pump(tester, player);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(player.calls, isEmpty);
  });

  testWidgets('nothing happens when disabled (mobile layout)', (tester) async {
    await _pump(tester, player, enabled: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(player.calls, isEmpty);
  });
}
