import 'dart:async';
import 'dart:typed_data';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../queue/queue_fake.dart';
import 'showcase_library.dart';
import 'showcase_track.dart';

/// A fake player that plays, for the showcase scenes: the queue fake's
/// commands (open, add, move, jump, next and the rest act on its
/// playlist), the Playback page's streams, and a playhead that [advance]
/// moves on in scene time, looping between A and B like mpv and going on
/// to the next entry at the end of one. Each entry known to [tracks]
/// gets its length, cover and waveform as it starts; the spectrum and
/// level taps carry what [ShowcaseSong] sounds like at the playhead.
class ShowcasePlayer extends QueueFakePlayer {
  ShowcasePlayer(
    PlayerState super.initial, {
    Map<String, ShowcaseEntry>? tracks,
  }) : _playhead = initial.position,
       tracks = tracks ?? {};

  final _fft = StreamController<FftFrame>.broadcast();
  final _pcm = StreamController<PcmFrame>.broadcast();
  final _loudness = StreamController<Loudness>.broadcast();
  final _taps = <(AudioFilter, int, TapSide), StreamController<PcmFrame>>{};

  /// Whether the output tap carries real blocks of samples (for the
  /// stereo scope and the per-stage meters) instead of one peak pair a
  /// frame (enough for the level meter).
  bool pcmBlocks = false;

  /// How a stage changes the sound, as (gain, brightness) of what comes
  /// out of it, for its "after" meter.
  final Map<AudioFilter, (double, double)> stageTone = {};

  Stream<PcmFrame> _tap(AudioFilter filter, int instance, TapSide side) =>
      _taps.putIfAbsent((
        filter,
        instance,
        side,
      ), StreamController<PcmFrame>.broadcast).stream;

  late final ShowcaseStream _stream = ShowcaseStream(this);

  @override
  PlayerStream get stream => _stream;

  /// What each queue entry is, by its URI.
  final Map<String, ShowcaseEntry> tracks;

  /// Seeks land on multiples of this (a scene's frame length, or the
  /// [updateInterval]), so the playhead stays on the grid and a scene can
  /// end exactly where it began. Null lands where asked.
  Duration? seekGrid;

  /// How often the spectrum and the reported position move on, or null
  /// for every frame. A GIF stays far smaller when they move together a
  /// few times a second: each spectrum update redraws a whole curve, and
  /// each playhead step a whole column of the waveform.
  Duration? updateInterval;
  int _lastBucket = -1;

  /// Where the song really is; [PlayerState.position] reports it on the
  /// [updateInterval] grid.
  Duration get playhead => _playhead;
  Duration _playhead;

  /// The entry whose length and cover are loaded.
  String? _loaded;

  /// The showcase song playing at [at] with [cover], the rest of its
  /// album around it.
  factory ShowcasePlayer.playing({
    required Duration at,
    required Uint8List cover,
  }) {
    final album = showcaseAlbum(ShowcaseSong.album).files;
    final index = album.indexWhere((t) => t.title == ShowcaseSong.title);
    return ShowcasePlayer.queue(
      [...album.skip(index), ...album.take(index)],
      covers: {0: cover},
      at: at,
    );
  }

  /// [queue] in the playlist, entry [index] playing at [at], with the
  /// [covers] painted for it (by cover number).
  factory ShowcasePlayer.queue(
    List<ShowcaseTrack> queue, {
    required Map<int, Uint8List> covers,
    int index = 0,
    Duration at = Duration.zero,
    bool playing = true,
  }) {
    final player = ShowcasePlayer(
      PlayerState(
        playlist: Playlist([for (final t in queue) t.media], index: index),
        playWhenReady: playing,
        playing: playing,
        position: at,
        seekable: true,
        volume: 80,
        volumeMax: 130,
        audioOutParams: const AudioParams(
          format: Format.float32,
          sampleRate: 48000,
          channelCount: 2,
          hrChannels: 'stereo',
        ),
      ),
      tracks: {
        for (final t in queue)
          t.media.uri: ShowcaseEntry(t, cover: covers[t.cover]),
      },
    );
    player.playbackState = playing
        ? MpvPlaybackState.playing
        : MpvPlaybackState.paused;
    player._load(at: at);
    return player;
  }

