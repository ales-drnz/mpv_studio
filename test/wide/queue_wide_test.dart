import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/queue/widgets/queue_now_playing.dart';

import '../queue/queue_fixture.dart';
import '../support/layout_harness.dart';

/// With room for three columns, Queue adds what plays and what comes next
/// beside the list and the details.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('a wide window shows Now playing and Up next', (tester) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(tester, player, details, size: const Size(2560, 1080));
    expect(find.byType(QueueNowPlaying), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    // The entry after the current one, by title.
    expect(
      find.descendant(
        of: find.byType(QueueNowPlaying),
        matching: find.text('Paper Lanterns'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a laptop window does not', (tester) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(tester, player, details, size: const Size(1440, 900));
    expect(find.byType(QueueNowPlaying), findsNothing);
  });

  testWidgets('the header stays put when the first file comes in', (
    tester,
  ) async {
    final (player, details) = emptyQueue();
    await pumpQueue(
      tester,
      player,
      details,
      size: const Size(2560, 1080),
      picked: ['/m/a.flac'],
    );
    final before = tester.getTopLeft(find.text('Queue').first);
    await tester.tap(find.text('Add files').last);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Queue').first), before);
  });
}
