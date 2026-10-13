import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/console/console_log.dart';
import 'app_settings.dart';

/// The audio engine as [startAudioEngine] hands it over.
typedef AudioEngine = ({
  Player player,
  ConsoleLog consoleLog,
  List<SettingFailure> failures,
});

/// Builds the single [Player] and brings it to a ready state: publishes the
/// OS media session, restores the user's persisted engine configuration and
/// DSP rack, and starts snapshotting future changes back to disk. Also
/// returns an always-on [ConsoleLog] that captures the engine log from boot
/// so the Console shows the full backlog whenever it's first opened.
///
/// Nothing the player refuses here stops the launch: each refused setting
/// lands in `failures` for the caller to report.
///
/// The [Player] stays the single runtime source of truth; [settings] only
/// seeds it on launch ([AppSettingsSync.applyTo]) and records changes
/// ([AppSettingsSync.attach]).
Future<AudioEngine> startAudioEngine(AppSettings settings) async {
  // The creation-only configuration (resume, resume folder, force seeking,
  // downmix normalization, disk cache folder) is read once here; changing
  // one later takes a player restart (MpvStudio.restart).
  final player = Player(configuration: settings.playerConfiguration);

  // Start log capture immediately, before any other setup emits log lines,
  // so nothing is lost before the Console is first opened.
  final consoleLog = ConsoleLog()..attach(player);
  final failures = <SettingFailure>[];

  // Native OS media session (Control Center, SMTC, MPRIS, the lock
  // screen). The advertised controls are user-customisable in Settings;
  // `null` when the user disabled the session entirely.
  try {
    await player.setMediaSession(settings.mediaSession);
  } on Object catch (e) {
    failures.add(SettingFailure('Media session', e));
  }

  // Re-apply the user's last engine configuration and DSP rack, then
  // start snapshotting future changes back to disk.
  failures.addAll(await settings.applyTo(player));
  try {
    await player.setAudioEffects(settings.effects);
  } on Object catch (e) {
    failures.add(SettingFailure('Effects chain', e));
  }
  settings.attach(player);

  return (player: player, consoleLog: consoleLog, failures: failures);
}
