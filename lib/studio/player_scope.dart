import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/console/console_log.dart';
import '../features/effects/rack_controller.dart';
import '../features/queue/queue_details.dart';
import '../features/stream/favorites_controller.dart';
import '../features/stream/media_server.dart';
import 'app_settings.dart';
import 'loudness_normalizer.dart';
import 'mpv_studio.dart';
import 'playback_issues.dart';

/// Exposes the running [MpvStudio], the single [Player] and the app's
/// services, to the whole widget tree. MPV Studio is a single-player app, so
/// one studio lives at the root and everything reads from here.
///
/// Pages don't reach for the whole studio; the typed accessors below
/// ([of], [settingsOf], [serverOf], …) hand back exactly the piece they need.
class PlayerScope extends InheritedWidget {
  final MpvStudio studio;

  /// Restarts the player (see [MpvStudio.restart]); null where the tree
  /// is hosted without the app around it.
  final Future<void> Function()? onRestart;

  const PlayerScope({
    super.key,
    required this.studio,
    this.onRestart,
    required super.child,
  });

  static MpvStudio _scope(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlayerScope>();
    assert(scope != null, 'PlayerScope.of() called with no PlayerScope above');
    return scope!.studio;
  }

  static Player of(BuildContext context) => _scope(context).player;

  static AppSettings settingsOf(BuildContext context) =>
      _scope(context).settings;

  /// The EBU R128 volume normalizer (offline-scan driven).
  static LoudnessNormalizer normalizerOf(BuildContext context) =>
      _scope(context).normalizer;

  /// The Signal chain rack, whose bypass is the app's FX bypass.
  static RackController rackOf(BuildContext context) => _scope(context).rack;

  /// The connected server of the given [kind].
  static MediaServer serverOf(BuildContext context, ServerKind kind) =>
      _scope(context).servers[kind]!;

  /// The always-on engine-log buffer.
  static ConsoleLog consoleLogOf(BuildContext context) =>
      _scope(context).consoleLog;

  /// Engine errors made readable (toasts, Console badge, failed entries).
  static PlaybackIssues issuesOf(BuildContext context) =>
      _scope(context).issues;

  /// [issuesOf], or null outside a [PlayerScope] (a shell hosted on its
  /// own, as in the navigation tests).
  static PlaybackIssues? maybeIssuesOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerScope>()?.studio.issues;

  /// What the engine read from the queue entries that have played.
  static QueueDetails queueDetailsOf(BuildContext context) =>
      _scope(context).queueDetails;

  /// The shared favourites store.
  static FavoritesController favoritesOf(BuildContext context) =>
      _scope(context).favorites;

  /// Restarts the player with the current settings, keeping the queue; the
  /// whole tree is rebuilt on the new player. Null without the app around.
  static Future<void> Function()? restartOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerScope>()?.onRestart;

  @override
  bool updateShouldNotify(PlayerScope oldWidget) =>
      oldWidget.studio != studio || oldWidget.onRestart != onRestart;
}
