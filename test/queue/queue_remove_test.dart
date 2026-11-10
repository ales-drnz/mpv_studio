import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';
import 'queue_fixture.dart';

void main() {
  setUpAll(loadStudioFonts);

  group('every removal can be undone', () {
    testWidgets('Delete', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'remove 0');
      expect(find.text('Removed "Kveld"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items, [localSong, webSong, serverSong]);
    });

    testWidgets('the row Remove button', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('two swipes in a row come back together', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      await tester.drag(find.text('Paper Lanterns'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Kveld'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(player.items, [webSong]);
      expect(find.text('Removed 2 tracks'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items, [localSong, webSong, serverSong]);
    });

    testWidgets('undoing the current entry makes it current again', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      // Departures, the current entry, is row 1.
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items, [localSong, webSong, serverSong]);
      expect(player.state.playback.playlist.index, 1);
    });
  });

  group('keyboard', () {
    testWidgets('holding Delete removes one entry', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(player.calls.where((c) => c.startsWith('remove')), ['remove 0']);
    });

    testWidgets('Backspace does not remove', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(player.calls, isNot(contains('remove 0')));
    });

    testWidgets('Enter on a focused row button runs that button', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Kveld'));
      await tester.pumpAndSettle();
      // The button's own focus, under its tooltip.
      final icon = find.descendant(
        of: find.byTooltip('Remove').first,
        matching: find.byType(Icon),
      );
      Focus.of(tester.element(icon)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(player.calls, contains('remove 0'));
      expect(player.calls, isNot(contains('jump 0')));
    });

    testWidgets('Alt+Up and Alt+Down move the selected entry one step', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(find.text('Paper Lanterns'));
      await tester.pumpAndSettle();
      Future<void> alt(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();
      }

      await alt(LogicalKeyboardKey.arrowUp);
      expect(player.items, [localSong, serverSong, webSong]);
      // The selection follows the entry, so it moves on.
      await alt(LogicalKeyboardKey.arrowUp);
      expect(player.items, [serverSong, localSong, webSong]);
      await alt(LogicalKeyboardKey.arrowDown);
      expect(player.items, [localSong, serverSong, webSong]);
    });
  });
}
