import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// Repeat says which of its three states it is in, not only its name.
void main() {
  for (final (loop, value) in [
    (Loop.off, 'off'),
    (Loop.file, 'this track'),
    (Loop.playlist, 'the queue'),
  ]) {
    testWidgets('Repeat reads "$value"', (tester) async {
      final semantics = tester.ensureSemantics();
      final player = playingTrack()..emit((s) => s.copyWith(loop: loop));
      await pumpPlayback(tester, player, size: studioSize('1440x900'));
      final node = tester.getSemantics(find.bySemanticsLabel('Repeat'));
      expect(node.getSemanticsData().value, value);
      semantics.dispose();
    });
  }
}
