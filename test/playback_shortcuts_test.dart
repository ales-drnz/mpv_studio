import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import 'now_playing/playback_fake.dart';
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
      guard: <T>(call) async {
        guarded++;
        return call();
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

  group('with the Playback actions', () {
    late PlaybackFake fake;
    setUp(() => fake = playingTrack());

    Future<void> settleToast(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    testWidgets('Up and Down step the volume, held to repeat', (tester) async {
      await _pump(tester, fake);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(fake.calls, ['setVolume 85', 'setVolume 90', 'setVolume 85']);
    });

    testWidgets('Page Up and Page Down step the chapters', (tester) async {
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      expect(fake.calls, [
        'setChapter 2',
        'setChapter 1',
        'setChapter 0',
        'setChapter 0',
      ]);
    });

    testWidgets('L sets A, then B, then clears the loop', (tester) async {
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(find.text('Loop A at 2:03'), findsOneWidget);
      fake.emit((s) => s.copyWith(position: const Duration(minutes: 3)));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      // B at the playhead sends it back to A, as mpv's own ab-loop does.
      expect(fake.calls, [
        'setAbLoopA 123000',
        'setAbLoopB 180000',
        'seek 123000',
        'setAbLoopA null',
        'setAbLoopB null',
      ]);
      expect(find.text('A-B loop cleared'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('a B before A swaps the two', (tester) async {
      fake.emit((s) => s.copyWith(abLoopA: const Duration(minutes: 3)));
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(fake.state.abLoopA, const Duration(minutes: 2, seconds: 3));
      expect(fake.state.abLoopB, const Duration(minutes: 3));
      // The playhead (2:03) is the loop's start, so it stays put.
      expect(fake.calls.where((c) => c.startsWith('seek')), isEmpty);
      await settleToast(tester);
    });

    testWidgets('[ and ] change the speed, Backspace resets it', (
      tester,
    ) async {
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(find.text('Speed 1.2x'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      expect(fake.calls, [
        'setRate 1.1',
        'setRate 1.2',
        'setRate 1.0',
        'setRate 0.9',
      ]);
      await settleToast(tester);
    });

    testWidgets('N at the end of the queue says so', (tester) async {
      fake.nextResult = false;
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      expect(find.text('End of queue'), findsOneWidget);
      await settleToast(tester);
    });

    testWidgets('the help lists every bound key', (tester) async {
      await _pump(tester, fake);
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      for (final (keys, action) in playbackShortcutList) {
        expect(find.text(keys), findsOneWidget);
        expect(find.text(action), findsOneWidget);
      }
    });

    testWidgets('keys are left to an open menu', (tester) async {
      await _pump(tester, fake);
      final context = tester.element(find.text('page'));
      showMenu<void>(
        context: context,
        position: RelativeRect.fill,
        items: const [PopupMenuItem(child: Text('item'))],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(fake.calls, isEmpty);
    });
  });

  testWidgets('nothing happens when disabled (mobile layout)', (tester) async {
    await _pump(tester, player, enabled: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(player.calls, isEmpty);
  });
}
