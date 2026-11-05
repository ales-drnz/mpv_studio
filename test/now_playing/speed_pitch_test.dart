import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

/// The speed menu leads to pitch, in semitones, beside the speed: the
/// engine moves one without the other.
void main() {
  Future<PlaybackFake> open(WidgetTester tester) async {
    final player = playingTrack();
    await pumpPlayback(tester, player, size: studioSize('1440x900'));
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speed and pitch'));
    await tester.pumpAndSettle();
    return player;
  }

  testWidgets('pitch moves by semitones', (tester) async {
    final player = await open(tester);
    expect(find.text('Pitch'), findsOneWidget);
    expect(find.text('0 st'), findsOneWidget);
    // The pitch slider from the keyboard: one semitone up.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final before = player.calls.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final pitched = player.calls
        .skip(before)
        .where((c) => c.startsWith('setPitch '));
    expect(pitched, ['setPitch 1.0595']);
    expect(find.text('+1 st'), findsOneWidget);
  });

  testWidgets('Keep pitch switches pitch correction', (tester) async {
    final player = await open(tester);
    await tester.tap(find.text('Keep pitch'));
    await tester.pumpAndSettle();
    expect(player.calls, contains('setPitchCorrection false'));
  });
}
