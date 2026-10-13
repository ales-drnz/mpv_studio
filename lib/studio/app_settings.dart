import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/effects/effects_codec.dart';
import 'settings_store.dart';

part 'app_settings_sync.dart';

/// The user's engine configuration, effects chain, network options and app
/// preferences, persisted so they survive a restart ([SettingsStore]).
///
/// Persistence is observer-driven: [attach] subscribes to the player's
/// streams and snapshots every relevant value as it changes, no matter
/// which surface changed it (Now Playing, Settings, the OS media session).
/// On launch the caller seeds the player from the persisted values via
/// [applyTo]. Values without a stream (the TLS CA file,
/// the user agent, the log level, the raw options) and the creation-only
/// [PlayerConfiguration] fields are recorded explicitly by the Settings
/// page.
///
/// The [Player] stays the single runtime source of truth; the UI reads
/// live values from its streams and writes through its setters. This
/// store only records and replays.
class AppSettings {
  AppSettings(this._store);

  /// Loads the persisted settings (or defaults on first run).
  static Future<AppSettings> load() async =>
      AppSettings(await SettingsStore.load());

  final SettingsStore _store;
  final List<StreamSubscription<Object?>> _subs = [];

  /// Notifies on every recorded change: the restart banner listens.
  Listenable get changes => _store;

  double _double(String k, double d) => _store.readDouble(k, d);
  int _int(String k, int d) => _store.readInt(k, d);
  bool _bool(String k, bool d) => _store.readBool(k, d);
  String _string(String k, String d) => _store.readString(k, d);
  E _enum<E extends Enum>(String k, List<E> values, E d) =>
      _store.readEnum(k, values, d);
  void _snap(String k, Object? value) => _store.write(k, value);

  // ---- Playback ---------------------------------------------------------
  double get volume => _double('volume', 50);
  double get volumeMax => _double('volumeMax', 130);
  bool get mute => _bool('mute', false);
  double get rate => _double('rate', 1);
  double get pitch => _double('pitch', 1);
  double get volumeGain => _double('volumeGain', 0);
  double get volumeGainMin => _double('volumeGainMin', -96);
  double get volumeGainMax => _double('volumeGainMax', 12);
  bool get pitchCorrection => _bool('pitchCorrection', true);
  Loop get loop => _enum('loop', Loop.values, Loop.off);
  bool get shuffle => _bool('shuffle', false);
  Gapless get gapless => _enum('gapless', Gapless.values, Gapless.weak);
  bool get prefetchPlaylist => _bool('prefetchPlaylist', false);

  ReplayGain get rgMode => _enum('rgMode', ReplayGain.values, ReplayGain.no);
  double get rgPreamp => _double('rgPreamp', 0);
  bool get rgClip => _bool('rgClip', false);
  double get rgFallback => _double('rgFallback', 0);

  ReplayGainSettings get replayGainSettings => ReplayGainSettings(
    mode: rgMode,
    preamp: rgPreamp,
    clip: rgClip,
    fallback: rgFallback,
  );

  /// EBU R128 volume normalization (offline loudness scan, volume-gain).
  bool get loudnessNormalization => _bool('loudnessNormalization', false);

  /// Normalization target, LUFS. -18 = ReplayGain 2.0 reference.
  double get loudnessTargetLufs => _double('loudnessTargetLufs', -18);

  void recordLoudnessNormalization(bool v) => _snap('loudnessNormalization', v);
  void recordLoudnessTargetLufs(double v) => _snap('loudnessTargetLufs', v);

