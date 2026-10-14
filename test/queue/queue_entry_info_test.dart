import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show Media;
import 'package:mpv_studio/features/queue/queue_details.dart';
import 'package:mpv_studio/features/queue/widgets/queue_entry_info.dart';
import 'package:mpv_studio/ui/tokens.dart';

import '../support/fake_player.dart';
import '../support/layout_harness.dart';

const _media = Media('https://example.test/missing.flac');

/// The colour of the selectable value that reads [text].
Color? _colorOf(WidgetTester tester, String text) => tester
    .widget<SelectableText>(
      find.byWidgetPredicate((w) => w is SelectableText && w.data == text),
    )
    .style!
    .color;

Future<void> _pump(
  WidgetTester tester, {
  required bool current,
  EntryOutcome? outcome,
}) => pumpStudio(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      child: QueueEntryInfo(
        index: 0,
        count: 1,
        media: _media,
        info: QueueRowInfo.of(_media, null),
        outcome: outcome,
        current: current,
        player: FakePlayer(),
        onPlay: () {},
        onCopy: () {},
        onRemove: () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('the current entry that failed to open reads Failed', (
    tester,
  ) async {
    await _pump(
      tester,
      current: true,
      outcome: const EntryOutcome(EntryEnd.failed, message: 'No such file'),
    );
    expect(find.text('Failed: No such file'), findsOneWidget);
    expect(find.text('Now playing'), findsNothing);
    expect(_colorOf(tester, 'Failed: No such file'), Tokens.red);
  });

  testWidgets('the current entry that plays reads Now playing', (tester) async {
    await _pump(tester, current: true);
    expect(find.text('Now playing'), findsOneWidget);
    expect(_colorOf(tester, 'Now playing'), Tokens.fg);
  });
}
