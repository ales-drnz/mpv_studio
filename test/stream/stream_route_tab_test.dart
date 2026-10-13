import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/http_options.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

void main() {
  setUpAll(loadStudioFonts);
  setUp(() {
    HttpOptions.lastUsed = const HttpOptions();
    SharedPreferences.setMockInitialValues({});
  });

  test('a route names its tab', () {
    expect(StreamTab.byName('plex'), StreamTab.plex);
    expect(StreamTab.byName('samba'), StreamTab.samba);
    expect(StreamTab.byName('youtube'), isNull);
    expect(StreamTab.byName(null), isNull);
  });

  testWidgets('a later route moves the live page to its tab', (tester) async {
    final player = StreamPlayer();
    await pumpAt(tester, streamView(player: player), '1440x900');
    TabController tabs() =>
        DefaultTabController.maybeOf(tester.element(find.byType(TabBar))) ??
        tester.widget<TabBar>(find.byType(TabBar)).controller!;
    expect(tabs().index, StreamTab.lab.index);

    await pumpAt(
      tester,
      streamView(player: player, tab: StreamTab.jellyfin),
      '1440x900',
    );
    await tester.pumpAndSettle();
    expect(tabs().index, StreamTab.jellyfin.index);
  });
}
