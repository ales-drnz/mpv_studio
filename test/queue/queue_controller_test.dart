import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_controller.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import 'queue_fake.dart';

const _a = Media('/a.flac');
const _b = Media('/b.flac');
const _c = Media('/c.flac');
const _d = Media('/d.flac');

void main() {
  late QueueFakePlayer player;
  late QueueController queue;
  late int guarded;

  setUp(() {
    player = QueueFakePlayer(
      const PlayerState(playlist: Playlist([_a, _b, _c, _d], index: 1)),
    );
    guarded = 0;
    queue = QueueController(
      player: player,
      guard: <T>(FutureOr<T> Function() call) {
        guarded++;
        return unguarded<T>(call);
      },
      pickFiles: () async => ['/x/One.flac', '/x/Two.mp3'],
    );
  });
  tearDown(() => queue.dispose());

  test('moves land at the final index asked for', () async {
    await queue.move(0, 2);
    expect(player.items, [_b, _c, _a, _d]);
    await queue.move(3, 0);
    expect(player.items, [_d, _b, _c, _a]);
    await queue.move(1, 1);
    expect(player.calls.where((c) => c.startsWith('move')), hasLength(2));
  });

  test('top and bottom', () async {
    await queue.moveToBottom(0);
    expect(player.items, [_b, _c, _d, _a]);
    await queue.moveToTop(2);
    expect(player.items, [_d, _b, _c, _a]);
  });

  test('play next puts the entry right after the current one', () async {
    await queue.playNext(3);
    expect(player.items, [_a, _b, _d, _c]);
    await queue.playNext(0);
    expect(player.items, [_b, _a, _d, _c]);
    expect(player.state.playlist.index, 0);
    // Already next: nothing to do.
    final before = player.calls.length;
    await queue.playNext(1);
    expect(player.calls, hasLength(before));
  });

  test('a removed entry comes back where it was', () async {
    final removed = await queue.remove(2);
    expect(removed, _c);
    expect(player.items, [_a, _b, _d]);
    await queue.restore(removed!, 2);
    expect(player.items, [_a, _b, _c, _d]);
  });

  test('picked files are appended through the guard', () async {
    await queue.addFiles();
    expect(player.items.skip(4).map((m) => m.uri), [
      '/x/One.flac',
      '/x/Two.mp3',
    ]);
    expect(player.items[4].extras?['title'], 'One');
    expect(guarded, 2);
    expect(queue.adding.value, 0);
  });

  test('a failing call stops the add and resets the progress', () async {
    final failing = QueueController(
      player: player,
      guard: <T>(FutureOr<T> Function() call) async => null,
      pickFiles: () async => ['/x/One.flac', '/x/Two.mp3'],
    );
    addTearDown(failing.dispose);
    await failing.addFiles();
    expect(failing.adding.value, 0);
    expect(await failing.remove(0), isNull);
  });

  test('playlist navigation hands back the answer', () async {
    expect(await queue.nextPlaylist(), isFalse);
    player.hasOtherPlaylist = true;
    expect(await queue.previousPlaylist(), isTrue);
  });
}
