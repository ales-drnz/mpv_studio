import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/playback_snapshot.dart';

import '../settings/studio_fakes.dart';

const _a = Media('/music/a.flac');
const _b = Media('/music/b.flac');

void main() {
  test('takes the queue, entry, position and intent', () {
    final s = PlaybackSnapshot.of(
      const PlayerState(
        playlist: Playlist([_a, _b], index: 1),
        position: Duration(seconds: 42),
        playWhenReady: true,
      ),
    );
    expect(s.queue, [_a, _b]);
    expect(s.index, 1);
    expect(s.position, const Duration(seconds: 42));
    expect(s.playing, isTrue);
  });

  test('restores paused at the entry, seeks once it opened, plays', () async {
    final player = StudioFakePlayer();
    const snapshot = PlaybackSnapshot(
      queue: [_a, _b],
      index: 1,
      position: Duration(seconds: 42),
      playing: true,
    );
    final done = snapshot.restore(player);
    await pumpEventQueue();
    // The entry opens: it reports a length.
    player.emit((s) => s.copyWith(duration: const Duration(minutes: 3)));
    await done;
    expect(player.calls, hasLength(3));
    expect(player.calls[0], startsWith('openAll'));
    expect(player.calls[0], endsWith('play=false index=1'));
    expect(player.calls.sublist(1), ['seek 42000', 'play']);
  });

  test('a paused session at the start restores without seeking', () async {
    final player = StudioFakePlayer();
    await const PlaybackSnapshot(
      queue: [_a],
      index: 0,
      position: Duration.zero,
      playing: false,
    ).restore(player);
    expect(player.calls, hasLength(1));
    expect(player.calls.single, startsWith('openAll'));
  });

  test('an empty queue restores nothing', () async {
    final player = StudioFakePlayer();
    await const PlaybackSnapshot(
      queue: [],
      index: -1,
      position: Duration.zero,
      playing: true,
    ).restore(player);
    expect(player.calls, isEmpty);
  });
}
