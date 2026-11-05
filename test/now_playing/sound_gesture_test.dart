import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/playback_states.dart';

/// In a browser the sound waits for a click or a key; Playback says so
/// while the engine waits.
void main() {
  testWidgets('a banner while the browser holds the sound', (tester) async {
    final waits = StreamController<bool>();
    addTearDown(waits.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundGestureBanner(stream: waits.stream, initial: true),
        ),
      ),
    );
    expect(find.textContaining('Click or press a key'), findsOneWidget);
    waits.add(false);
    await tester.pump();
    expect(find.textContaining('Click or press a key'), findsNothing);
  });
}
