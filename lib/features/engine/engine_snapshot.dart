import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// One sample of the cache over time, for the "cached ahead" history.
typedef CacheSample = ({double t, double ahead, bool paused});

/// One prefetch transition, for the prefetch timeline.
typedef PrefetchMark = ({double t, PrefetchState state});

/// Everything the Engine panel draws, taken at one moment. [state] is the
/// player's snapshot; the other fields come from the streams that have no
/// snapshot counterpart. [now] and the history times are seconds on the
/// panel's own clock.
class EngineSnapshot {
  final PlayerState state;
  final MpvPlaybackState playbackState;
  final PrefetchState prefetchState;
  final Duration prefetchCacheDuration;
  final WaveformData? waveform;
  final LoudnessScan? loudnessScan;
  final List<CacheSample> cacheHistory;
  final List<PrefetchMark> prefetchHistory;
  final double now;

  /// The user's effects chain while the rack's bypass is on (the engine
  /// then plays a muted copy of it).
  final List<AudioEffect>? bypassedChain;

  const EngineSnapshot({
    required this.state,
    this.playbackState = MpvPlaybackState.idle,
    this.prefetchState = PrefetchState.idle,
    this.prefetchCacheDuration = Duration.zero,
    this.waveform,
    this.loudnessScan,
    this.cacheHistory = const [],
    this.prefetchHistory = const [],
    this.now = 0,
    this.bypassedChain,
  });
}

/// Seconds of a [Duration], as a double.
double secondsOf(Duration d) => d.inMicroseconds / 1e6;
