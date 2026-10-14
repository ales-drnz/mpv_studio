import 'dart:async';
import 'dart:typed_data';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../now_playing/playback_fake.dart';
import 'showcase_track.dart';

/// A [PlaybackFake] that plays: [advance] moves the playhead on in scene
/// time (looping between A and B like mpv), seeks land, and the spectrum
/// and level taps carry what [ShowcaseSong] sounds like at the playhead.
class ShowcasePlayer extends PlaybackFake {
  ShowcasePlayer(PlayerState super.initial) : _playhead = initial.position;

  final _fft = StreamController<FftFrame>.broadcast();
  final _pcm = StreamController<PcmFrame>.broadcast();

  late final ShowcaseStream _stream = ShowcaseStream(this);

  @override
  PlayerStream get stream => _stream;

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

  /// The song playing, with its cover, at [at], the analysers running.
  factory ShowcasePlayer.playing({
    required Duration at,
    required Uint8List cover,
  }) {
    final player = ShowcasePlayer(
      PlayerState(
        playlist: const Playlist([
          Media(
            'file:///music/Juniper Avenue/Night Ferry/03 Harbour Lights.flac',
            extras: {
              'title': ShowcaseSong.title,
              'artist': ShowcaseSong.artist,
              'album': ShowcaseSong.album,
            },
          ),
          Media(
            'file:///music/Juniper Avenue/Night Ferry/04 Lowtide.flac',
            extras: {'title': 'Lowtide', 'artist': ShowcaseSong.artist},
          ),
        ]),
        playWhenReady: true,
        playing: true,
        duration: ShowcaseSong.length,
        position: at,
        seekable: true,
        volume: 80,
        volumeMax: 130,
        chapters: ShowcaseSong.chapters,
        currentChapter: _chapterAt(at),
        coverArt: CoverArt(bytes: cover, mimeType: 'image/png'),
        audioParams: const AudioParams(
          format: Format.s16,
          sampleRate: 44100,
          channelCount: 2,
          hrChannels: 'stereo',
          codec: 'FLAC',
        ),
        audioOutParams: const AudioParams(
          format: Format.float32,
          sampleRate: 48000,
          channelCount: 2,
          hrChannels: 'stereo',
        ),
        fileFormat: 'flac',
        audioBitrate: 968000.0,
        streamPath:
            'file:///music/Juniper Avenue/Night Ferry/03 Harbour Lights.flac',
        path: '/music/Juniper Avenue/Night Ferry/03 Harbour Lights.flac',
        filename: '03 Harbour Lights.flac',
        fileSize: 35321856,
      ),
    );
    player
      ..playbackState = MpvPlaybackState.playing
      ..waveform = ShowcaseSong.waveform()
      ..loudnessScan = ShowcaseSong.loudness;
    return player;
  }

  static int? _chapterAt(Duration at) {
    int? index;
    for (var i = 0; i < ShowcaseSong.chapters.length; i++) {
      if (ShowcaseSong.chapters[i].time <= at) index = i;
    }
    return index;
  }

  /// Plays on by [dt] of scene time, then reports the position and hands
  /// the analysers what the song sounds like there.
  void advance(Duration dt) {
    final s = state;
    var pos = _playhead;
    if (s.playWhenReady) {
      pos += dt * s.rate;
      final a = s.abLoopA;
      final b = s.abLoopB;
      if (a != null && b != null && pos >= b) pos = a + (pos - b);
      if (pos > s.duration) pos = s.duration;
    }
    _playhead = pos;
    // On the playhead's grid: the same stretch of the song updates on the
    // same frames, so a scene that ends where it began looks the same
    // there. The position is reported on every frame even when it holds:
    // the waveform runs its playhead on from each report by the wall
    // clock, which a test must not show.
    final every = updateInterval;
    final bucket = every == null
        ? -1
        : pos.inMicroseconds ~/ every.inMicroseconds;
    _report(every == null ? pos : every * bucket);
    final t = pos.inMicroseconds / 1e6;
    if (every == null || bucket != _lastBucket) {
      _lastBucket = bucket;
      _fft.add(ShowcaseSong.spectrum(t));
    }
    _pcm.add(ShowcaseSong.levels(t));
  }

  void _report(Duration pos) {
    emit(
      (s) => s.copyWith(
        position: pos,
        audioPts: pos,
        timeRemaining: s.duration - pos,
        currentChapter: _chapterAt(pos),
      ),
    );
  }

  @override
  Future<void> seek(
    Duration position, {
    bool relative = false,
    bool exact = false,
  }) async {
    await super.seek(position, relative: relative, exact: exact);
    var to = relative ? _playhead + position : position;
    final grid = seekGrid;
    if (grid != null && grid > Duration.zero) {
      to = grid * (to.inMicroseconds / grid.inMicroseconds).round();
    }
    final end = state.duration;
    _playhead = to < Duration.zero ? Duration.zero : (to > end ? end : to);
    _report(_playhead);
  }

  void close() {
    _fft.close();
    _pcm.close();
  }
}

/// The streams of a [ShowcasePlayer]: the Playback fake's, with the
/// spectrum and level taps live.
class ShowcaseStream extends PlaybackFakeStream {
  ShowcaseStream(this._player) : super(_player);

  final ShowcasePlayer _player;

  @override
  Stream<FftFrame> get fft => _player._fft.stream;

  @override
  Stream<PcmFrame> get pcm => _player._pcm.stream;
}
