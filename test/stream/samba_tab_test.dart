import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/samba/samba_login_store.dart';
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

  late SambaLoginStore store;
  late FakeSecretStore secrets;

  Future<FakeShare> pumpSaved(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'samba.host': 'nas.local',
      'samba.share': 'Music',
      'samba.user': 'alex',
    });
    secrets = FakeSecretStore()..values[SambaLoginStore.passwordKey] = 'secret';
    store = SambaLoginStore(secrets: secrets);
    final share = FakeShare(tree);
    await pumpAt(
      tester,
      Scaffold(
        body: SambaTab(
          actions: actionsFor(StreamPlayer()),
          connector: (_) async => share,
          store: store,
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
    expect(await store.load(), isNull);
    expect(secrets.values, isEmpty);
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

  testWidgets('says when the keychain cannot keep the password', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final failing = SambaLoginStore(secrets: FakeSecretStore(failing: true));
    await pumpAt(
      tester,
      Scaffold(
        body: SambaTab(
          actions: actionsFor(StreamPlayer()),
          connector: (_) async => throw Exception('host down'),
          store: failing,
        ),
      ),
      '360x780',
    );
    expect(find.textContaining('no system keychain'), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Host'), 'nas');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Share'),
      'Music',
    );
    await failing.save(
      const SambaLogin(host: 'nas', share: 'Music', password: 'pw'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Password not saved: no system keychain.'),
      findsOneWidget,
    );
    expectNoOverflow(tester);
  });
}