  // ---- Output -----------------------------------------------------------
  // Empty = let mpv auto-probe. mpv has no driver literally named
  // "auto": setting `ao=auto` disables audio output entirely.
  String get audioDriver => _string('audioDriver', '');
  bool get audioExclusive => _bool('audioExclusive', false);
  Format get audioFormat => _enum('audioFormat', Format.values, Format.auto);
  String get audioChannels => _string('audioChannels', 'auto');
  int get audioSampleRate => _int('audioSampleRate', 0);
  int get audioBufferMs => _int('audioBufferMs', 200);
  int get audioDelayUs => _int('audioDelayUs', 0);
  bool get audioMediaRole => _bool('audioMediaRole', true);
  bool get audioNullUntimed => _bool('audioNullUntimed', false);
  bool get audioStreamSilence => _bool('audioStreamSilence', false);
  String get audioClientName => _string('audioClientName', '');

  /// The S/PDIF passthrough codecs, as mpv names them.
  List<String> get audioSpdif => _strings('audioSpdif');

  // ---- Cache and demuxer ------------------------------------------------
  Cache get cacheMode => _enum('cacheMode', Cache.values, Cache.auto);
  int get cacheSecs => _int('cacheSecs', 3600);
  bool get cacheOnDisk => _bool('cacheOnDisk', false);
  bool get cachePause => _bool('cachePause', true);
  int get cachePauseWaitMs => _int('cachePauseWaitMs', 1000);
  bool get cachePauseInitial => _bool('cachePauseInitial', false);

  CacheSettings get cacheSettings => CacheSettings(
    mode: cacheMode,
    secs: Duration(seconds: cacheSecs),
    onDisk: cacheOnDisk,
    pause: cachePause,
    pauseWait: Duration(milliseconds: cachePauseWaitMs),
    pauseInitial: cachePauseInitial,
  );

  /// The demuxer read-ahead settings; null until the user changed one, so
  /// mpv keeps its own defaults.
  DemuxerSettings? get demuxerSettings {
    if (!_store.containsKey('demuxerMaxBytes')) return null;
    const d = DemuxerSettings();
    return DemuxerSettings(
      maxBytes: _int('demuxerMaxBytes', d.maxBytes),
      maxBackBytes: _int('demuxerMaxBackBytes', d.maxBackBytes),
      readahead: Duration(
        milliseconds: _int('demuxerReadaheadMs', d.readahead.inMilliseconds),
      ),
    );
  }

  // ---- Network ----------------------------------------------------------
  int get networkTimeoutSecs => _int('networkTimeoutSecs', 60);
  bool get tlsVerify => _bool('tlsVerify', true);

  /// A CA bundle to verify TLS servers against; empty for the system one.
  String get tlsCaFile => _string('tlsCaFile', '');

  /// The HTTP proxy URL for network streams; empty for none.
  String get httpProxy => _string('httpProxy', '');

  /// Whether mpv keeps an HTTP cookie jar for network streams.
  bool get cookies => _bool('cookies', false);

  /// The HLS variant picked from an adaptive playlist. A runtime setting
  /// since MPV Studio 0.3 (0.2 stored it under the same key).
  HlsBitrate get hlsBitrate =>
      _enum('hlsBitrate', HlsBitrate.values, HlsBitrate.max);

  /// The HTTP User-Agent for every stream that does not bring its own
  /// header; empty for mpv's default.
  String get userAgent => _string('userAgent', '');

  /// The TLS CA file has no stream to observe: the Settings field records
  /// it here (and calls the player setter).
  void recordTlsCaFile(String v) => _snap('tlsCaFile', v);

  /// The user agent is set through a raw property, with no stream.
  void recordUserAgent(String v) => _snap('userAgent', v);

  // ---- Advanced ---------------------------------------------------------
  /// The severity the engine log reaches the Console at.
  LogLevel get logLevel => _enum('logLevel', LogLevel.values, LogLevel.info);
  void recordLogLevel(LogLevel v) => _snap('logLevel', v.name);

