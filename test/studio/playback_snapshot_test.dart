import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/playback_snapshot.dart';

import '../settings/studio_fakes.dart';

const _a = Media('/music/a.flac');
const _b = Media('/music/b.flac');

const _atB = PlaybackSnapshot(
  queue: [_a, _b],
  index: 1,
  position: Duration(seconds: 42),
  playing: true,
);

/// The player after the queue loaded at [index], [seekable] or not.
void _loaded(StudioFakePlayer p, {int index = 1, bool seekable = true}) =>
    p.emit(
      (s) => s.copyWith(
        playlist: Playlist(const [_a, _b], index: index),
        seekable: seekable,
      ),
    );

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
    final done = _atB.restore(player);
    await pumpEventQueue();
    _loaded(player);
    player.opened.add(null);
    await done;
    expect(player.calls, hasLength(3));
    expect(player.calls[0], startsWith('openAll'));
    expect(player.calls[0], endsWith('play=false index=1'));
    expect(player.calls.sublist(1), ['seek 42000', 'play']);
  });

  test('a live stream that cannot seek plays at once, unseeked', () async {
    final player = StudioFakePlayer();
    final done = _atB.restore(player);
    await pumpEventQueue();
    _loaded(player, seekable: false);
    player.opened.add(null);
    await done;
    expect(player.calls.sublist(1), ['play']);
  });

  test('seeks when the core is seekable ahead of the state', () async {
    // mpv reports the playback restart before the property changes of the
    // same load: the state can still say not seekable.
    final player = StudioFakePlayer()..rawProperties['seekable'] = 'yes';
    final done = _atB.restore(player);
    await pumpEventQueue();
    _loaded(player, seekable: false);
    player.opened.add(null);
    await done;
    expect(player.calls.sublist(1), ['seek 42000', 'play']);
  });

  test('a paused session comes back paused at its position', () async {
    final player = StudioFakePlayer();
    final done = const PlaybackSnapshot(
      queue: [_a, _b],
      index: 1,
      position: Duration(seconds: 26),
      playing: false,
    ).restore(player);
    await pumpEventQueue();
    _loaded(player);
    player.opened.add(null);
    await done;
    expect(player.calls.sublist(1), ['seek 26000']);
  });

  test('an entry that failed and moved on keeps its position', () async {
    final player = StudioFakePlayer();
    final done = _atB.restore(player);
    await pumpEventQueue();
    player.ended.add(
      const MpvFileEndedEvent(reason: MpvEndFileReason.error, error: -13),
    );
    _loaded(player, index: 0);
    await done;
    expect(player.calls.sublist(1), ['play']);
  });

  test('an entry that never opens plays after the timeout', () {
    fakeAsync((async) {
      final player = StudioFakePlayer();
      var finished = false;
      _atB.restore(player).then((_) => finished = true);
      async.elapse(PlaybackSnapshot.openTimeout - const Duration(seconds: 1));
      expect(finished, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(finished, isTrue);
      expect(player.calls.sublist(1), ['play']);
    });
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

  test('restoreReporting hands any failure to report', () async {
    final player = StudioFakePlayer()..refuse.add('openAll');
    final reported = <Object>[];
    await _atB.restoreReporting(player, reported.add);
    expect(reported.single, isA<MpvCommandException>());
  });
}
