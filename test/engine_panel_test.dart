import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/engine/engine_page.dart';
import 'package:mpv_studio/features/engine/widgets/analysis_view.dart';
import 'package:mpv_studio/features/engine/widgets/chain_view.dart';
import 'package:mpv_studio/ui/theme.dart';

import 'support/fake_player.dart';

PlayerState _streaming() => PlayerState(
  playWhenReady: true,
  position: const Duration(seconds: 40),
  duration: const Duration(minutes: 4),
  demuxerViaNetwork: true,
  demuxerCacheState: const DemuxerCacheState(
    seekableRanges: [CacheRange(Duration(seconds: 20), Duration(seconds: 75))],
  ),
  bufferDuration: const Duration(seconds: 35),
  cacheSpeed: 1.8e6,
  cache: const CacheSettings(
    secs: Duration(seconds: 60),
    pause: true,
    pauseWait: Duration(seconds: 3),
  ),
  prefetchPlaylist: true,
  playlist: const Playlist([
    Media('https://example.test/a.flac'),
    Media('https://example.test/b.flac', extras: {'title': 'Track B'}),
  ]),
  audioOutputState: AudioOutputState.active,
  currentAo: 'pipewire',
  audioDevice: const Device(name: 'pipewire', description: 'Speakers'),
  audioParams: const AudioParams(
    codecName: 'flac',
    format: Format.s32,
    sampleRate: 96000,
    hrChannels: 'stereo',
  ),
  audioOutParams: const AudioParams(
    format: Format.float32Planar,
    sampleRate: 48000,
    hrChannels: 'stereo',
  ),
  audioEffects: const [
    BassEffect(gain: 4),
    TrebleEffect(enabled: false),
    LoudnormEffect(),
  ],
  mpvVersion: 'mpv v0.41.0+r16',
  ffmpegVersion: '8.1.1',
);

WaveformData _halfWave() {
  const n = 64;
  return WaveformData(
    duration: const Duration(minutes: 4),
    min: Float32List.fromList(List.filled(n, -0.5)),
    max: Float32List.fromList(List.filled(n, 0.5)),
    rms: Float32List.fromList(List.filled(n, 0.3)),
    filled: Uint8List.fromList([for (var i = 0; i < n; i++) i < 20 ? 1 : 0]),
  );
}

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  late FakePlayer player;

  setUp(() {
    player = FakePlayer(_streaming())
      ..playbackState = MpvPlaybackState.buffering
      ..prefetchState = PrefetchState.loading
      ..prefetchCacheDuration = const Duration(seconds: 12)
      ..waveform = _halfWave()
      ..loudnessScan = const LoudnessScan(
        state: LoudnessScanState.scanning,
        progress: 0.4,
      );
  });

  for (final (name, size) in [
    ('phone', const Size(390, 2600)),
    ('desktop', const Size(1280, 1600)),
  ]) {
    testWidgets('shows every panel on a $name', (tester) async {
      await _pump(tester, EnginePanel(player: player), size);

      expect(find.text('Buffering'), findsOneWidget);
      expect(find.text('playWhenReady'), findsOneWidget);
      expect(find.text('mpv v0.41.0+r16'), findsOneWidget);
      expect(find.text('8.1.1'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('35.0 s'), findsOneWidget, reason: 'cached ahead');
      expect(find.text('Next: Track B'), findsOneWidget);
      expect(find.text('12.0 s of 1:00'), findsOneWidget);
      expect(find.text('progressive'), findsOneWidget);
      expect(find.text('scanning'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('pipewire'), findsOneWidget);
      expect(find.text('96 kHz'), findsOneWidget);
      expect(find.text('48 kHz'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(find.text('1 more stage switched off.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('follows the streams live', (tester) async {
    await _pump(tester, EnginePanel(player: player), const Size(1280, 1600));

    player.emitExtra((p) {
      p.playbackState = MpvPlaybackState.playing;
      p.prefetchState = PrefetchState.used;
    });
    player.emit((s) => s.copyWith(pausedForCache: true));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Playing'), findsOneWidget);
    expect(find.text('Paused for cache'), findsOneWidget);
    // The header pill and the legend both name the current state.
    expect(find.text('used'), findsNWidgets(2));
  });

  testWidgets('shows the saved chain while the FX bypass is on', (
    tester,
  ) async {
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    await _pump(
      tester,
      EnginePanel(player: player, rack: rack),
      const Size(1280, 1600),
    );

    await tester.runAsync(() async {
      rack.setBypass(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Bypass'), findsOneWidget);
    expect(
      find.text('Bypassed: the audio plays dry until the bypass is released.'),
      findsOneWidget,
    );
    // The engine plays a switched-off copy of the same shape; the panel
    // still names the stages of the user's chain.
    expect(player.state.audioEffects, hasLength(3));
    expect(player.state.audioEffects.where((e) => e.enabled), isEmpty);
    expect(
      find.text(ChainView.nameOf(const BassEffect(gain: 4))),
      findsOneWidget,
    );
  });

  test('waveform phases', () {
    expect(WaveformPhase.of(null), WaveformPhase.waiting);
    expect(WaveformPhase.of(_halfWave()), WaveformPhase.progressive);
  });
}
