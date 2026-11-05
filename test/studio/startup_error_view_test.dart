import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/studio/startup_error_view.dart';

/// A browser that cannot run libmpv gets its reason and where the demo
/// runs, and no Try again, which could only fail the same way.
void main() {
  testWidgets('an unsupported browser gets the reason, not a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupErrorView(
          error: 'SharedArrayBuffer is not available',
          unsupported: true,
        ),
      ),
    );
    expect(find.text('This browser cannot run the audio engine'), findsOne);
    expect(find.textContaining('SharedArrayBuffer'), findsOneWidget);
    expect(find.textContaining('Chrome, Edge or Firefox'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('any other failure offers to try again', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupErrorView(error: 'boom', onRetry: () => retried++),
      ),
    );
    expect(find.text('The audio engine did not start'), findsOne);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });
}
