import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

void main() {
  setUpAll(loadStudioFonts);

  final tree = {
    '': const [
      SambaEntry(name: 'Jazz', isDirectory: true),
      SambaEntry(name: 'Rock', isDirectory: true),
    ],
    'Jazz': const [SambaEntry(name: 'blue.flac', isDirectory: false)],
    'Rock': const [SambaEntry(name: 'loud.mp3', isDirectory: false)],
  };

  Future<FakeShare> pumpSaved(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'samba.host': 'nas.local',
      'samba.share': 'Music',
      'samba.user': 'alex',
      'samba.pass': 'secret',
    });
    final share = FakeShare(tree);
    await pumpAt(
      tester,
      Scaffold(
        body: SambaTab(
          actions: actionsFor(StreamPlayer()),
          connector: (_) async => share,
        ),
      ),
      '1440x900',
    );
    return share;
  }

  testWidgets('disconnecting forgets the login even on a dead connection', (
    tester,
  ) async {
    final share = await pumpSaved(tester);
    expect(find.text('Jazz'), findsOneWidget);
    share.disconnectError = Exception('connection reset');
    await tester.tap(find.byTooltip('Disconnect from the share'));
    await tester.pumpAndSettle();
    expect(share.disconnected, isTrue);
    expect(find.text('Connect to Samba'), findsOneWidget);
    expect(await SambaLogin.load(), isNull);
  });

  testWidgets('a folder that loads late does not replace a newer one', (
    tester,
  ) async {
    final share = await pumpSaved(tester);
    final slow = share.gates['Jazz'] = Completer<void>();
    await tester.tap(find.text('Jazz'));
    await tester.pump();
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Music/Rock'), findsOneWidget);

    slow.complete();
    await tester.pumpAndSettle();
    expect(find.text('Music/Rock'), findsOneWidget);
    expect(find.text('loud'), findsOneWidget);
    expect(find.text('blue'), findsNothing);
  });
}
