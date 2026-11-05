import 'package:flutter_test/flutter_test.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// When no device opens, the engine plays on its null output: the
/// position runs and nothing is heard. Playback says so, and offers to
/// open the output again.
void main() {
  const notice = 'No audio device: playing silently';

  testWidgets('the null output fallback shows a banner', (tester) async {
    final player = playingTrack();
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    expect(find.textContaining(notice), findsNothing);
    player.emit((s) => s.copyWith(currentAo: 'null'));
    await tester.pumpAndSettle();
    expect(find.textContaining(notice), findsOneWidget);
    await tester.tap(find.text('Reopen output'));
    await tester.pump();
    expect(player.calls, contains('reloadAudio'));
  });

  testWidgets('the null driver chosen on purpose shows none', (tester) async {
    final player = playingTrack();
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    player.emit((s) => s.copyWith(currentAo: 'null', audioDriver: 'null'));
    await tester.pumpAndSettle();
    expect(find.textContaining(notice), findsNothing);
  });
}