  /// Registers [entries] so they load like the queue's own when they play
  /// (files added later, server tracks).
  void know(Iterable<ShowcaseEntry> entries) {
    for (final e in entries) {
      tracks[e.track.media.uri] = e;
    }
  }

  /// The entry for [uri], also as a bare path (files added from a picker
  /// carry no scheme).
  ShowcaseEntry? _entry(String? uri) =>
      uri == null ? null : (tracks[uri] ?? tracks['file://$uri']);

  Media? get _current {
    final pl = state.playlist;
    return pl.index >= 0 && pl.index < pl.items.length
        ? pl.items[pl.index]
        : null;
  }

  /// Loads what the current entry is, as mpv reports a new file: length,
  /// cover, tags, chapters for the showcase song, the waveform, and the
  /// playhead at [at].
  void _load({Duration at = Duration.zero}) {
    final media = _current;
    _loaded = media?.uri;
    if (media == null) return;
    final entry = _entry(media.uri);
    final track = entry?.track;
    final length = track?.length ?? const Duration(minutes: 4);
    final song = track?.title == ShowcaseSong.title;
    _playhead = at;
    _lastBucket = -1;
    final path = track == null || track.url != null ? media.uri : track.path;
    emit(
      (s) => s.copyWith(
        duration: length,
        position: at,
        audioPts: at,
        timeRemaining: length - at,
        chapters: song ? ShowcaseSong.chapters : const [],
        currentChapter: song ? _chapterAt(at) : null,
        coverArt: entry?.cover == null
            ? null
            : CoverArt(bytes: entry!.cover!, mimeType: 'image/png'),
        audioParams: const AudioParams(
          format: Format.s16,
          sampleRate: 44100,
          channelCount: 2,
          hrChannels: 'stereo',
          codec: 'FLAC',
        ),
        fileFormat: 'flac',
        audioBitrate: 968000.0,
        streamPath: media.uri,
        path: path,
        filename: path.split('/').last,
        fileSize: (length.inMilliseconds * 121).round(),
      ),
    );
    emitExtra(
      (p) => p
        ..waveform = ShowcaseSong.waveform(duration: length)
        ..loudnessScan = ShowcaseSong.loudness,
    );
    loaded.add(null);
  }

  static int? _chapterAt(Duration at) {
    int? index;
    for (var i = 0; i < ShowcaseSong.chapters.length; i++) {
      if (ShowcaseSong.chapters[i].time <= at) index = i;
    }
    return index;
  }

  /// The song's time for the playhead: every track follows the showcase
  /// song's shape, stretched to its own length.
  double _songSecs(Duration pos) {
    final d = state.duration.inMicroseconds;
    if (d <= 0) return 0;
    return pos.inMicroseconds / d * (ShowcaseSong.length.inMicroseconds / 1e6);
  }

  /// Plays on by [dt] of scene time, then reports the position and hands
  /// the analysers what the song sounds like there.
  void advance(Duration dt) {
    if (_current?.uri != _loaded) _load();
    if (_current == null) return;
    final s = state;
    var pos = _playhead;
    if (s.playWhenReady) {
      pos += dt * s.rate;
      final a = s.abLoopA;
      final b = s.abLoopB;
      if (a != null && b != null && pos >= b) pos = a + (pos - b);
      if (pos >= s.duration) {
        // The end of the entry: it played, the next one starts.
        endFile.add(
          const MpvFileEndedEvent(reason: MpvEndFileReason.eof, error: 0),
        );
        final i = s.playlist.index;
        if (i + 1 < s.playlist.items.length) {
          emit(
            (st) => st.copyWith(playlist: st.playlist.copyWith(index: i + 1)),
          );
          _load();
          return;
        }
        pos = s.duration;
      }
    }
    _playhead = pos;
    // On the playhead's grid: the same stretch of the song updates on the
    // same frames, so a scene that ends where it began looks the same
    // there. The position is reported on every frame even when it holds,
    // like mpv's own reports.
    final every = updateInterval;
    final bucket = every == null
        ? -1
        : pos.inMicroseconds ~/ every.inMicroseconds;
    _report(every == null ? pos : every * bucket);
    final t = _songSecs(pos);
    if (s.playWhenReady && (every == null || bucket != _lastBucket)) {
      _lastBucket = bucket;
      _fft.add(ShowcaseSong.spectrum(t));
    }
    if (!s.playWhenReady) return;
    if (!pcmBlocks && _taps.isEmpty) {
      _pcm.add(ShowcaseSong.levels(t));
    } else {
      _feedBlocks(t, dt);
    }
    _loudness.add(_reading(t));
  }