  /// Extra mpv options written with `setRawProperty` on every launch, in
  /// order, as name and value.
  List<(String, String)> get rawOptions {
    final raw = _store['rawOptions'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is List && e.length == 2 && e[0] is String && e[1] is String)
          (e[0] as String, e[1] as String),
    ];
  }

  void recordRawOptions(List<(String, String)> options) => _snap('rawOptions', [
    for (final (name, value) in options) [name, value],
  ]);

  // ---- Creation-only PlayerConfiguration fields -------------------------
  // Read ONCE when the Player is constructed (startAudioEngine): there is
  // no runtime setter. The Settings page records them here and offers to
  // restart the player ([RestartSetting.pending]).
  bool get resumePlayback => _bool('resumePlayback', true);
  // Empty string = use mpv's default location.
  String get watchLaterDir => _string('watchLaterDir', '');
  bool get forceSeekable => _bool('forceSeekable', false);
  bool get normalizeDownmix => _bool('normalizeDownmix', false);
  String get demuxerCacheDir => _string('demuxerCacheDir', '');

  void recordResumePlayback(bool v) => _snap('resumePlayback', v);
  void recordWatchLaterDir(String v) => _snap('watchLaterDir', v);
  void recordForceSeekable(bool v) => _snap('forceSeekable', v);
  void recordNormalizeDownmix(bool v) => _snap('normalizeDownmix', v);
  void recordDemuxerCacheDir(String v) => _snap('demuxerCacheDir', v);

  /// The build-time configuration assembled from the persisted values,
  /// passed to the [Player] constructor in `startAudioEngine`.
  PlayerConfiguration get playerConfiguration => PlayerConfiguration(
    initialVolume: volume,
    autoPlay: true,
    logLevel: logLevel,
    resumePlayback: resumePlayback,
    watchLaterDir: watchLaterDir.isEmpty ? null : watchLaterDir,
    forceSeekable: forceSeekable,
    hlsBitrate: hlsBitrate,
    normalizeDownmix: normalizeDownmix,
    demuxerCacheDir: demuxerCacheDir.isEmpty ? null : demuxerCacheDir,
  );

  // ---- Appearance and app ----------------------------------------------
  /// The app theme: dark (the default), light, or following the system.
  /// Read at launch; the theme controller records changes through
  /// [recordThemeMode].
  ThemeMode get themeMode =>
      _enum('themeMode', ThemeMode.values, ThemeMode.dark);
  void recordThemeMode(ThemeMode v) => _snap('themeMode', v.name);

  /// Whether the welcome screen was completed or skipped.
  bool get onboarded => _bool('onboarded', false);
  void recordOnboarded(bool v) => _snap('onboarded', v);

  Cover get coverArtAuto => _enum('coverArtAuto', Cover.values, Cover.no);

  WindowFunction get specWindow =>
      _enum('specWindow', WindowFunction.values, WindowFunction.hann);
  int get specFft => _int('specFft', 2048);
  int get specBands => _int('specBands', 64);

  SpectrumSettings get spectrumSettings => SpectrumSettings(
    window: specWindow,
    fftSize: specFft,
    bandCount: specBands,
  );

  // ---- OS media session -------------------------------------------------
  // The full capability set, in the order the Session page shows them.
  static const _defaultSessionActions = <MediaAction>[
    MediaAction.play,
    MediaAction.pause,
    MediaAction.playPause,
    MediaAction.stop,
    MediaAction.next,
    MediaAction.previous,
    MediaAction.seek,
    MediaAction.fastForward,
    MediaAction.rewind,
    MediaAction.setRepeatMode,
    MediaAction.setShuffle,
    MediaAction.setPlaybackRate,
    MediaAction.like,
  ];

  /// Whether the OS media session is published at all.
  bool get sessionOn => _bool('sessionOn', true);

  /// The user's ordered set of advertised [MediaAction]s. Absent key:
  /// the full default set; an empty stored list is a valid "none".
  List<MediaAction> get sessionActions {
    final raw = _store['sessionActions'];
    if (raw is! List) return List.of(_defaultSessionActions);
    return [
      for (final n in raw)
        for (final a in MediaAction.values)
          if (a.name == n) a,
    ];
  }

  /// Interval (seconds) the OS "skip forward" and "skip back" buttons jump
  /// when [MediaAction.fastForward] and [MediaAction.rewind] are
  /// advertised.
  int get sessionFastForwardSecs => _int('sessionFfSecs', 30);
  int get sessionRewindSecs => _int('sessionRwSecs', 10);

  /// How playback reacts to an OS audio interruption (a call, Siri, an
  /// alarm). Honoured on iOS and Android only (a no-op on desktop).
  InterruptionPolicy get sessionInterruption => _enum(
    'sessionInterruption',
    InterruptionPolicy.values,
    InterruptionPolicy.pauseAndResume,
  );

  /// Builds the session config the app advertises from [actions], keeping
  /// the rate ladder and identity. The skip intervals and interruption
  /// policy default to the persisted values but can be overridden for a
  /// live edit. Shared by [mediaSession] (launch) and the Session settings
  /// (live).
  MediaSession composeMediaSession(
    Iterable<MediaAction> actions, {
    int? fastForwardSecs,
    int? rewindSecs,
    InterruptionPolicy? interruptionPolicy,
  }) => MediaSession(
    artwork: MediaSessionArtwork.embedded,
    actions: actions.toSet(),
    interruptionPolicy: interruptionPolicy ?? sessionInterruption,
    fastForwardInterval: Duration(
      seconds: fastForwardSecs ?? sessionFastForwardSecs,
    ),
    rewindInterval: Duration(seconds: rewindSecs ?? sessionRewindSecs),
    supportedPlaybackRates: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
    appName: 'MPV Studio',
  );

  /// The session to publish on launch, or `null` when disabled.
  MediaSession? get mediaSession =>
      sessionOn ? composeMediaSession(sessionActions) : null;

  /// The Session settings record their edits explicitly (the advertised
  /// set isn't reconstructable from the unordered live stream).
  void recordSession({
    required bool on,
    required List<MediaAction> actions,
    required int fastForwardSecs,
    required int rewindSecs,
    required InterruptionPolicy interruption,
  }) => _store.writeAll({
    'sessionOn': on,
    'sessionActions': [for (final a in actions) a.name],
    'sessionFfSecs': fastForwardSecs,
    'sessionRwSecs': rewindSecs,
    'sessionInterruption': interruption.name,
  });

  // ---- Effects ----------------------------------------------------------
  /// The persisted effects chain, in order. Reads the blob of MPV Studio
  /// 0.2 too, which the next change rewrites in the current format.
  /// A chain that cannot be read is dropped rather than stopping the
  /// launch.
  List<AudioEffect> get effects {
    try {
      return EffectsCodec.decode(_store['effects']);
    } on Object catch (e) {
      debugPrint('Persisted effects chain unreadable: $e');
      return const [];
    }
  }

  /// While true the chain on `stream.audioEffects` is not recorded: the
  /// rack's global bypass plays a switched-off copy of the chain, and
  /// records the user's chain itself through [recordEffects].
  bool holdEffects = false;

  /// Records the effects chain explicitly.
  void recordEffects(List<AudioEffect> fx) =>
      _snap('effects', EffectsCodec.encode(fx));

  // ---- Lifecycle --------------------------------------------------------
  List<String> _strings(String k) {
    final raw = _store[k];
    return raw is List ? [for (final e in raw) ?(e is String ? e : null)] : [];
  }

  /// The keys a reset keeps: the theme and the welcome screen choice.
  static const _keptOnReset = {'themeMode', 'onboarded'};

  /// Stops recording and forgets every value but the theme and the
  /// welcome screen choice, saved at once. Restart the player afterwards
  /// so the defaults take effect.
  Future<void> resetToDefaults() async {
    await _detach();
    _store.clear(keep: _keptOnReset);
    await _store.flush();
  }

  Future<void> _detach() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  /// Cancels observers and flushes any pending write.
  Future<void> dispose() async {
    await _detach();
    await _store.close();
  }
}
