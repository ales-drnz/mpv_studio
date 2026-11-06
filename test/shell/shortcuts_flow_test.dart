import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';

import '../now_playing/playback_fake.dart';
import '../support/fake_engine.dart';
import '../support/fake_player.dart';

Future<void> _pump(
  WidgetTester tester,
  FakePlayer player, {
  RackController? rack,
  Widget? child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlaybackShortcuts(
          player: player,
          rack: rack,
          child: child ?? const Text('page'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Page Down scrolls a focused list instead of the chapters', (
    tester,
  ) async {
    final fake = playingTrack();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      fake,
      child: ListView(
        controller: controller,
        primary: false,
        children: [
          for (var i = 0; i < 80; i++)
            SizedBox(
              height: 48,
              child: Focus(autofocus: i == 0, child: Text('row $i')),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('row 0'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(fake.calls, isEmpty);
    // Shift moves through the chapters wherever the focus is.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(fake.calls, ['setChapter 2']);
  });

  testWidgets('B bypasses the effects and says so', (tester) async {
    final rack = RackController(FakeEngine([const BassEffect(gain: 4)]));
    addTearDown(rack.dispose);
    await _pump(tester, playingTrack(), rack: rack);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(rack.bypass, isTrue);
    expect(find.text('Effects bypassed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('M and Space are announced', (tester) async {
    final said = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final data = (message as Map)['data'] as Map;
        if (data['message'] case final String text) said.add(text);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await _pump(tester, playingTrack());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(said, ['Muted', 'Playing']);
  });

  testWidgets('the help lists the keys of the pages too', (tester) async {
    await _pump(tester, playingTrack());
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    for (final keys in [
      'Ctrl+1 to 7',
      'Escape',
      'B',
      'Ctrl+F',
      'Alt+Up, Alt+Down',
    ]) {
      expect(find.text(keys), findsWidgets, reason: keys);
    }
  });
}