  PcmFrame _frame(Float32List samples, double t) => PcmFrame(
    samples: samples,
    timestamp: Duration(microseconds: (t * 1e6).round()),
    sampleRate: 48000,
    channels: 2,
  );

  void _feedBlocks(double t, Duration dt) {
    final n = (dt.inMicroseconds * 48000 / 1e6).round();
    final dry = ShowcaseSong.block(t, n);
    _pcm.add(_frame(dry, t));
    for (final MapEntry(key: (filter, _, side), value: c) in _taps.entries) {
      if (!c.hasListener) continue;
      final (gain, brightness) = stageTone[filter] ?? (1.0, 1.0);
      final samples = side == TapSide.pre || (gain == 1 && brightness == 1)
          ? dry
          : ShowcaseSong.block(t, n, gain: gain, brightness: brightness);
      c.add(_frame(samples, t));
    }
  }

  /// A live loudness reading at song time [t].
  Loudness _reading(double t) {
    final e = ShowcaseSong.energy(t);
    final d = ShowcaseSong.drums(t);
    return Loudness(
      momentary: -24 + 15 * e + 1.5 * d.kick,
      shortTerm: -23 + 14 * ShowcaseSong.energy(t - 1.5),
      integrated: -10.4,
      range: 6.2,
    );
  }

  void _report(Duration pos) {
    final song = _entry(_current?.uri)?.track.title == ShowcaseSong.title;
    emit(
      (s) => s.copyWith(
        position: pos,
        audioPts: pos,
        timeRemaining: s.duration - pos,
        currentChapter: song ? _chapterAt(pos) : null,
      ),
    );
  }

  /// Marks the current entry failed, as mpv does when a file cannot be
  /// opened, and moves on to the next one.
  void failCurrent() {
    _loaded = null;
    endFile.add(
      const MpvFileEndedEvent(
        reason: MpvEndFileReason.error,
        error: MpvError.mpvErrorLoadingFailed,
      ),
    );
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
    var to = relative ? _playhead + position : position;
    final grid = seekGrid;
    if (grid != null && grid > Duration.zero) {
      to = grid * (to.inMicroseconds / grid.inMicroseconds).round();
    }
    final end = state.duration;
    _playhead = to < Duration.zero ? Duration.zero : (to > end ? end : to);
    _report(_playhead);
  }

  /// Called with each entry [open] plays, for scenes that react to it
  /// (the Resolver's signed links).
  void Function(Media media)? onOpen;

  @override
  Future<void> open(Media media, {bool? play}) async {
    await super.open(media, play: play);
    _loaded = null;
    onOpen?.call(media);
  }

  @override
  Future<void> sendRawCommand(List<String> args) async {
    await super.sendRawCommand(args);
    // The Console's seeks move the playhead, like mpv's.
    if (args.length >= 2 && args.first == 'seek') {
      final secs = double.tryParse(args[1]);
      if (secs == null) return;
      final by = Duration(microseconds: (secs * 1e6).round());
      final absolute = args.length > 2 && args[2].startsWith('absolute');
      await seek(by, relative: !absolute);
    }
  }

  @override
  Future<void> jump(int index) async {
    // Like mpv, a jump to the playing entry starts it again.
    await super.jump(index);
    _loaded = null;
  }

