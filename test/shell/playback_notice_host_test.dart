import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/shell/playback_notice_host.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

/// Opening the Console clears its badge without rebuilding the badge in
/// the middle of the shell's build.
void main() {
  testWidgets('switching to the Console clears the badge after the frame', (
    tester,
  ) async {
    final errors = StreamController<PlayerError>.broadcast();
    final issues = PlaybackIssues(
      errors: errors.stream,
      endFile: const Stream.empty(),
      playlist: const Stream.empty(),
      loaded: const Stream.empty(),
    );
    addTearDown(issues.dispose);
    addTearDown(errors.close);

    // An mpv error line, then the frame that shows its count.
    Future<void> logError() async {
      errors.add(
        const LogError(prefix: 'ffmpeg', level: LogLevel.error, text: 'bad'),
      );
      await tester.pump();
      await tester.pump();
    }

    var console = false;
    late StateSetter setShell;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setShell = setState;
            return PlaybackNoticeHost(
              issues: issues,
              consoleVisible: console,
              onShowLog: () {},
              // The Console's navigation badge.
              child: ValueListenableBuilder<int>(
                valueListenable: issues.unseenLogErrors,
                builder: (context, count, _) => Text('badge $count'),
              ),
            );
          },
        ),
      ),
    );

    await logError();
    expect(find.text('badge 1'), findsOneWidget);

    setShell(() => console = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(find.text('badge 0'), findsOneWidget);

    // While the Console shows, new errors are seen at once.
    await logError();
    expect(find.text('badge 0'), findsOneWidget);

    setShell(() => console = false);
    await tester.pump();
    await tester.pump();
    await logError();
    expect(find.text('badge 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
