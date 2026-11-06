import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_runner.dart';

import '../queue/queue_fake.dart';
import '../support/layout_harness.dart';
import 'console_fixture.dart';

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).last).controller!.text;

Future<void> typeLine(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pumpAndSettle();
}

Future<void> runLine(WidgetTester tester, String text) async {
  await typeLine(tester, text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

/// A player whose mpv refuses every raw command, like an unknown name.
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

  group('history', () {
    testWidgets('Up after a click on the field recalls the last line', (
      tester,
    ) async {
      final player = consolePlayer();
      await pumpConsole(tester, player, consoleLog(player));
      await runLine(tester, 'seek 10');
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(fieldText(tester), 'seek 10');
      // Recalled, Up goes on through the history, not into a popup.
      await runLine(tester, 'seek 20');
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(fieldText(tester), 'seek 10');
    });

    testWidgets('Down brings back the line being typed', (tester) async {
      final player = consolePlayer();
      await pumpConsole(tester, player, consoleLog(player));
      await runLine(tester, 'seek 10');
      await typeLine(tester, 'get vol');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(fieldText(tester), 'get vol');
    });

    testWidgets('a phone recalls the history from a button', (tester) async {
      final player = consolePlayer();
      await pumpConsole(
        tester,
        player,
        consoleLog(player),
        size: const Size(390, 844),
      );
      await runLine(tester, 'seek 10');
      await tester.tap(find.byTooltip('Command history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('seek 10').last);
      await tester.pumpAndSettle();
      expect(fieldText(tester), 'seek 10');
    });
  });

  testWidgets('the level follows the setting and records a change', (
    tester,
  ) async {
    final player = consolePlayer();
    final picked = <LogLevel>[];
    await pumpConsole(
      tester,
      player,
      consoleLog(player),
      level: LogLevel.v,
      onLevel: picked.add,
    );
    expect(find.textContaining('Detected file format'), findsOneWidget);
    await tester.tap(find.text('Verbose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warnings').last);
    await tester.pumpAndSettle();
    expect(picked, [LogLevel.warn]);
  });

  test('an unknown command says how to find one', () async {
    final results = await ConsoleRunner(_Refusing()).run('frobnicate 3');
    expect(
      results.single.text,
      "Unknown command 'frobnicate'. Type help, or press Tab for the list.",
    );
  });

  test('a known command with wrong arguments shows its form', () async {
    final results = await ConsoleRunner(_Refusing()).run('seek');
    expect(results.single.text, startsWith('seek did not take those '));
    expect(results.single.text, contains('seek <target>'));
  });

  test('get without a property says what it needs', () async {
    final results = await ConsoleRunner(consolePlayer()).run('get');
    expect(results.single.text, 'get needs a property, like get volume');
  });

  testWidgets('copying an empty view says so', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await tester.enterText(find.byType(TextField).first, 'no such line');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy the log'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to copy'), findsOneWidget);
  });

  testWidgets('clearing the log can be undone', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await tester.tap(find.byTooltip('Clear the log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio device: pipewire'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio device: pipewire'), findsOneWidget);
  });

  testWidgets('Tab leaves a line with nothing to complete', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await typeLine(tester, 'seek 10 ');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isFalse);
  });
}
