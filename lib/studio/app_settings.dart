import 'dart:async';
import 'dart:convert';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/effects/effects_codec.dart';

/// Persists the user's engine configuration and DSP rack so they survive
/// a restart, backed by a single JSON blob in [SharedPreferences].
///
/// Persistence is observer-driven: [attach] subscribes to the player's
/// streams and snapshots every relevant value as it changes — no matter
/// which surface changed it (Now Playing, Settings, the OS media
/// session). Writes are debounced. On launch the caller seeds the player
/// from the persisted blob via [applyTo].
///
/// The [Player] stays the single runtime source of truth; the UI reads
/// live values from its streams and writes through its setters. This
/// store only records and replays.
class AppSettings {
  static const _key = 'mpv_studio.settings.v1';
  static const _debounce = Duration(milliseconds: 400);

  final SharedPreferences _prefs;
  final Map<String, Object?> _data;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;

  AppSettings._(this._prefs, this._data);

  /// Loads the persisted settings (or defaults on first run).
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    Map<String, Object?> data = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = decoded.cast<String, Object?>();
      } catch (_) {
        // Corrupt blob — start clean rather than crash.
      }
    }
    return AppSettings._(prefs, data);
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_prefs.setString(_key, jsonEncode(_data)));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, _flush);
  }

  /// Records [value] under [key], scheduling a debounced save when it
  /// actually changed.
  void _snap(String key, Object? value) {
    if (_data[key] == value) return;
    _data[key] = value;
    _scheduleSave();
  }

  double _double(String k, double d) => (_data[k] as num?)?.toDouble() ?? d;
  int _int(String k, int d) => (_data[k] as num?)?.toInt() ?? d;
  bool _bool(String k, bool d) => _data[k] as bool? ?? d;
  String _string(String k, String d) => _data[k] as String? ?? d;

  E _enumByName<E extends Enum>(String k, List<E> values, E d) {
    final name = _data[k] as String?;
    if (name == null) return d;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return d;
  }

  // ---- Persisted values (read for restore + non-observable UI) ----
  double get volume => _double('volume', 50);
  double get volumeMax => _double('volumeMax', 130);
  bool get mute => _bool('mute', false);
  double get rate => _double('rate', 1);
  double get pitch => _double('pitch', 1);
  double get volumeGain => _double('volumeGain', 0);
  bool get pitchCorrection => _bool('pitchCorrection', true);
  Loop get loop => _enumByName('loop', Loop.values, Loop.off);
  bool get shuffle => _bool('shuffle', false);
  Gapless get gapless => _enumByName('gapless', Gapless.values, Gapless.weak);

  ReplayGain get rgMode =>
      _enumByName('rgMode', ReplayGain.values, ReplayGain.no);
  double get rgPreamp => _double('rgPreamp', 0);
  bool get rgClip => _bool('rgClip', false);
  double get rgFallback => _double('rgFallback', 0);

  // Empty = let mpv auto-probe. mpv has no driver literally named
  // "auto" — setting `ao=auto` disables audio output entirely.
  String get audioDriver => _string('audioDriver', '');
  bool get audioExclusive => _bool('audioExclusive', false);
  Format get audioFormat =>
      _enumByName('audioFormat', Format.values, Format.auto);
  String get audioChannels => _string('audioChannels', 'auto');
  int get audioSampleRate => _int('audioSampleRate', 0);
  int get audioBufferMs => _int('audioBufferMs', 200);

  Cache get cacheMode => _enumByName('cacheMode', Cache.values, Cache.auto);
  int get cacheSecs => _int('cacheSecs', 3600);
  bool get cacheOnDisk => _bool('cacheOnDisk', false);
  bool get cachePauseInitial => _bool('cachePauseInitial', false);
  int get networkTimeoutSecs => _int('networkTimeoutSecs', 60);
  bool get tlsVerify => _bool('tlsVerify', true);

  // ---- Build-time PlayerConfiguration knobs ---------------------------
  // These are read ONCE when the Player is constructed (startAudioEngine),
  // so the Settings UI records them here and they take effect on next
  // launch — there is no runtime setter / stream to observe.
  bool get resumePlayback => _bool('resumePlayback', true);
  // Empty string = use mpv's default location.
  String get watchLaterDir => _string('watchLaterDir', '');
  bool get forceSeekable => _bool('forceSeekable', false);
  HlsBitrate get hlsBitrate =>
      _enumByName('hlsBitrate', HlsBitrate.values, HlsBitrate.max);
  bool get normalizeDownmix => _bool('normalizeDownmix', false);

  /// EBU R128 volume normalization (offline loudness scan → volume-gain).
  bool get loudnessNormalization => _bool('loudnessNormalization', false);

  /// Normalization target, LUFS. -18 = ReplayGain 2.0 reference.
  double get loudnessTargetLufs => _double('loudnessTargetLufs', -18);
  String get demuxerCacheDir => _string('demuxerCacheDir', '');

  void recordResumePlayback(bool v) => _snap('resumePlayback', v);
  void recordWatchLaterDir(String v) => _snap('watchLaterDir', v);
  void recordForceSeekable(bool v) => _snap('forceSeekable', v);
  void recordHlsBitrate(HlsBitrate v) => _snap('hlsBitrate', v.name);
  void recordNormalizeDownmix(bool v) => _snap('normalizeDownmix', v);

  void recordLoudnessNormalization(bool v) => _snap('loudnessNormalization', v);

  void recordLoudnessTargetLufs(double v) => _snap('loudnessTargetLufs', v);
  void recordDemuxerCacheDir(String v) => _snap('demuxerCacheDir', v);

  /// The build-time configuration assembled from the persisted knobs, passed
  /// to the [Player] constructor in `startAudioEngine`.
  PlayerConfiguration get playerConfiguration => PlayerConfiguration(
        initialVolume: volume,
        autoPlay: true,
        logLevel: LogLevel.info,
        resumePlayback: resumePlayback,
        watchLaterDir: watchLaterDir.isEmpty ? null : watchLaterDir,
        forceSeekable: forceSeekable,
        hlsBitrate: hlsBitrate,
        normalizeDownmix: normalizeDownmix,
        demuxerCacheDir: demuxerCacheDir.isEmpty ? null : demuxerCacheDir,
      );

  Cover get coverArtAuto => _enumByName('coverArtAuto', Cover.values, Cover.no);

  WindowFunction get specWindow =>
      _enumByName('specWindow', WindowFunction.values, WindowFunction.hann);
  int get specFft => _int('specFft', 2048);
  int get specBands => _int('specBands', 64);

  ReplayGainSettings get replayGainSettings => ReplayGainSettings(
        mode: rgMode,
        preamp: rgPreamp,
        clip: rgClip,
        fallback: rgFallback,
      );

  CacheSettings get cacheSettings => CacheSettings(
        mode: cacheMode,
        secs: Duration(seconds: cacheSecs),
        onDisk: cacheOnDisk,
        pauseInitial: cachePauseInitial,
      );

  SpectrumSettings get spectrumSettings => SpectrumSettings(
        window: specWindow,
        fftSize: specFft,
        bandCount: specBands,
      );

  // ---- OS media session ----------------------------------------------
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

  /// The user's ordered set of advertised [MediaAction]s. Absent key →
  /// the full default set; an empty stored list is a valid "none".
  List<MediaAction> get sessionActions {
    final raw = _data['sessionActions'];
    if (raw is! List) return List.of(_defaultSessionActions);
    return [
      for (final n in raw)
        for (final a in MediaAction.values)
          if (a.name == n) a,
    ];
  }

  /// Interval (seconds) the OS "skip forward / back N seconds" buttons jump
  /// when [MediaAction.fastForward] / [MediaAction.rewind] are advertised.
  int get sessionFastForwardSecs => _int('sessionFfSecs', 30);
  int get sessionRewindSecs => _int('sessionRwSecs', 10);

  /// How playback reacts to an OS audio interruption (call / Siri / alarm).
  /// Honoured on iOS & Android only (a no-op on desktop).
  InterruptionPolicy get sessionInterruption => _enumByName(
        'sessionInterruption',
        InterruptionPolicy.values,
        InterruptionPolicy.pauseAndResume,
      );

  /// Builds the session config the app advertises from [actions], keeping the
  /// rate ladder / identity. The skip intervals and interruption policy
  /// default to the persisted values but can be overridden for a live edit.
  /// Single source of truth shared by [mediaSession] (launch) and the Session
  /// page (live).
  MediaSession composeMediaSession(
    Iterable<MediaAction> actions, {
    int? fastForwardSecs,
    int? rewindSecs,
    InterruptionPolicy? interruptionPolicy,
  }) =>
      MediaSession(
        artwork: MediaSessionArtwork.embedded,
        actions: actions.toSet(),
        interruptionPolicy: interruptionPolicy ?? sessionInterruption,
        fastForwardInterval:
            Duration(seconds: fastForwardSecs ?? sessionFastForwardSecs),
        rewindInterval: Duration(seconds: rewindSecs ?? sessionRewindSecs),
        supportedPlaybackRates: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        appName: 'MPV Studio',
      );

  /// The session to publish on launch, or `null` when disabled.
  MediaSession? get mediaSession =>
      sessionOn ? composeMediaSession(sessionActions) : null;

  /// The persisted effects chain, in order. Reads the blob of MPV Studio
  /// 0.2 too, which the next change rewrites in the current format.
  List<AudioEffect> get effects => EffectsCodec.decode(_data['effects']);

  /// While true the chain on `stream.audioEffects` is not recorded: the
  /// rack's global bypass plays a switched-off copy of the chain, and
  /// records the user's chain itself through [recordEffects].
  bool holdEffects = false;

  /// Records the effects chain explicitly.
  void recordEffects(List<AudioEffect> fx) =>
      _snapJson('effects', EffectsCodec.encode(fx));

  /// [_snap] for JSON values, which compare by content.
  void _snapJson(String key, Object? value) {
    if (jsonEncode(_data[key]) == jsonEncode(value)) return;
    _data[key] = value;
    _scheduleSave();
  }

  /// Exclusive audio output has no observable stream, so the Settings
  /// toggle records it explicitly here (and calls the player setter).
  void recordExclusive(bool value) => _snap('audioExclusive', value);

  /// The Session page records its media-session edits explicitly (the
  /// advertised set isn't reconstructable from the unordered live stream).
  void recordSessionOn(bool value) => _snap('sessionOn', value);
  void recordSessionActions(List<MediaAction> actions) {
    _data['sessionActions'] = [for (final a in actions) a.name];
    _scheduleSave();
  }

  void recordSessionFastForward(int secs) => _snap('sessionFfSecs', secs);
  void recordSessionRewind(int secs) => _snap('sessionRwSecs', secs);
  void recordSessionInterruption(InterruptionPolicy p) =>
      _snap('sessionInterruption', p.name);

  /// Seeds the live player from the persisted blob on launch. Effects are
  /// applied separately by the caller (they need the codec).
  Future<void> applyTo(Player p) async {
    await p.setVolumeMax(volumeMax);
    await p.setVolume(volume);
    await p.setMute(mute);
    await p.setRate(rate);
    await p.setPitch(pitch);
    await p.setVolumeGain(volumeGain);
    await p.setPitchCorrection(pitchCorrection);
    await p.setLoop(loop);
    await p.setShuffle(shuffle);
    await p.setGapless(gapless);
    await p.setReplayGain(replayGainSettings);
    // Only force a specific driver; empty / "auto" means let mpv probe.
    if (audioDriver.isNotEmpty && audioDriver != 'auto') {
      await p.setAudioDriver(audioDriver);
    }
    await p.setAudioExclusive(audioExclusive);
    await p.setAudioFormat(audioFormat);
    await p.setAudioChannels(Channels.fromMpv(audioChannels));
    if (audioSampleRate > 0) await p.setAudioSampleRate(audioSampleRate);
    await p.setAudioBuffer(Duration(milliseconds: audioBufferMs));
    await p.setCache(cacheSettings);
    await p.setNetworkTimeout(Duration(seconds: networkTimeoutSecs));
    await p.setTlsVerify(tlsVerify);
    await p.setCoverArtAuto(coverArtAuto);
    p.setSpectrum(spectrumSettings);
  }

  /// Subscribes to the player's streams and snapshots every relevant
  /// value as it changes. Call once, after [applyTo].
  void attach(Player p) {
    final s = p.stream;
    _subs.addAll([
      s.volume.listen((v) => _snap('volume', v)),
      s.volumeMax.listen((v) => _snap('volumeMax', v)),
      s.mute.listen((v) => _snap('mute', v)),
      s.rate.listen((v) => _snap('rate', v)),
      s.pitch.listen((v) => _snap('pitch', v)),
      // Skip persisting volume-gain while loudness normalization owns the
      // stage: the LoudnessNormalizer drives `volume-gain` per track, so
      // persisting it here would overwrite the user's MANUAL gain slider and
      // re-seed a stale normalizer value on the next launch (before the scan
      // re-runs). When normalization is off, the slider owns the value again.
      s.volumeGain.listen((v) {
        if (!loudnessNormalization) _snap('volumeGain', v);
      }),
      s.pitchCorrection.listen((v) => _snap('pitchCorrection', v)),
      s.loop.listen((v) => _snap('loop', v.name)),
      s.shuffle.listen((v) => _snap('shuffle', v)),
      s.gapless.listen((v) => _snap('gapless', v.name)),
      s.replayGain.listen((v) {
        _data['rgMode'] = v.mode.name;
        _data['rgPreamp'] = v.preamp;
        _data['rgClip'] = v.clip;
        _data['rgFallback'] = v.fallback;
        _scheduleSave();
      }),
      s.audioDriver.listen((v) => _snap('audioDriver', v)),
      s.audioFormat.listen((v) => _snap('audioFormat', v.name)),
      s.audioChannels.listen((v) => _snap('audioChannels', v.mpvValue)),
      s.audioSampleRate.listen((v) => _snap('audioSampleRate', v)),
      s.audioBuffer.listen((v) => _snap('audioBufferMs', v.inMilliseconds)),
      s.cache.listen((v) {
        _data['cacheMode'] = v.mode.name;
        _data['cacheSecs'] = v.secs.inSeconds;
        _data['cacheOnDisk'] = v.onDisk;
        _data['cachePauseInitial'] = v.pauseInitial;
        _scheduleSave();
      }),
      s.networkTimeout.listen((v) => _snap('networkTimeoutSecs', v.inSeconds)),
      s.tlsVerify.listen((v) => _snap('tlsVerify', v)),
      s.coverArtAuto.listen((v) => _snap('coverArtAuto', v.name)),
      s.spectrum.listen((v) {
        _data['specWindow'] = v.window.name;
        _data['specFft'] = v.fftSize;
        _data['specBands'] = v.bandCount;
        _scheduleSave();
      }),
      s.audioEffects.listen((v) {
        if (!holdEffects) recordEffects(v);
      }),
    ]);
  }

  /// Cancels observers and flushes any pending write.
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    if (_saveTimer?.isActive ?? false) _flush();
  }
}
