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

  testWidgets('a new request moves the live page, a rebuild does not', (
    tester,
  ) async {
    final player = StreamPlayer();
    int shown() =>
        tester.widget<IndexedStack>(find.byKey(StreamView.tabsKey)).index!;
    Future<void> show(StreamTab tab, Object? request) async {
      await pumpAt(
        tester,
        streamView(player: player, tab: tab, tabRequest: request),
        '1440x900',
      );
      await tester.pumpAndSettle();
    }

    await show(StreamTab.lab, null);
    expect(shown(), StreamTab.lab.index);

    final first = Object();
    await show(StreamTab.jellyfin, first);
    expect(shown(), StreamTab.jellyfin.index);

    // The user moves on; a rebuild with the same request keeps their tab.
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await show(StreamTab.jellyfin, first);
    expect(shown(), StreamTab.lab.index);

    // Asking for the same tab again is a new request and moves the page.
    await show(StreamTab.jellyfin, Object());
    expect(shown(), StreamTab.jellyfin.index);
  });
}
