import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../support/finders.dart';
import '../support/layout_harness.dart';
import 'settings_page_test.dart' show pumpSettings, tapVisible;

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('Restart says when the player is back', (tester) async {
    final h = await pumpSettings(tester);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Restart'));
    expect(h.restarts, 1);
    // The page goes with the restart: the next studio says it.
    expect(PlaybackIssues.takeCarriedOver(), 'Player restarted');
  });

  testWidgets('Reset all says it is done', (tester) async {
    final h = await pumpSettings(tester);
    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, buttonWithText<TileButton>('Reset'));
    await tester.tap(buttonWithText<FilledButton>('Reset'));
    await tester.pumpAndSettle();
    expect(h.restarts, 1);
    expect(PlaybackIssues.takeCarriedOver(), 'Settings reset');
  });
}
