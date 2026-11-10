import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';

/// The queue as it was before an action that replaced or emptied it, so
/// the action can be undone.
class QueueSnapshot {
  QueueSnapshot._(this.items, this.index, this.playing);

  final List<Media> items;
  final int index;
  final bool playing;

  /// The app's queue edits so far: an undo only replaces a queue no edit
  /// came to after the action. Counted, not compared: mpv reports the
  /// playlist after the calls return, so the queue an action left is not
  /// known when its toast shows.
  static int _edits = 0;

  /// Counts an edit of the queue made in the app (an add, a move).
  static void noteEdit() => _edits++;

  /// [_edits] when the action was done, once [seal] saw it.
  int? _sealedAt;

  /// What an undo says when the queue changed after the action.
  static const changedMessage = 'The queue changed since, so it stays';

  /// The queue of [player] now, or null when it is empty: there is
  /// nothing to put back.
  static QueueSnapshot? of(PlayerApi player) {
    final s = player.state;
    if (s.playback.playlist.items.isEmpty) return null;
    return QueueSnapshot._(
      s.playback.playlist.items,
      s.playback.playlist.index.clamp(0, s.playback.playlist.items.length - 1),
      s.playback.playWhenReady,
    );
  }

  /// Whether the queue of [player] is no longer this one: the action
  /// went through (a refused call leaves it as it was).
  bool changedIn(PlayerApi player) =>
      !identical(player.state.playback.playlist.items, items);

  /// Notes that the action is done: an undo only replaces the queue it
  /// left.
  void seal() => _sealedAt = _edits;

  /// Puts the queue back on the same entry, playing if it was. Returns
  /// false, and changes nothing, when the app edited the queue after
  /// [seal]: an undo must not wipe what was added since.
  Future<bool> restore(PlayerApi player, CallGuard guard) async {
    final sealed = _sealedAt;
    if (sealed != null && sealed != _edits) return false;
    await guard(() => player.openAll(items, play: playing, index: index));
    return true;
  }
}
