import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

/// Every tab of the Stream page lays out without overflow at every size,
/// and on a 360 wide phone with the text 30% larger.
void main() {
  setUpAll(loadStudioFonts);

  FakeServer library() => FakeServer(
    connected: true,
    tracks: const [
      ServerTrack(
        id: '1',
        title: 'A very long song title that will not fit on a phone row',
        artist: 'Somebody with a long name',
        album: 'An album with an even longer name',
        duration: Duration(minutes: 4, seconds: 5),
      ),
    ],
  );

  for (final tab in StreamTab.values) {
    for (final s in studioSizes) {
      testWidgets('${tab.name} at $s', (tester) async {
        await pumpAt(
          tester,
          streamView(player: StreamPlayer(), jellyfin: library(), tab: tab),
          s.name,
        );
        expectNoOverflow(tester, reason: '${tab.name} ${s.name}');
      });
    }

    testWidgets('${tab.name} at 360x780 with text at 130%', (tester) async {
      await pumpAt(
        tester,
        streamView(player: StreamPlayer(), jellyfin: library(), tab: tab),
        '360x780',
        textScale: 1.3,
      );
      expectNoOverflow(tester, reason: tab.name);
    });
  }
}
