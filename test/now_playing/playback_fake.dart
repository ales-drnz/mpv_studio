import 'dart:typed_data';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../support/fake_player.dart';

/// A [FakePlayer] with what the Playback page reads and calls: the A-B
/// loop, chapters, speed, volume and the transport modes. [nextResult]
/// and [previousResult] are what next and previous answer (false at an
/// end of the queue).
class PlaybackFake extends FakePlayer {
  PlaybackFake([super.initial]);

  bool nextResult = true;
  bool previousResult = true;

  @override
  late final PlayerStream stream = PlaybackFakeStream(this);

  @override
  Future<bool> next({bool force = false}) async {
    calls.add(force ? 'next force' : 'next');
    return nextResult;
  }

  @override
  Future<bool> previous({bool force = false}) async {
    calls.add(force ? 'previous force' : 'previous');
    return previousResult;
  }

  @override
  Future<void> setAbLoopA(Duration? position) async {
    calls.add('setAbLoopA ${position?.inMilliseconds}');
    emit((s) => s.copyWith(abLoopA: position));
  }

  @override
  Future<void> setAbLoopB(Duration? position) async {
    calls.add('setAbLoopB ${position?.inMilliseconds}');
    emit((s) => s.copyWith(abLoopB: position));
  }

  @override
  Future<void> setAbLoopCount(int? count) async {
    calls.add('setAbLoopCount $count');
    emit((s) => s.copyWith(abLoopCount: count));
  }

  @override
  Future<void> setChapter(int index) async {
    calls.add('setChapter $index');
    emit((s) => s.copyWith(currentChapter: index));
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate $rate');
    emit((s) => s.copyWith(rate: rate));
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume ${volume.round()}');
    emit((s) => s.copyWith(volume: volume));
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> jump(int index) async => calls.add('jump $index');
}

/// The streams of a [PlaybackFake]: the shared fake's, plus the ones the
/// Playback page reads. The analysers (PCM, FFT) never emit.
class PlaybackFakeStream extends FakePlayerStream {
  PlaybackFakeStream(this._fake) : super(_fake);

  final PlaybackFake _fake;

  Stream<T> _s<T>(T Function(PlayerState s) pick) =>
      _fake.watch((p) => pick(p.state));

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
  Stream<Map<String, String>> get chapterMetadata =>
      _s((s) => s.chapterMetadata);
  @override
  Stream<void> get seekCompleted => const Stream.empty();
  @override
  Stream<PcmFrame> get pcm => const Stream.empty();
  @override
  Stream<FftFrame> get fft => const Stream.empty();
}

/// A track with a title, an artist, a waveform and two chapters, a third
/// of the way in.
PlaybackFake playingTrack() {
  final fake = PlaybackFake(
    const PlayerState(
      playlist: Playlist([
        Media(
          'https://example.test/one.flac',
          extras: {
            'title': 'Blue in Green',
            'artist': 'Bill Evans Trio',
            'album': 'Portrait in Jazz',
          },
        ),
        Media('https://example.test/two.flac'),
      ]),
      duration: Duration(minutes: 5, seconds: 37),
      position: Duration(minutes: 2, seconds: 3),
      seekable: true,
      volume: 80,
      volumeMax: 130,
      chapters: [
        Chapter(time: Duration.zero, title: 'Intro'),
        Chapter(time: Duration(minutes: 1, seconds: 40), title: 'Theme'),
        Chapter(time: Duration(minutes: 4), title: 'Coda'),
      ],
      currentChapter: 1,
    ),
  );
  fake.waveform = demoWaveform(const Duration(minutes: 5, seconds: 37));
  return fake;
}

/// A deterministic envelope of [duration]: a slow swell with a beat.
WaveformData demoWaveform(Duration duration) {
  const n = 400;
  final min = Float32List(n);
  final max = Float32List(n);
  final rms = Float32List(n);
  for (var i = 0; i < n; i++) {
    final swell = 0.35 + 0.45 * (i / n);
    final beat = (i % 8 == 0) ? 0.2 : 0.0;
    final peak = (swell + beat).clamp(0.0, 0.98);
    max[i] = peak;
    min[i] = -peak * 0.9;
    rms[i] = peak * 0.5;
  }
  return WaveformData(
    duration: duration,
    min: min,
    max: max,
    rms: rms,
    filled: Uint8List.fromList(List.filled(n, 1)),
  );
}
