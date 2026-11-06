import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

ServerTrack _t(String id, String title) => ServerTrack(
  id: id,
  title: title,
  artist: 'Lantern Coast',
  album: 'Harbour Lights',
  duration: const Duration(minutes: 3),
);

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('a search keeps the results on screen while it loads', (
    tester,
  ) async {
    final server = FakeServer(
      connected: true,
      tracks: [_t('1', 'Amber'), _t('2', 'Low Tide'), _t('3', 'Amber Road')],
    );
    await pumpStudio(
      tester,
      streamView(
        player: StreamPlayer(),
        jellyfin: server,
        tab: StreamTab.jellyfin,
      ),
      size: const Size(1440, 900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Low Tide'), findsOneWidget);
    server.trackGate = Completer();
    await tester.enterText(find.byType(TextField).first, 'Amb');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Low Tide'), findsOneWidget, reason: 'still on screen');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    server.trackGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Low Tide'), findsNothing);
    expect(find.text('Amber Road'), findsOneWidget);
  });

  testWidgets('an expired session keeps the server address', (tester) async {
    final server = FakeServer(
      connected: true,
      host: 'https://jf.home.test',
      fetchError: FakeAuthError(),
    );
    await pumpStudio(
      tester,
      streamView(
        player: StreamPlayer(),
        jellyfin: server,
        tab: StreamTab.jellyfin,
      ),
      size: const Size(1440, 900),
    );
    await tester.pumpAndSettle();
    expect(find.text('The session expired. Sign in again.'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.map((f) => f.controller?.text),
      contains('https://jf.home.test'),
    );
  });
}
