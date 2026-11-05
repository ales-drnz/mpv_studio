import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_painter.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The waveform marks what the engine holds in its cache, on a network
/// source; a local file is all there and gets no mark.
void main() {
  WaveformPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<WaveformPainter>()
      .single;

  const ranges = [
    CacheRange(Duration(minutes: 1, seconds: 50), Duration(minutes: 3)),
  ];

  testWidgets('a network source shows its cached ranges', (tester) async {
    final player = playingTrack();
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    player.emit(
      (s) => s.copyWith(
        demuxerViaNetwork: true,
        demuxerCacheState: const DemuxerCacheState(seekableRanges: ranges),
      ),
    );
    await tester.pump();
    expect(painter(tester).cached, ranges);
  });

  testWidgets('a local file shows none', (tester) async {
    final player = playingTrack();
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    player.emit(
      (s) => s.copyWith(
        demuxerCacheState: const DemuxerCacheState(seekableRanges: ranges),
      ),
    );
    await tester.pump();
    expect(painter(tester).cached, isEmpty);
  });
}
