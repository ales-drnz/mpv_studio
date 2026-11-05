import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/pcm_tab.dart';
import 'package:mpv_studio/features/stream/stream_actions.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

/// A live input that holds what it is fed, and holds back the feeder
/// once a quarter of a second waits, as a PcmSource does.
class _FakePcm implements LivePcm {
  final chunks = <Uint8List>[];
  bool aborted = false;
  final _drain = Completer<void>();
  bool stopped = false;

  /// The player let the input go (stop, next, another open).
  void stopFromPlayer() {
    stopped = true;
    if (!_drain.isCompleted) _drain.complete();
  }

  int get _bytes => chunks.fold(0, (n, c) => n + c.lengthInBytes);

  @override
  Duration get buffered =>
      Duration(microseconds: (_bytes / 4 / 48000 * 1e6).round());

  @override
  Future<void> get ready =>
      buffered < PcmTab.ahead ? Future.value() : _drain.future;

  @override
  void add(Uint8List chunk) => chunks.add(chunk);

  @override
  Future<void> close() async {}

  @override
  void abort() {
    aborted = true;
    if (!_drain.isCompleted) _drain.complete();
  }

  @override
  bool get isDone => aborted || stopped;
}

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('Play live opens a stereo input and feeds it ahead', (
    tester,
  ) async {
    final fake = _FakePcm();
    PcmFormat? opened;
    Map<String, Object?>? sent;
    await pumpStudio(
      tester,
      Material(
        child: PcmTab(
          actions: StreamActions(player: StreamPlayer(), guard: unguarded),
          open: (format, {required lowLatency, required extras}) async {
            opened = format;
            sent = extras;
            return fake;
          },
        ),
      ),
    );
    await tester.tap(find.text('Play live'));
    await tester.pump();
    await tester.pump();
    expect(opened?.sampleRate, 48000);
    expect(opened?.channels, 2);
    expect(sent?['title'], 'Live PCM');
    // Fed up to the quarter of a second ahead, then held.
    expect(fake.buffered, greaterThanOrEqualTo(PcmTab.ahead));
    expect(fake.buffered, lessThan(PcmTab.ahead + PcmTab.chunk * 2));
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(fake.aborted, isTrue);
    expect(find.text('Play live'), findsOneWidget);
  });

  testWidgets('a stop from elsewhere puts the tab back to Play live', (
    tester,
  ) async {
    final fake = _FakePcm();
    await pumpStudio(
      tester,
      Material(
        child: PcmTab(
          actions: StreamActions(player: StreamPlayer(), guard: unguarded),
          open: (format, {required lowLatency, required extras}) async => fake,
        ),
      ),
    );
    await tester.tap(find.text('Play live'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);
    fake.stopFromPlayer();
    await tester.pump();
    await tester.pump();
    expect(find.text('Play live'), findsOneWidget);
    expect(fake.aborted, isFalse);
  });

  testWidgets('a tab gone while the input opens stops it', (tester) async {
    final fake = _FakePcm();
    final opening = Completer<LivePcm>();
    await pumpStudio(
      tester,
      Material(
        child: PcmTab(
          actions: StreamActions(player: StreamPlayer(), guard: unguarded),
          open: (format, {required lowLatency, required extras}) =>
              opening.future,
        ),
      ),
    );
    await tester.tap(find.text('Play live'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    opening.complete(fake);
    await tester.pump();
    expect(fake.aborted, isTrue);
  });
}
