import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';

/// The queue as it was before an action that replaced or emptied it, so
/// the action can be undone.
class QueueSnapshot {
  const QueueSnapshot._(this.items, this.index, this.playing);

  final List<Media> items;
  final int index;
  final bool playing;

  /// The queue of [player] now, or null when it is empty: there is
  /// nothing to put back.
  static QueueSnapshot? of(PlayerApi player) {
    final s = player.state;
    if (s.playlist.items.isEmpty) return null;
    return QueueSnapshot._(
      s.playlist.items,
      s.playlist.index.clamp(0, s.playlist.items.length - 1),
      s.playWhenReady,
    );
  }

  /// Whether the queue of [player] is no longer this one: the action
  /// went through (a refused call leaves it as it was).
  bool changedIn(PlayerApi player) =>
      !identical(player.state.playlist.items, items);

  /// Puts the queue back on the same entry, playing if it was.
  Future<void> restore(PlayerApi player, CallGuard guard) =>
      guard(() => player.openAll(items, play: playing, index: index));
}