  @override
  Future<void> play() async {
    await super.play();
    playbackState = MpvPlaybackState.playing;
    emit((s) => s.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    await super.pause();
    playbackState = MpvPlaybackState.paused;
    emit((s) => s.copyWith(playing: false));
  }

  @override
  Future<void> setAbLoopA(Duration? position) async =>
      emit((s) => s.copyWith(abLoopA: position));

  @override
  Future<void> setAbLoopB(Duration? position) async =>
      emit((s) => s.copyWith(abLoopB: position));

  @override
  Future<void> setAbLoopCount(int? count) async =>
      emit((s) => s.copyWith(abLoopCount: count));

  @override
  Future<void> setChapter(int index) async {
    final chapters = state.chapters;
    if (index < 0 || index >= chapters.length) return;
    await seek(chapters[index].time);
  }

  @override
  Future<void> setRate(double rate) async =>
      emit((s) => s.copyWith(rate: rate));

  @override
  Future<void> setVolume(double volume) async =>
      emit((s) => s.copyWith(volume: volume));

  @override
  Future<void> setShuffle(bool shuffle) async =>
      emit((s) => s.copyWith(shuffle: shuffle));

  @override
  Future<void> setLoop(Loop loop) async => emit((s) => s.copyWith(loop: loop));

  /// Setters this fake does not model are accepted and recorded, so a
  /// page that sets something on load does not fail the scene.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (invocation.isMethod && name.contains('"set')) {
      calls.add(name);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  void close() {
    _fft.close();
    _pcm.close();
    _loudness.close();
    for (final c in _taps.values) {
      c.close();
    }
  }
}

/// A queue entry the showcase knows: its track and its cover (PNG bytes,
/// or null for none).
class ShowcaseEntry {
  const ShowcaseEntry(this.track, {this.cover});

  final ShowcaseTrack track;
  final Uint8List? cover;
}

/// The streams of a [ShowcasePlayer]: the queue fake's, the ones the
/// Playback page and its info sheet read, and the spectrum and level
/// taps.
class ShowcaseStream extends QueueFakeStream {
  ShowcaseStream(this._p) : super(_p);

  final ShowcasePlayer _p;

  Stream<T> _s<T>(T Function(PlayerState s) pick) =>
      _p.watch((p) => pick(p.state));

  @override
  Stream<double> get rate => _s((s) => s.rate);
  @override
  Stream<double> get volume => _s((s) => s.volume);
  @override
  Stream<double> get volumeMax => _s((s) => s.volumeMax);
  @override
  Stream<bool> get seekable => _s((s) => s.seekable);
  @override
  Stream<bool> get shuffle => _s((s) => s.shuffle);
  @override
  Stream<Loop> get loop => _s((s) => s.loop);
  @override
  Stream<Duration?> get abLoopA => _s((s) => s.abLoopA);
  @override
  Stream<Duration?> get abLoopB => _s((s) => s.abLoopB);
  @override
  Stream<int?> get abLoopCount => _s((s) => s.abLoopCount);
  @override
  Stream<int?> get remainingAbLoops => _s((s) => s.remainingAbLoops);
  @override
  Stream<List<Chapter>> get chapters => _s((s) => s.chapters);
  @override
  Stream<int?> get currentChapter => _s((s) => s.currentChapter);
  @override
  Stream<AudioParams> get audioParams => _s((s) => s.audioParams);
  @override
  Stream<AudioParams> get audioOutParams => _s((s) => s.audioOutParams);
  @override
  Stream<String> get fileFormat => _s((s) => s.fileFormat);
  @override
  Stream<double?> get audioBitrate => _s((s) => s.audioBitrate);
  @override
  Stream<double> get volumeGain => _s((s) => s.volumeGain);
  @override
  Stream<String> get streamPath => _s((s) => s.streamPath);
  @override
  Stream<String> get path => _s((s) => s.path);
  @override
  Stream<String> get filename => _s((s) => s.filename);
  @override
  Stream<int> get fileSize => _s((s) => s.fileSize);
  @override
  Stream<Duration> get audioPts => _s((s) => s.audioPts);
  @override
  Stream<Duration> get timeRemaining => _s((s) => s.timeRemaining);
  @override
  Stream<bool> get partiallySeekable => _s((s) => s.partiallySeekable);
  @override
  Stream<bool> get eofReached => _s((s) => s.eofReached);
  @override
  Stream<FftFrame> get fft => _p._fft.stream;
  @override
  Stream<PcmFrame> get pcm => _p._pcm.stream;
  @override
  Stream<PcmFrame> tap(
    AudioFilter filter, {
    int instance = 0,
    required TapSide side,
  }) => _p._tap(filter, instance, side);
  @override
  Stream<Loudness> get loudnessMeter => _p._loudness.stream;
  @override
  Stream<SpectrumSettings> get spectrum => Stream.value(_p.state.spectrum);
  @override
  Stream<List<AudioEffect>> get audioEffects => _s((s) => s.audioEffects);
}
