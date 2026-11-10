import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/now_playing_page.dart';
import 'package:mpv_studio/features/stream/stream_actions.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../now_playing/playback_fake.dart';
import '../support/finders.dart';
import '../support/layout_harness.dart';
import 'queue_fake.dart';
import 'queue_fixture.dart';

/// Records the toasts of a [StreamActions].
class _Toasts {
  final messages = <String>[];
  VoidCallback? undo;
  void call(String message, {String? actionLabel, VoidCallback? onAction}) {
    messages.add(message);
    if (actionLabel == 'Undo') undo = onAction;
  }
}

/// The Playback fake with a queue that grows on [add].
class _QueueingPlayback extends PlaybackFake {
  _QueueingPlayback(super.initial);

  void _set(List<Media> items, int index) =>
      emit((s) => s.copyWith(playlist: Playlist(items, index: index)));

  @override
  Future<void> add(Media media) async {
    calls.add('add');
    final pl = state.playback.playlist;
    _set([...pl.items, media], pl.index);
  }

  @override
  Future<void> openAll(List<Media> medias, {bool? play, int index = 0}) async {
    calls.add('openAll');
    _set(medias, index);
  }
}

void main() {
  setUpAll(loadStudioFonts);

  group('the Queue page', () {
    testWidgets('loading a playlist over a queue can be undone', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, picked: const ['/a.m3u']);
      await tester.tap(buttonWithText<TextButton>('Load playlist'));
      await tester.pumpAndSettle();
      expect(player.calls.last, startsWith('openPlaylistFile'));
      expect(find.text('Queue replaced'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items, [localSong, webSong, serverSong]);
      expect(player.state.playback.playlist.index, 1);
    });

    testWidgets('clearing is at once and can be undone', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details);
      await tester.tap(buttonWithText<TextButton>('Clear queue'));
      await tester.pumpAndSettle();
      expect(find.text('Clear the queue?'), findsNothing);
      expect(player.calls, contains('clearPlaylist'));
      expect(find.text('Queue cleared'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(player.items, [localSong, webSong, serverSong]);
      expect(player.state.playback.playlist.index, 1);
    });
  });

  testWidgets('an Undo after the queue changed again keeps the new queue', (
    tester,
  ) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(tester, player, details, picked: const ['/m/new.flac']);
    await tester.tap(buttonWithText<TextButton>('Clear queue'));
    await tester.pumpAndSettle();
    await tester.tap(buttonWithText<FilledButton>('Add files').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(player.items.single.uri, '/m/new.flac');
    expect(find.text('The queue changed since, so it stays'), findsOneWidget);
  });

  testWidgets('Open files on Playback adds to the queue', (tester) async {
    final player = _QueueingPlayback(
      const PlayerState(
        playback: PlaybackState(
          playlist: Playlist([localSong, webSong], index: -1),
        ),
      ),
    );
    await pumpStudio(
      tester,
      Scaffold(
        body: NowPlayingPage(
          player: player,
          pickFiles: () async => ['/music/new.flac'],
          onOpenStream: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open files'));
    await tester.pumpAndSettle();
    final items = player.state.playback.playlist.items;
    expect(items, hasLength(3));
    expect(items.take(2), [localSong, webSong]);
  });

  group('Stream actions', () {
    test('playing over a queue offers to put it back', () async {
      final player = QueueFakePlayer(
        const PlayerState(
          playback: PlaybackState(
            playlist: Playlist([localSong, webSong], index: 1),
            playWhenReady: true,
          ),
        ),
      );
      final toasts = _Toasts();
      final actions = StreamActions(
        player: player,
        guard: unguarded,
        toast: toasts.call,
      );
      await actions.playAll(const [Media('https://radio.test/a')]);
      expect(player.items, hasLength(1));
      expect(toasts.messages, ['Queue replaced']);
      toasts.undo!();
      await Future<void>.delayed(Duration.zero);
      expect(player.items, [localSong, webSong]);
      expect(player.state.playback.playlist.index, 1);
    });

    test('playing on an empty queue has nothing to undo', () async {
      final player = QueueFakePlayer();
      final toasts = _Toasts();
      final actions = StreamActions(
        player: player,
        guard: unguarded,
        toast: toasts.call,
      );
      await actions.play(const Media('https://radio.test/a'));
      expect(toasts.messages, isEmpty);
    });

    test('adding says what it did', () async {
      final player = QueueFakePlayer(
        const PlayerState(
          playback: PlaybackState(playlist: Playlist([localSong], index: 0)),
        ),
      );
      final toasts = _Toasts();
      final actions = StreamActions(
        player: player,
        guard: unguarded,
        toast: toasts.call,
      );
      await actions.enqueue(const [Media('https://radio.test/a')]);
      await actions.playNext(const [
        Media('https://radio.test/b'),
        Media('https://radio.test/c'),
      ]);
      expect(toasts.messages, ['Added to the queue', '2 tracks play next']);
    });
  });
}
