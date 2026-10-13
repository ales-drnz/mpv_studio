import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// A [PlayerApi] with no engine behind it, for widget tests.
///
/// [state] is a plain [PlayerState] the test edits with [emit]; every
/// state stream replays the current value on listen and follows each
/// [emit]. The stream-only values ([playbackState], [prefetchState] and so
/// on) are fields set through [emitExtra]. Commands are recorded in
/// [calls] and applied to [state] where it makes sense.
class FakePlayer implements PlayerApi {
  FakePlayer([PlayerState? initial])
      : _state = initial ?? const PlayerState();

  PlayerState _state;
  final _changes = StreamController<void>.broadcast(sync: true);
  late final FakePlayerStream _stream = FakePlayerStream(this);

  /// Commands received, e.g. `play`, `seek +5000`, `setMute true`.
  final List<String> calls = [];

  MpvPlaybackState playbackState = MpvPlaybackState.idle;
  PrefetchState prefetchState = PrefetchState.idle;
  Duration prefetchCacheDuration = Duration.zero;
  WaveformData? waveform;
  LoudnessScan? loudnessScan;

  @override
  PlayerState get state => _state;

  @override
  PlayerStream get stream => _stream;

  /// Applies [change] to [state] and notifies every stream.
  void emit(PlayerState Function(PlayerState s) change) {
    _state = change(_state);
    _changes.add(null);
  }

  /// Runs [change] on the stream-only fields and notifies every stream.
  void emitExtra(void Function(FakePlayer p) change) {
    change(this);
    _changes.add(null);
  }

  Stream<T> watch<T>(T Function(FakePlayer p) pick) async* {
    yield pick(this);
    yield* _changes.stream.map((_) => pick(this));
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit((s) => s.copyWith(playWhenReady: true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit((s) => s.copyWith(playWhenReady: false));
  }

  @override
  Future<bool> next({bool force = false}) async {
    calls.add('next');
    return true;
  }

  @override
  Future<bool> previous({bool force = false}) async {
    calls.add('previous');
    return true;
  }

  @override
  Future<void> seek(
    Duration position, {
    bool relative = false,
    bool exact = false,
  }) async {
    calls.add(
      relative
          ? 'seek ${position.isNegative ? '' : '+'}${position.inMilliseconds}'
          : 'seek ${position.inMilliseconds}',
    );
  }

  @override
  Future<void> seekToPercent(
    double percent, {
    bool relative = false,
    bool exact = false,
  }) async {
    calls.add('seekToPercent ${percent.round()}');
  }

  @override
  Future<void> setMute(bool mute) async {
    calls.add('setMute $mute');
    emit((s) => s.copyWith(mute: mute));
  }

  @override
  Future<void> setAudioEffects(List<AudioEffect> effects) async {
    calls.add('setAudioEffects ${effects.length}');
    emit((s) => s.copyWith(audioEffects: List.unmodifiable(effects)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakePlayer: ${invocation.memberName}');
}

/// The streams of a [FakePlayer]. Only the ones the app's shell and Engine
/// panel read are wired; the rest throw.
class FakePlayerStream implements PlayerStream {
  FakePlayerStream(this._p);
  final FakePlayer _p;

  Stream<T> _s<T>(T Function(PlayerState s) pick) =>
      _p.watch((p) => pick(p.state));

  @override
  Stream<bool> get playWhenReady => _s((s) => s.playWhenReady);
  @override
  Stream<bool> get playing => _s((s) => s.playing);
  @override
  Stream<bool> get completed => _s((s) => s.completed);
  @override
  Stream<Duration> get position => _s((s) => s.position);
  @override
  Stream<Duration> get duration => _s((s) => s.duration);
  @override
  Stream<bool> get mute => _s((s) => s.mute);
  @override
  Stream<Playlist> get playlist => _s((s) => s.playlist);
  @override
  Stream<Map<String, String>> get metadata => _s((s) => s.metadata);
  @override
  Stream<String> get mediaTitle => _s((s) => s.mediaTitle);
  @override
  Stream<CoverArt?> get coverArt => _s((s) => s.coverArt);
  @override
  Stream<List<AudioEffect>> get audioEffects => _s((s) => s.audioEffects);
  @override
  Stream<MpvPlaybackState> get playbackState =>
      _p.watch((p) => p.playbackState);
  @override
  Stream<PrefetchState> get prefetchState => _p.watch((p) => p.prefetchState);
  @override
  Stream<Duration> get prefetchCacheDuration =>
      _p.watch((p) => p.prefetchCacheDuration);
  @override
  Stream<WaveformData?> get waveform => _p.watch((p) => p.waveform);
  @override
  Stream<LoudnessScan?> get loudnessScan => _p.watch((p) => p.loudnessScan);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakePlayerStream: ${invocation.memberName}');
}
