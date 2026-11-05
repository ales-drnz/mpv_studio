import 'package:flutter_test/flutter_test.dart';

import '../stream/stream_fakes.dart';
import '../support/layout_harness.dart';

/// With room for two columns of a card's readable width, the Lab's
/// categories stand in two, where one column of rows ran across the page.
void main() {
  setUpAll(loadStudioFonts);

  testWidgets('a wide window shows the Lab in two columns', (tester) async {
    await pumpAt(tester, streamView(player: StreamPlayer()), '2560x1080');
    final first = tester.getRect(find.text('MP3 reference'));
    final later = tester.getRect(find.text('Lossless and hi-fi'));
    expect(later.left, greaterThan(first.left + 400));
  });

  testWidgets('a small laptop window keeps one column', (tester) async {
    await pumpAt(tester, streamView(player: StreamPlayer()), '1024x700');
    final first = tester.getRect(find.text('MP3 reference'));
    final later = tester.getRect(find.text('Lossless and hi-fi'));
    expect(later.left, first.left);
  });
}
