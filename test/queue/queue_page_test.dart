import 'dart:async';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';
import 'queue_fixture.dart';

void main() {
  setUpAll(loadStudioFonts);

  group('empty queue', () {
    testWidgets('offers the ways to fill it', (tester) async {
      final (player, details) = emptyQueue();
      await pumpQueue(tester, player, details, picked: ['/m/a.flac']);
      expect(find.text('The queue is empty'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add files'), findsWidgets);
      expect(find.text('Load playlist'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Add files').last);
      await tester.pumpAndSettle();
      expect(player.calls, contains('openAll 1 play=true'));
      expect(find.text('a'), findsWidgets);
      expect(find.text('1 track'), findsOneWidget);
    });

    testWidgets('clear is disabled', (tester) async {
      final (player, details) = emptyQueue();
      await pumpQueue(tester, player, details);
      final clear = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Clear queue'),
      );
      expect(clear.onPressed, isNull);
    });
  });

  group('rows', () {
    testWidgets('label every row the same way', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      expect(find.text('Peace Piece'), findsOneWidget);
      expect(find.text('Local file'), findsOneWidget);
      // The current row: tags, artist and source.
      expect(find.text('So What'), findsOneWidget);
      expect(find.text('Miles Davis · Web stream'), findsOneWidget);
      // The failed row: badge and reason.
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Could not open the file or stream'), findsOneWidget);
      expect(find.text('3 tracks, at least 14:59'), findsOneWidget);
    });

    testWidgets('a pointer gets a context menu, touch an action sheet', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Peace Piece'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Play next'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'move 0 2');
      expect(player.items.first, webSong);
      expect(player.items[1], localSong);

      final (touchPlayer, touchDetails) = await threeEntries(
        () => tester.pump(),
      );
      await pumpQueue(
        tester,
        touchPlayer,
        touchDetails,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      await tester.longPress(find.text('Peace Piece'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Move to bottom'));
      await tester.pumpAndSettle();
      expect(touchPlayer.calls.last, 'move 0 3');
      expect(touchPlayer.items.last, localSong);
    });

    testWidgets('keyboard selects, plays and removes', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Peace Piece'));
      await tester.pumpAndSettle();
      // One click selects (and shows the details beside the list).
      expect(player.calls, isNot(contains('jump 0')));
      expect(find.text('1 of 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'jump 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'remove 2');
      expect(player.items, [localSong, webSong]);
    });

    testWidgets('a double click plays', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Peace Piece'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Peace Piece').first);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'jump 0');
    });

    testWidgets('a tap plays on touch and a swipe removes with undo', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      await tester.tap(find.text('Peace Piece'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'jump 0');

      await tester.drag(find.text('Blue in Green'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'remove 2');
      expect(find.text('Removed "Blue in Green"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items.last, serverSong);
    });

    testWidgets('clearing asks first', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.widgetWithText(TextButton, 'Clear queue'));
      await tester.pumpAndSettle();
      expect(find.text('Clear the queue?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(player.calls, isNot(contains('clearPlaylist')));
      await tester.tap(find.widgetWithText(TextButton, 'Clear queue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'clearPlaylist');
      expect(find.text('The queue is empty'), findsOneWidget);
    });

    testWidgets('the details show a location without the token', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      await tester.longPress(find.text('Blue in Green'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show info'));
      await tester.pumpAndSettle();
      expect(find.text('https://jf.example.test/Audio/42/stream'), findsOne);
      expect(find.textContaining('secret'), findsNothing);
      expect(find.text('Failed: Could not open the file or stream'), findsOne);
    });
  });

  testWidgets('the playlist banner says when there is no other playlist', (
    tester,
  ) async {
    final (player, details) = await threeEntries(() => tester.pump());
    player.emit((s) => s.copyWith(playlistPath: '/lists/Jazz%20Night.m3u'));
    await pumpQueue(tester, player, details);
    expect(find.text('From Jazz Night.m3u'), findsOneWidget);
    await tester.tap(find.byTooltip('Next playlist'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'nextPlaylist');
    expect(find.text('This is the last playlist'), findsOneWidget);

    player.hasOtherPlaylist = true;
    await tester.tap(find.byTooltip('Previous playlist'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'previousPlaylist');
  });

  group('selection follows the entry', () {
    testWidgets('through a move made elsewhere', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Peace Piece').first);
      await tester.pump(const Duration(milliseconds: 400));
      // The Console (or a shuffle) moves it to the end.
      await player.move(0, 3);
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'jump 2');
    });

    testWidgets('through a removal above it', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Blue in Green').first);
      await tester.pump(const Duration(milliseconds: 400));
      await player.remove(0);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'remove 1');
      expect(player.items, [webSong]);
    });

    testWidgets('to the next entry when it is removed', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Peace Piece').first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // So What is now first and selected.
      expect(player.calls.last, 'jump 0');
    });
  });

  testWidgets('the info sheet follows its entry', (tester) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(
      tester,
      player,
      details,
      size: const Size(412, 915),
      input: InputMode.touch,
    );
    await tester.longPress(find.text('Blue in Green'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show info'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    await player.move(2, 0);
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'jump 0');
  });

  testWidgets('rows expose their tap and menu to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(
      tester,
      player,
      details,
      size: const Size(412, 915),
      input: InputMode.touch,
    );
    final row = find.bySemanticsLabel(RegExp('^Track 1, Peace Piece'));
    expect(
      tester.getSemantics(row),
      isSemantics(isButton: true, hasTapAction: true, hasLongPressAction: true),
    );
    final node = find.semantics.byLabel(RegExp('^Track 1, Peace Piece'));
    tester.semantics.tap(node);
    await tester.pumpAndSettle();
    expect(player.calls.last, 'jump 0');
    tester.semantics.longPress(node);
    await tester.pumpAndSettle();
    expect(find.text('Move to bottom'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the summary shows files being added to an empty queue', (
    tester,
  ) async {
    final (player, details) = emptyQueue();
    player.openGate = Completer();
    await pumpQueue(
      tester,
      player,
      details,
      picked: ['/m/a.flac', '/m/b.flac'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add files').last);
    await tester.pump();
    expect(find.text('Adding 2 files'), findsOneWidget);
    player.openGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Adding 2 files'), findsNothing);
    expect(find.text('2 tracks'), findsOneWidget);
  });
}
