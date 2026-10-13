import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/console/console_log.dart';
import '../features/effects/rack_controller.dart';
import '../features/queue/queue_details.dart';
import '../features/stream/favorites_controller.dart';
import '../features/stream/media_server.dart';
import 'app_settings.dart';
import 'audio_engine.dart';
import 'loudness_normalizer.dart';
import 'media_servers.dart';
import 'playback_issues.dart';
import 'playback_snapshot.dart';

/// The running MPV Studio: every long-lived service the player app needs,
/// owned in one place. [launch] turns the app on (settings, audio engine,
/// media servers), [shutdown] turns it off and [restart] does both while
/// keeping the queue; the widget tree only ever sees a ready [MpvStudio]
/// handed down through `PlayerScope`.
///
/// This is the single home for the app's runtime. Adding a service means
/// adding a field here, a line to [launch] and one to [shutdown]: nothing
/// else in the boot chain changes.
class MpvStudio {
  /// The single audio engine. Stays the one runtime source of truth: every
  /// surface reads its live streams and writes through its setters.
  final Player player;

  /// Persisted engine configuration and DSP rack. Seeds the player on
  /// launch and records changes back to disk.
  final AppSettings settings;

  /// Connected media servers (Jellyfin, Plex), keyed by kind.
  final Map<ServerKind, MediaServer> servers;

  /// Shared favourite (like) state for server tracks: the song-list star
  /// and the OS lock-screen like both read and write this.
  final FavoritesController favorites;

  /// Always-on engine-log buffer, capturing from boot so the Console is
  /// never empty on first open.
  final ConsoleLog consoleLog;

  /// EBU R128 volume normalization, fed by the engine's offline loudness
  /// scan. The Settings toggle and the Now Playing badge observe this.
  final LoudnessNormalizer normalizer;

  /// Engine errors made readable: toasts, the Console badge and the failed
  /// queue entries.
  final PlaybackIssues issues;

  /// Titles, artists and lengths the engine read from the queue entries
  /// that have played.
  final QueueDetails queueDetails;

  /// The Signal chain rack: the user's effects chain and the one FX
  /// bypass, shared by the Effects page, the mini-player toggle and the
  /// Engine panel.
  final RackController rack;

  MpvStudio._({
    required this.player,
    required this.settings,
    required this.servers,
    required this.favorites,
    required this.consoleLog,
    required this.normalizer,
    required this.issues,
    required this.queueDetails,
    required this.rack,
    required void Function() disposeServers,
  }) : _disposeServers = disposeServers;

  /// Stops the media servers' background work (playback reporting, the
  /// Plex heartbeat).
  final void Function() _disposeServers;

  Future<void>? _shutdown;

  /// Powers the app on. Restores persisted settings, starts the audio engine
  /// (with the OS media session and DSP rack), and connects the media servers
  /// with playback reporting and Plex's source resolver. Everything is ready
  /// by the time this returns, so the first frame renders live state.
  ///
  /// A persisted setting the player refuses does not stop the launch: it is
  /// logged to the Console and reported as one notice.
  static Future<MpvStudio> launch() async {
    // Persisted settings, restored before the first frame.
    final settings = await AppSettings.load();

    final engine = await startAudioEngine(settings);

    // From here a failure must not leave a player (and its OS media
    // session) running: what was built is torn down, newest first, and the
    // error goes on to the caller (the startup error screen, whose retry
    // launches again).
    final undo = <FutureOr<void> Function()>[
      engine.player.dispose,
      engine.consoleLog.dispose,
      settings.dispose,
    ];
    try {
      // Subscribed before anything loads, so no failure goes unseen.
      final issues = PlaybackIssues.of(engine.player);
      undo.add(issues.dispose);
      final queueDetails = QueueDetails.of(engine.player);
      undo.add(queueDetails.dispose);

      final media = await connectMediaServers(engine.player);
      undo.add(media.dispose);

      // Volume normalization rides the engine's offline loudness scan; the
      // subscription itself arms the scan, so an off toggle costs nothing.
      final normalizer = LoudnessNormalizer(
        engine.player,
        settings,
        guard: issues.guard,
      )..restore();
      undo.add(normalizer.dispose);

      // The rack's bypass holds persistence while it plays the muted copy,
      // so a quit mid-comparison keeps the real chain on disk.
      final rack = RackController.forSettings(engine.player, settings);

      final studio = MpvStudio._(
        player: engine.player,
        settings: settings,
        servers: media.servers,
        favorites: media.favorites,
        consoleLog: engine.consoleLog,
        normalizer: normalizer,
        issues: issues,
        queueDetails: queueDetails,
        disposeServers: media.dispose,
        rack: rack,
      );
      studio._reportSettingFailures(engine.failures);
      return studio;
    } on Object {
      await undoAll(undo);
      rethrow;
    }
  }

  /// Runs [steps] newest first, each on its own: one that throws is
  /// logged and the others still run.
  @visibleForTesting
  static Future<void> undoAll(List<FutureOr<void> Function()> steps) async {
    for (final step in steps.reversed) {
      try {
        await step();
      } on Object catch (e) {
        debugPrint('Cleanup after a failed launch: $e');
      }
    }
  }

  void _reportSettingFailures(List<SettingFailure> failures) {
    if (failures.isEmpty) return;
    for (final f in failures) {
      _log(LogLevel.warn, 'setting "${f.setting}" was not applied: ${f.error}');
    }
    issues.notify(describeSettingFailures(failures), isError: true);
  }

  /// A line of the app's own in the Console log.
  void _log(LogLevel level, String text) {
    debugPrint('studio: $text');
    consoleLog.add(MpvLogEntry(prefix: 'studio', level: level, text: text));
  }

  /// Shows an error nothing else caught (a framework error, an async error
  /// that escaped a handler) as a notice, and logs it with its [stack] in
  /// the Console, instead of letting it pass silently.
  void reportUncaught(Object error, StackTrace? stack) {
    _log(
      LogLevel.error,
      'uncaught error: $error${stack == null ? '' : '\n$stack'}',
    );
    issues.notify(describeCallError(error), isError: true);
  }

  /// Restarts the player with the current settings, for the settings the
  /// player reads only when it is created ([RestartSetting]). This studio
  /// shuts down completely first (one OS media session per process), then
  /// a new one launches and returns at once, getting the queue, the current
  /// entry, the position and the play state back in the background (what
  /// fails there becomes a notice). This studio is unusable afterwards.
  Future<MpvStudio> restart() async {
    final snapshot = PlaybackSnapshot.of(player.state);
    await shutdown();
    final next = await launch();
    unawaited(snapshot.restoreReporting(next.player, next.issues.report));
    return next;
  }

  /// Powers the app off: on process exit, and before a [restart]. Stops
  /// persistence, the media servers and the log buffer, then tears down
  /// the audio engine last. Safe to call more than once.
  Future<void> shutdown() => _shutdown ??= _teardown();

  Future<void> _teardown() async {
    normalizer.dispose();
    _disposeServers();
    issues.dispose();
    queueDetails.dispose();
    rack.dispose();
    await settings.dispose();
    await consoleLog.dispose();
    await player.dispose();
  }
}
