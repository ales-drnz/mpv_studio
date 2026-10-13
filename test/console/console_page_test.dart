import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';
import 'console_fixture.dart';

void main() {
  setUpAll(loadStudioFonts);

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the backlog filtered by level and search', (tester) async {
    final player = consolePlayer();
    final log = consoleLog(player);
    await pumpConsole(tester, player, log);
    expect(find.textContaining('Audio device: pipewire'), findsOneWidget);
    // Verbose lines are below the info floor.
    expect(find.textContaining('Detected file format'), findsNothing);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verbose').last);
    await tester.pumpAndSettle();
    expect(player.logLevel, LogLevel.v);
    expect(find.textContaining('Detected file format'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'FFMPEG');
    await tester.pumpAndSettle();
    expect(find.textContaining('Header missing'), findsOneWidget);
    expect(find.textContaining('Audio device'), findsNothing);
  });

  testWidgets('runs a routed command and logs the route', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await type(tester, 'loadfile "https://x.test/a b.mp3" append-play');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('› loadfile "https://x.test/a b.mp3" append-play'),
      findsOneWidget,
    );
    expect(find.text('via Player.add(), Player.jump(0)'), findsOneWidget);
    expect(player.items.single.uri, 'https://x.test/a b.mp3');
    expect(player.state.playWhenReady, isTrue);
  });

  testWidgets('keyboard: history, Tab completion, Escape and Ctrl+L', (
    tester,
  ) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await type(tester, 'seek 10');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await type(tester, 'seek 20');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(player.rawCommands, [
      ['seek', '10'],
      ['seek', '20'],
    ]);

    final field = find.byType(TextField).last;
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'seek 20');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'seek 10');

    // Tab completes a unique match at once.
    await type(tester, 'getno');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'getnode ');
    // The popup lists the properties for it.
    expect(find.text('playlist-pos'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('playlist-pos'), findsNothing);

    expect(find.textContaining('Audio device'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio device'), findsNothing);
  });

  testWidgets('touch: the level filter opens a sheet, suggestions are tall', (
    tester,
  ) async {
    final player = consolePlayer();
    await pumpConsole(
      tester,
      player,
      consoleLog(player),
      size: const Size(360, 780),
      input: InputMode.touch,
    );
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Errors'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio device'), findsNothing);
    expect(find.textContaining('Failed to open'), findsOneWidget);

    await type(tester, 'get vol');
    expect(find.text('volume'), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('volume'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('volume'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    expect(tester.widget<TextField>(field).controller!.text, 'get volume ');
  });

  testWidgets('help explains the Console', (tester) async {
    final player = consolePlayer();
    await pumpConsole(tester, player, consoleLog(player));
    await tester.tap(find.byTooltip('Console help'));
    await tester.pumpAndSettle();
    expect(find.text('Console help'), findsOneWidget);
    expect(find.textContaining('expand-properties'), findsOneWidget);
    expect(find.textContaining('Player API'), findsOneWidget);
  });
}
