import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_controls.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// A live stream's waveform follows its newest end; scrolled back, a Live
/// chip brings it there again.
void main() {
  WaveformData live(int startSecs, int spanSecs) {
    const n = 400;
    return WaveformData(
      start: Duration(seconds: startSecs),
      duration: Duration(seconds: spanSecs),
      min: Float32List(n)..fillRange(0, n, -0.4),
      max: Float32List(n)..fillRange(0, n, 0.4),
      filled: Uint8List(n)..fillRange(0, n, 1),
      live: true,
    );
  }

  testWidgets('scrolled back, Live follows the end again', (tester) async {
    final player = playingTrack()
      ..waveform = live(100, 120)
      ..emit((s) => s.copyWith(duration: Duration.zero));
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    await tester.pump();
    expect(find.text('Live'), findsNothing);

    // Drag the scrollbar back to the start of the cached window.
    final bar = find.byType(WaveformScrollBar);
    await tester.dragFrom(
      tester.getRect(bar).centerRight - const Offset(4, 0),
      Offset(-tester.getSize(bar).width, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsOneWidget);

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsNothing);
  });
}
