import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Where playback stood (the queue, the current entry, the position and
/// whether it was playing), taken from one player and restored on another:
/// the in-app player restart carries the session across with it.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.index,
    required this.position,
    required this.playing,
  });

  /// The snapshot of [state].
  factory PlaybackSnapshot.of(PlayerState state) => PlaybackSnapshot(
    queue: List.unmodifiable(state.playlist.items),
    index: state.playlist.index,
    position: state.position,
    playing: state.playWhenReady,
  );

  final List<Media> queue;

  /// The current entry, -1 for none.
  final int index;
  final Duration position;

  /// The play intent (`playWhenReady`), not the momentary output.
  final bool playing;

  /// How long [restore] waits for the current entry to open before it
  /// plays on without the position.
  static const openTimeout = Duration(seconds: 10);

  /// Positions this close to the start are not worth a seek.
  static const _minSeek = Duration(seconds: 1);

  /// Loads the queue on [player] paused at the current entry, puts it back
  /// at the position once the entry has opened, then resumes when it was
  /// playing. The position is skipped when the entry cannot seek (a live
  /// stream), when it failed and the player moved on, or when it did not
  /// open within [openTimeout]. An empty queue restores nothing.
  Future<void> restore(PlayerApi player) async {
    if (queue.isEmpty) return;
    final at = index.clamp(0, queue.length - 1);
    final opened = index >= 0 && position >= _minSeek
        ? _whenOpened(player)
        : null;
    try {
      await player.openAll(queue, index: at, play: false);
    } on Object {
      opened?.ignore();
      rethrow;
    }
    if (opened != null &&
        await opened &&
        player.state.playlist.index == at &&
        await _seekable(player)) {
      await player.seek(position);
    }
    if (playing) await player.play();
  }

  /// Whether the open entry can seek. The core is asked when the state
  /// says no: mpv reports the playback restart ahead of the property
  /// changes of the same load, so `seekable` can still be the idle core's
  /// false at that moment.
  static Future<bool> _seekable(PlayerApi player) async {
    if (player.state.seekable) return true;
    try {
      return await player.getRawProperty('seekable') == 'yes';
    } on Object {
      return false;
    }
  }

  /// Completes with true once the next entry has opened (mpv restarted
  /// playback, live streams included), false when it ended first (it
  /// failed) or nothing happened within [openTimeout].
  static Future<bool> _whenOpened(PlayerApi player) {
    final done = Completer<bool>();
    final subs = <StreamSubscription<Object?>>[];
    void finish(bool opened) {
      if (done.isCompleted) return;
      done.complete(opened);
      for (final s in subs) {
        s.cancel();
      }
    }

    subs
      ..add(player.stream.seekCompleted.listen((_) => finish(true)))
      ..add(player.stream.endFile.listen((_) => finish(false)));
    return done.future.timeout(
      openTimeout,
      onTimeout: () {
        finish(false);
        return false;
      },
    );
  }

  /// [restore], with whatever it throws handed to [report] instead: the
  /// restart carries on without the session rather than failing.
  Future<void> restoreReporting(
    PlayerApi player,
    void Function(Object error) report,
  ) async {
    try {
      await restore(player);
    } on Object catch (e) {
      report(e);
    }
  }

  @override
  String toString() =>
      'PlaybackSnapshot(${queue.length} entries, at $index, $position, '
      '${playing ? 'playing' : 'paused'})';
}
