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
  /// gives up on the position.
  static const openTimeout = Duration(seconds: 10);

  /// Positions this close to the start are not worth a seek.
  static const _minSeek = Duration(seconds: 1);

  /// Loads the queue on [player] paused at the current entry, seeks to the
  /// position once the entry has opened (a live stream that cannot seek
  /// starts over), then resumes when it was playing. An empty queue
  /// restores nothing.
  Future<void> restore(PlayerApi player) async {
    if (queue.isEmpty) return;
    final at = index.clamp(0, queue.length - 1);
    final opened = index >= 0 && position >= _minSeek
        ? player.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(openTimeout)
        : null;
    try {
      await player.openAll(queue, index: at, play: false);
    } on Object {
      opened?.ignore();
      rethrow;
    }
    if (opened != null) {
      try {
        await opened;
        await player.seek(position);
      } on TimeoutException {
        // The entry never reported a length: play it from the start.
      }
    }
    if (playing) await player.play();
  }

  @override
  String toString() =>
      'PlaybackSnapshot(${queue.length} entries, at $index, $position, '
      '${playing ? 'playing' : 'paused'})';
}
