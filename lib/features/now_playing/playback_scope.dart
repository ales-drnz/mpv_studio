import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';

/// What the Playback page and its widgets work with: the [player], the
/// [guard] every player call goes through, and the app services they read
/// when the app is around them. The page installs it, from the app's
/// [PlayerScope] or from what a test hands it.
class PlaybackScope extends InheritedWidget {
  const PlaybackScope({
    super.key,
    required this.player,
    this.guard = unguarded,
    this.failed,
    this.loudnessSeed,
    required super.child,
  });

  /// The scope built from the app's [PlayerScope] above [context], or null
  /// when there is none (a widget test).
  static PlaybackScope? fromApp(BuildContext context, {required Widget child}) {
    final app = context.dependOnInheritedWidgetOfExactType<PlayerScope>();
    if (app == null) return null;
    final studio = app.studio;
    return PlaybackScope(
      player: studio.player,
      guard: studio.issues.guard,
      failed: studio.issues.failed,
      loudnessSeed: () => studio.normalizer.lastScan,
      child: child,
    );
  }

  final PlayerApi player;

  /// Runs a player call and turns what it throws into a toast.
  final CallGuard guard;

  /// The queue entries whose last attempt to play failed.
  final ValueListenable<Set<Media>>? failed;

  /// The latest loudness scan, to show before the stream replays it.
  final LoudnessScan? Function()? loudnessSeed;

  static PlaybackScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlaybackScope>();
    assert(scope != null, 'No PlaybackScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(PlaybackScope old) =>
      old.player != player || old.guard != guard || old.failed != failed;
}
