import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/playback_scope.dart';
import 'package:mpv_studio/features/now_playing/widgets/transport_controls.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/theme.dart';

import 'queue_fake.dart';
import 'queue_fixture.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) =>
          LayoutScope(inputMode: InputMode.pointer, child: child!),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
  await tester.pump();
}

void _expectStoppedOnSameEntry(QueueFakePlayer player) {
  expect(player.calls, contains('stop'));
  expect(player.items, [localSong, webSong, serverSong]);
  expect(player.state.playlist.index, 1);
  expect(player.state.playWhenReady, isFalse);
}

void main() {
  // mpv's stop empties the playlist; the studio's Stop only stops.
  testWidgets('Stop in the mini-player menu keeps the queue', (tester) async {
    final (player, _) = await threeEntries(() => tester.pump());
    await _pump(tester, MiniPlayer(player: player));
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('mini-info'))),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    _expectStoppedOnSameEntry(player);
  });

  testWidgets('the Stop button of Playback keeps the queue', (tester) async {
    final (player, _) = await threeEntries(() => tester.pump());
    await _pump(
      tester,
      PlaybackScope(player: player, child: const TransportControls()),
    );
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    _expectStoppedOnSameEntry(player);
  });

  testWidgets('Stop on an empty queue only stops', (tester) async {
    final (player, _) = emptyQueue();
    await _pump(
      tester,
      PlaybackScope(player: player, child: const TransportControls()),
    );
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(player.calls, ['stop']);
  });

  testWidgets('Stop drops a live PCM entry, which ends with it', (
    tester,
  ) async {
    final player = QueueFakePlayer(
      const PlayerState(
        playlist: Playlist([Media('mak-pcm://3'), localSong], index: 0),
      ),
    );
    await _pump(tester, MiniPlayer(player: player));
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('mini-info'))),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(player.items, [localSong]);
  });
}
