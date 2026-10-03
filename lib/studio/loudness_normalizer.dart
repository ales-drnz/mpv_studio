import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'app_settings.dart';

/// EBU R128 volume normalization, driven by the engine's offline loudness
/// scan (`player.stream.loudness`).
///
/// The loudness is ALWAYS measured (it rides the waveform analyzer's single
/// decode pass), regardless of the toggle: the result feeds both normalization
/// AND the Now Playing info sheet, so opening the sheet finds the measurement
/// ready instead of arming a fresh decode (which would restart the scan from
/// zero). The "Normalize volume" toggle only controls whether the measured
/// gain is APPLIED.
///
/// The gain rides mpv's `volume-gain` (a dB stage separate from the user
/// volume slider), so toggling normalization never touches the user's volume
/// setting. Tracks the scan cannot measure up-front (adaptive or live streams
/// report `unavailable`) play at unity gain.
///
/// Owned by [MpvStudio]; the Settings rows and the Now Playing badge observe
/// this notifier.
class LoudnessNormalizer extends ChangeNotifier {
  LoudnessNormalizer(this._player, this._settings);

  final Player _player;
  final AppSettings _settings;

  StreamSubscription<LoudnessScan?>? _sub;
  LoudnessScan? _lastScan;
  double _appliedGainDb = 0;
  bool _enabled = false;

  /// Whether normalization (the gain) is active. The measurement runs either
  /// way.
  bool get enabled => _enabled;

  /// The most recent scan result for the loaded track (`null` until the
  /// first result lands, and again across a track change).
  LoudnessScan? get lastScan => _lastScan;

  /// The gain currently applied by the normalizer, in dB (0 when off,
  /// when no scan is available yet, or for unmeasurable sources).
  double get appliedGainDb => _appliedGainDb;

  /// Target integrated loudness, LUFS. -18 is the ReplayGain 2.0
  /// reference; streaming services typically sit between -14 and -16.
  double get targetLufs => _settings.loudnessTargetLufs;

  /// Restores the persisted state on launch and arms the (permanent) loudness
  /// measurement. The subscription itself drives the engine's scan
  /// (listener-gated); it stays alive for the normalizer's lifetime so the
  /// measurement is always available without re-decoding.
  void restore() {
    _enabled = _settings.loudnessNormalization;
    _sub = _player.stream.loudnessScan.listen(_onScan);
  }

  /// Turns the gain on/off and records the choice. The measurement keeps
  /// running either way.
  void setEnabled(bool on) {
    if (on == _enabled) return;
    _enabled = on;
    _settings.recordLoudnessNormalization(on);
    // Re-evaluate: apply the measured gain, or revert to unity.
    _onScan(_lastScan);
  }

  /// Changes the target and re-applies it to the current track.
  void setTargetLufs(double lufs) {
    _settings.recordLoudnessTargetLufs(lufs);
    _onScan(_lastScan);
  }

  void _onScan(LoudnessScan? scan) {
    _lastScan = scan;
    if (_enabled && scan?.state == LoudnessScanState.ready) {
      // Clamp generously: a hot-mastered track needs at most a cut of a
      // dozen dB; a very quiet one should not be boosted into clipping.
      _apply((targetLufs - scan!.integrated!).clamp(-24.0, 24.0));
    } else if (scan?.state != LoudnessScanState.scanning) {
      // Normalization off, no ready measurement, or an unmeasurable source:
      // unity gain. The scanning ticks are skipped so volume-gain is not
      // re-applied on every poll.
      _apply(0);
    }
    notifyListeners();
  }

  void _apply(double gainDb) {
    _appliedGainDb = gainDb;
    unawaited(_player.setVolumeGain(gainDb));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
