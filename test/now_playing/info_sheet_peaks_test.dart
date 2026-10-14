import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The scan's peaks are linear amplitudes: the info shows them in
/// decibels, the true peak as dBTP and the sample peak as dBFS.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('peaks read in dBTP and dBFS', (tester) async {
    final player = playingTrack()
      ..loudnessScan = const LoudnessScan(
        state: LoudnessScanState.ready,
        integrated: -9.8,
        range: 6.4,
        samplePeak: 0.933,
        truePeak: 0.966,
      );
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    await tester.tap(find.byTooltip('Track and playback info'));
    await tester.pumpAndSettle();
    expect(find.text('-0.3 dBTP'), findsOneWidget);
    expect(find.text('-0.6 dBFS'), findsOneWidget);
  });
}
