import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../ui/layout/layout.dart';
import '../../util/mixed_content.dart';

/// What a row of the Stream page can do with its media, the entries of its
/// context menu.
enum RowAction {
  playNow('Play now', Icons.play_arrow_rounded),
  playNext('Play next', Icons.queue_play_next_rounded),
  addToQueue('Add to queue', Icons.playlist_add_rounded),
  favorite('Favorite', Icons.star_border_rounded),
  unfavorite('Unfavorite', Icons.star_rounded);

  final String label;
  final IconData icon;
  const RowAction(this.label, this.icon);

  /// The menu entry for this action.
  StudioMenuItem<RowAction> get item =>
      StudioMenuItem(value: this, label: label, icon: icon);

  /// The queue actions every playable row offers.
  static const queueActions = [playNow, playNext, addToQueue];
}

/// The player calls of the Stream page, every one through the app's
/// [CallGuard] so a refused call becomes a toast instead of an uncaught
/// error. Each tab gets one from the page.
///
/// In a browser page served over HTTPS an `http://` entry would only fail
/// on a request the browser blocks: it is not sent to the player, and
/// [notify] says why instead.
class StreamActions {
  const StreamActions({required this.player, required this.guard, this.notify});

  final PlayerApi player;
  final CallGuard guard;

  /// Shows an error notice; the notices of the app's [PlaybackIssues].
  final void Function(String message)? notify;

  bool get _queueEmpty => player.state.playlist.items.isEmpty;

  /// Whether every one of [medias] can be loaded from this page.
  bool _loadable(List<Media> medias) {
    final blocked = medias.any(
      (m) => isBlockedMixedContent(Uri.tryParse(m.uri) ?? Uri()),
    );
    if (blocked) notify?.call(mixedContentMessage);
    return !blocked;
  }

  /// Replaces the queue with [media] and plays it.
  Future<void> play(Media media) async {
    if (!_loadable([media])) return;
    await guard(() => player.open(media, play: true));
  }

  /// Replaces the queue with [medias] and plays the one at [index].
  Future<void> playAll(List<Media> medias, {int index = 0}) async {
    if (medias.isEmpty || !_loadable(medias)) return;
    await guard(() => player.openAll(medias, play: true, index: index));
  }

  /// Appends [medias] to the queue, or plays them when the queue is empty.
  Future<void> enqueue(List<Media> medias) async {
    if (medias.isEmpty || !_loadable(medias)) return;
    await guard(() async {
      if (_queueEmpty) return player.openAll(medias, play: true);
      for (final m in medias) {
        await player.add(m);
      }
    });
  }

  /// Inserts [medias] right after the current entry, or plays them when
  /// the queue is empty.
  Future<void> playNext(List<Media> medias) async {
    if (medias.isEmpty || !_loadable(medias)) return;
    await guard(() async {
      final pl = player.state.playlist;
      if (pl.items.isEmpty) return player.openAll(medias, play: true);
      var end = pl.items.length;
      var to = pl.index < 0 ? end : pl.index + 1;
      for (final m in medias) {
        await player.add(m);
        if (to < end) await player.move(end, to);
        end++;
        to++;
      }
    });
  }

  /// Runs the queue [action] for [medias] (the favourite actions are the
  /// caller's).
  Future<void> run(RowAction action, List<Media> medias) => switch (action) {
    RowAction.playNow =>
      medias.length == 1 ? play(medias.single) : playAll(medias),
    RowAction.playNext => playNext(medias),
    RowAction.addToQueue => enqueue(medias),
    RowAction.favorite || RowAction.unfavorite => Future.value(),
  };
}
