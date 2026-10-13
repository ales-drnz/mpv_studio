import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/console/console_log.dart';
import '../features/queue/queue_details.dart';
import '../features/stream/favorites_controller.dart';
import '../features/stream/media_server.dart';
import 'app_settings.dart';
import 'audio_engine.dart';
import 'loudness_normalizer.dart';
import 'media_servers.dart';
import 'playback_issues.dart';

/// The running MPV Studio: every long-lived service the player app needs,
/// owned in one place. [launch] turns the app on (settings → audio engine →
/// media servers) and [shutdown] turns it off; the widget tree only ever sees
/// a ready [MpvStudio] handed down through [PlayerScope].
///
/// This is the single home for the app's runtime. Adding a service means
/// adding a field here and a line to [launch] — nothing else in the boot
/// chain changes.
class MpvStudio {
  /// The single audio engine. Stays the one runtime source of truth — every
  /// surface reads its live streams and writes through its setters.
  final Player player;

  /// Persisted engine configuration + DSP rack. Seeds the player on launch
  /// and records changes back to disk.
  final AppSettings settings;

  /// Connected media servers (Jellyfin / Plex), keyed by kind.
  final Map<ServerKind, MediaServer> servers;

  /// Shared favourite (like) state for server tracks — the song-list star and
  /// the OS lock-screen like both read/write this.
  final FavoritesController favorites;

  /// Always-on engine-log buffer, capturing from boot so the Console is never
  /// empty on first open.
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

  const MpvStudio._({
    required this.player,
    required this.settings,
    required this.servers,
    required this.favorites,
    required this.consoleLog,
    required this.normalizer,
    required this.issues,
    required this.queueDetails,
    required void Function() disposeServers,
  }) : _disposeServers = disposeServers;

  /// Stops the media servers' background work (the Plex heartbeat).
  final void Function() _disposeServers;

  /// Powers the app on. Restores persisted settings, starts the audio engine
  /// (with the OS media session and DSP rack), and connects the media servers
  /// with playback reporting and Plex's source resolver. Everything is ready
  /// by the time this returns, so the first frame renders live state.
  static Future<MpvStudio> launch() async {
    // Persisted settings, restored before the first frame.
    final settings = await AppSettings.load();

    final engine = await startAudioEngine(settings);

    // Subscribed before anything loads, so no failure goes unseen.
    final issues = PlaybackIssues.of(engine.player);
    final queueDetails = QueueDetails.of(engine.player);

    final media = await connectMediaServers(engine.player);

    // Volume normalization rides the engine's offline loudness scan; the
    // subscription itself arms the scan, so an off toggle costs nothing.
    final normalizer = LoudnessNormalizer(engine.player, settings)..restore();

    return MpvStudio._(
      player: engine.player,
      settings: settings,
      servers: media.servers,
      favorites: media.favorites,
      consoleLog: engine.consoleLog,
      normalizer: normalizer,
      issues: issues,
      queueDetails: queueDetails,
      disposeServers: media.dispose,
    );
  }

  /// Powers the app off — released on process exit. Stops persistence and the
  /// log buffer, then tears down the audio engine last.
  Future<void> shutdown() async {
    normalizer.dispose();
    _disposeServers();
    issues.dispose();
    queueDetails.dispose();
    await settings.dispose();
    await consoleLog.dispose();
    await player.dispose();
  }
}
