import 'package:flutter_test/flutter_test.dart';

import '../now_playing/playback_fake.dart';
import '../now_playing/playback_harness.dart';
import '../support/layout_harness.dart';

/// On a wide window Track info opens as a report: its sections side by
/// side in a wider dialog, where one narrow column had to scroll.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> open(WidgetTester tester, String size) async {
    await pumpPlayback(tester, playingTrack(), size: studioSize(size));
    await tester.tap(find.byTooltip('Track and playback info'));
    await tester.pumpAndSettle();
  }

  testWidgets('a wide window shows the sections in columns', (tester) async {
    await open(tester, '1920x1080');
    final source = tester.getRect(find.text('Source').last);
    final stream = tester.getRect(find.text('Stream').last);
    expect(stream.left, greaterThan(source.left + 300));
  });

  testWidgets('a laptop window shows two', (tester) async {
    await open(tester, '1024x700');
    final source = tester.getRect(find.text('Source').last);
    final stream = tester.getRect(find.text('Stream').last);
    expect(stream.left, greaterThan(source.left + 300));
  });

  testWidgets('a tablet sheet keeps one column', (tester) async {
    await open(tester, '800x1280');
    final source = tester.getRect(find.text('Source').last);
    final stream = tester.getRect(find.text('Stream').last);
    expect(stream.left, source.left);
  });
}
