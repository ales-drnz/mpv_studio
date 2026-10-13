import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/ui/widgets/chapter_scrubber.dart';

import '../support/layout_harness.dart';

const _chapters = [
  Chapter(time: Duration.zero, title: 'Intro'),
  Chapter(time: Duration(minutes: 1)),
  Chapter(time: Duration(minutes: 3), title: 'Outro'),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? activeTitle,
    ValueChanged<int>? onSeekChapter,
    ValueChanged<Duration>? onSeek,
  }) => pumpStudio(
    tester,
    Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: ChapterScrubber(
            chapters: _chapters,
            position: const Duration(minutes: 1, seconds: 30),
            duration: const Duration(minutes: 4),
            activeTitle: activeTitle,
            onSeekChapter: onSeekChapter,
            onSeek: onSeek,
          ),
        ),
      ),
    ),
  );

  testWidgets('names the active chapter, untitled ones by number', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('the chapter tags override the listed title', (tester) async {
    await pump(tester, activeTitle: 'Verse');
    expect(find.text('Verse'), findsOneWidget);
  });

  testWidgets('dots jump to their chapter, the bar seeks', (tester) async {
    int? chapter;
    Duration? at;
    await pump(
      tester,
      onSeekChapter: (i) => chapter = i,
      onSeek: (d) => at = d,
    );
    await tester.tap(find.bySemanticsLabel('Outro, 3:00'));
    expect(chapter, 2);

    final bar = tester.getRect(find.byType(ChapterScrubber));
    await tester.tapAt(Offset(bar.left + bar.width / 2, bar.bottom - 6));
    expect(at, const Duration(minutes: 2));
  });
}
