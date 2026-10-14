import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_controls.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/now_playing/now_playing_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/layout_harness.dart';
import 'playback_fake.dart';
import 'playback_harness.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  PlaybackFake player, {
  Size size = const Size(1440, 900),
  InputMode input = InputMode.pointer,
  ValueNotifier<Set<Media>>? failed,
  VoidCallback? onOpenFiles,
  VoidCallback? onOpenStream,
}) => pumpStudio(
  tester,
  Scaffold(
    body: NowPlayingPage(
      player: player,
      failed: failed,
      onOpenFiles: onOpenFiles ?? () {},
      onOpenStream: onOpenStream ?? () {},
    ),
  ),
  size: size,
  input: input,
);

/// Lets a toast's timer run out, so no timer is left pending.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadStudioFonts);

  group('transport', () {
    testWidgets('next at the end of the queue says so', (tester) async {
      final player = playingTrack()..nextResult = false;
      await _pumpPage(tester, player);
      await tester.tap(find.byTooltip('Next (long press to force)'));
      await tester.pump();
      expect(player.calls, ['next']);
      expect(find.text('End of queue'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('previous at the start of the queue says so', (tester) async {
      final player = playingTrack()..previousResult = false;
      await _pumpPage(tester, player);
      await tester.tap(find.byTooltip('Previous (long press to force)'));
      await tester.pump();
      expect(player.calls, ['previous']);
      expect(find.text('Start of queue'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('a move to another entry shows no toast', (tester) async {
      final player = playingTrack();
      await _pumpPage(tester, player);
      await tester.tap(find.byTooltip('Next (long press to force)'));
      await tester.pump();
      expect(find.text('End of queue'), findsNothing);
    });

    testWidgets('a spinner rings play while seeking or buffering', (
      tester,
    ) async {
      final player = playingTrack();
      await _pumpPage(tester, player);
      expect(find.byKey(const ValueKey('play-busy')), findsNothing);

      player.emit((s) => s.copyWith(seeking: true));
      await tester.pump();
      expect(find.byKey(const ValueKey('play-busy')), findsOneWidget);
      expect(find.text('Seeking'), findsOneWidget);

      player.emit((s) => s.copyWith(seeking: false));
      player.emitExtra((p) => p.playbackState = MpvPlaybackState.buffering);
      await tester.pump();
      expect(find.text('Buffering'), findsOneWidget);

      player.emitExtra((p) => p.playbackState = MpvPlaybackState.paused);
      await tester.pump();
      expect(find.byKey(const ValueKey('play-busy')), findsNothing);
    });
  });

  group('A-B loop', () {
    testWidgets('the chip shows the points and the loops left', (tester) async {
      final player = playingTrack()
        ..emit(
          (s) => s.copyWith(
            abLoopA: const Duration(minutes: 1),
            abLoopB: const Duration(minutes: 1, seconds: 30),
            abLoopCount: 3,
            remainingAbLoops: 2,
          ),
        );
      await _pumpPage(tester, player);
      expect(find.text('1:00 to 1:30'), findsOneWidget);
      expect(find.text('2 left'), findsOneWidget);

      // Once the run is over, the badge falls back to the count.
      player.emit((s) => s.copyWith(remainingAbLoops: null));
      await tester.pump();
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('the chip menu sets points and the loop count', (tester) async {
      final player = playingTrack();
      await _pumpPage(tester, player);

      await tester.tap(find.text('A-B loop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set A at 2:03'));
      await tester.pumpAndSettle();
      expect(player.calls, ['setAbLoopA 123000']);
      expect(find.text('A 2:03'), findsOneWidget);

      await tester.tap(find.text('A 2:03'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat 3 times'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'setAbLoopCount 3');
      await _settleToast(tester);
    });

    testWidgets('the waveform menu sets loop B where it was clicked', (
      tester,
    ) async {
      final player = playingTrack();
      await _pumpPage(tester, player);
      final meter = tester.getRect(
        find.bySemanticsLabel('Waveform and position'),
      );
      await tester.tapAt(
        Offset(meter.left + meter.width / 2, meter.center.dy),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      final setB = find.textContaining('Set loop B at');
      expect(setB, findsOneWidget);
      await tester.tap(setB);
      await tester.pumpAndSettle();
      expect(player.calls.single, startsWith('setAbLoopB '));
      expect(player.state.abLoopB, isNotNull);
      await _settleToast(tester);
    });
  });

  group('chapters', () {
    testWidgets('the title comes from the chapter tags first', (tester) async {
      final player = playingTrack();
      await _pumpPage(tester, player);
      final title = find.byKey(const ValueKey('chapter-title'));
      expect(tester.widget<Text>(title).data, 'Theme');
      expect(find.text('Chapter 2 of 3'), findsOneWidget);

      player.emit(
        (s) => s.copyWith(chapterMetadata: const {'TITLE': 'Main theme'}),
      );
      await tester.pump();
      expect(tester.widget<Text>(title).data, 'Main theme');
    });

    testWidgets('previous and next chapter step the chapter', (tester) async {
      final player = playingTrack();
      await _pumpPage(tester, player);
      await tester.tap(find.byTooltip('Next chapter'));
      await tester.pump();
      expect(player.calls, ['setChapter 2']);
      await tester.tap(find.byTooltip('Previous chapter'));
      await tester.pump();
      expect(player.calls, ['setChapter 2', 'setChapter 1']);
    });

    testWidgets('before the first chapter no chapter is claimed', (
      tester,
    ) async {
      final player = playingTrack()
        ..emit((s) => s.copyWith(currentChapter: null));
      await _pumpPage(tester, player);
      final title = find.byKey(const ValueKey('chapter-title'));
      expect(tester.widget<Text>(title).data, 'Before the first chapter');
      expect(find.text('3 chapters'), findsOneWidget);
      await tester.tap(find.byTooltip('Next chapter'));
      expect(player.calls, ['setChapter 0']);
    });

    testWidgets('a track without chapters shows no chapter line', (
      tester,
    ) async {
      final player = playingTrack()
        ..emit((s) => s.copyWith(chapters: const [], currentChapter: null));
      await _pumpPage(tester, player);
      expect(find.byTooltip('Next chapter'), findsNothing);
    });
  });

  group('states', () {
    testWidgets('nothing playing offers files and Stream', (tester) async {
      var files = 0;
      var stream = 0;
      await _pumpPage(
        tester,
        PlaybackFake(const PlayerState()),
        onOpenFiles: () => files++,
        onOpenStream: () => stream++,
      );
      expect(find.text('Nothing playing'), findsOneWidget);
      expect(find.byType(NowPlayingPage), findsOneWidget);
      await tester.tap(find.text('Open files'));
      await tester.tap(find.text('Go to Stream'));
      expect((files, stream), (1, 1));
      expect(find.bySemanticsLabel('Waveform and position'), findsNothing);
    });

    testWidgets('a queue with nothing on offers to play it', (tester) async {
      final player = PlaybackFake(
        const PlayerState(
          playlist: Playlist([Media('https://example.test/a.flac')], index: -1),
        ),
      );
      await _pumpPage(tester, player);
      await tester.tap(find.text('Play the queue'));
      expect(player.calls, ['jump 0']);
    });

    testWidgets('playing the queue is the one primary, files second', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        PlaybackFake(
          const PlayerState(
            playlist: Playlist([
              Media('https://example.test/a.flac'),
            ], index: -1),
          ),
        ),
      );
      Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget(button('Play the queue')), isA<FilledButton>());
      expect(tester.widget(button('Open files')), isA<OutlinedButton>());
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('an empty queue makes opening files the primary', (
      tester,
    ) async {
      await _pumpPage(tester, PlaybackFake(const PlayerState()));
      expect(find.text('Play the queue'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('Open files'),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed current track shows Retry and Next', (tester) async {
      final player = playingTrack();
      final failed = ValueNotifier<Set<Media>>({
        player.state.playlist.items.first,
      });
      addTearDown(failed.dispose);
      await _pumpPage(tester, player, failed: failed);
      expect(find.text('Could not play "Blue in Green".'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(player.calls, ['jump 0']);

      failed.value = const {};
      await tester.pump();
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('touch', () {
    testWidgets('a double tap on the cover skips 10 s', (tester) async {
      final player = playingTrack();
      await _pumpPage(
        tester,
        player,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      final cover = tester.getRect(find.bySemanticsLabel('No cover art'));
      final right = Offset(cover.right - 10, cover.center.dy);
      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(right);
      await tester.pump();
      expect(player.calls, ['seek +10000']);
      expect(find.text('10 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the cover splits in its own halves, not the page\'s', (
      tester,
    ) async {
      final player = playingTrack();
      await _pumpPage(
        tester,
        player,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      final cover = tester.getRect(find.bySemanticsLabel('No cover art'));
      for (final at in [0.6, 0.4]) {
        final point = Offset(cover.left + cover.width * at, cover.center.dy);
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(point);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(player.calls, ['seek +10000', 'seek -10000']);
    });

    testWidgets('a tap on the waveform seeks once it is not a double tap', (
      tester,
    ) async {
      final player = playingTrack();
      await _pumpPage(
        tester,
        player,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      final meter = tester.getRect(
        find.bySemanticsLabel('Waveform and position'),
      );
      await tester.tapAt(Offset(meter.left + 4, meter.center.dy));
      expect(player.calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(player.calls.single, startsWith('seek '));
    });
  });

  testWidgets('custom painted parts carry semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPage(tester, playingTrack());
    expect(
      tester.getSemantics(find.bySemanticsLabel('Waveform and position')),
      matchesSemantics(
        label: 'Waveform and position',
        value: '2:03 of 5:37',
        increasedValue: '2:08 of 5:37',
        decreasedValue: '1:58 of 5:37',
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Output level'), findsOneWidget);
    expect(find.bySemanticsLabel('Spectrum analyser'), findsOneWidget);
    expect(find.bySemanticsLabel('No cover art'), findsOneWidget);
    expect(find.bySemanticsLabel('Volume'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('every icon button has a tooltip', (tester) async {
    await _pumpPage(tester, playingTrack());
    for (final button in tester.widgetList<InkWell>(
      find.descendant(
        of: find.byType(NowPlayingPage),
        matching: find.byType(InkWell),
      ),
    )) {
      if (button.onTap == null) continue;
      final hasTooltip = find
          .ancestor(of: find.byWidget(button), matching: find.byType(Tooltip))
          .evaluate()
          .isNotEmpty;
      final isTextButton = find
          .ancestor(
            of: find.byWidget(button),
            matching: find.byType(ButtonStyleButton),
          )
          .evaluate()
          .isNotEmpty;
      expect(hasTooltip || isTextButton, isTrue, reason: '$button');
    }
  });

  group('low and tiny windows', () {
    for (final size in const [
      Size(1024, 500),
      Size(1000, 520),
      Size(824, 560),
    ]) {
      testWidgets('the stage with a failure banner fits ${size.width.round()}x'
          '${size.height.round()}', (tester) async {
        final player = playingTrack();
        final failed = ValueNotifier<Set<Media>>({
          player.state.playlist.items.first,
        });
        addTearDown(failed.dispose);
        await _pumpPage(tester, player, size: size, failed: failed);
        expectNoOverflow(tester);
        expect(find.text('Retry'), findsOneWidget);
      });
    }

    for (final size in const [
      Size(330, 270),
      Size(200, 200),
      Size(1300, 300),
    ]) {
      testWidgets('nothing throws at ${size.width.round()}x'
          '${size.height.round()}', (tester) async {
        await _pumpPage(tester, playingTrack(), size: size);
        // A window this small may clip, but never throws.
        final error = tester.takeException();
        expect(error, anyOf(isNull, isA<FlutterError>()));
        expect(error is ArgumentError, isFalse);
      });
    }

    testWidgets('phone landscape has one info button', (tester) async {
      await pumpPlayback(tester, playingTrack(), size: studioSize('780x360'));
      expect(find.byTooltip('Track and playback info'), findsOneWidget);
    });

    testWidgets('a desktop window has one info button', (tester) async {
      await _pumpPage(tester, playingTrack());
      expect(find.byTooltip('Track and playback info'), findsOneWidget);
    });
  });

  testWidgets('the wheel pans a zoomed waveform, not the page', (tester) async {
    await _pumpPage(tester, playingTrack(), size: const Size(412, 600));
    final page = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final meter = tester.getCenter(
      find.bySemanticsLabel('Waveform and position'),
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    Future<void> wheel() async {
      await tester.sendEventToBinding(pointer.hover(meter));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      await tester.pump();
    }

    // The whole track shows: nothing to pan, the page scrolls.
    await wheel();
    expect(page.position.pixels, greaterThan(0));
    page.position.jumpTo(0);
    await tester.pump();

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    final meterNow = tester.getCenter(
      find.bySemanticsLabel('Waveform and position'),
    );
    expect(meterNow, meter);
    await wheel();
    expect(page.position.pixels, 0);
  });

  testWidgets('transport buttons keep 48 dp on a 360 wide phone', (
    tester,
  ) async {
    await pumpPlayback(tester, playingTrack(), size: studioSize('360x780'));
    for (final tip in [
      'Previous (long press to force)',
      'Back 10 s',
      'Forward 10 s',
      'Next (long press to force)',
      'Shuffle off',
      'Stop',
      'Repeat off',
      'Undo last seek',
      'Playback speed',
      'Track and playback info',
    ]) {
      final size = tester.getSize(
        find.descendant(
          of: find.byTooltip(tip),
          matching: find.byType(InkWell),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48), reason: tip);
      expect(size.height, greaterThanOrEqualTo(48), reason: tip);
    }
  });

  group('large text on a small phone', () {
    for (final empty in [false, true]) {
      testWidgets(empty ? 'empty' : 'playing', (tester) async {
        await pumpPlayback(
          tester,
          empty ? PlaybackFake(const PlayerState()) : playingTrack(),
          size: studioSize('360x780'),
          textScale: 1.3,
        );
        expectNoOverflow(tester);
      });
    }

    testWidgets('in landscape', (tester) async {
      await pumpPlayback(
        tester,
        playingTrack(),
        size: studioSize('780x360'),
        textScale: 1.3,
      );
      expectNoOverflow(tester);
    });
  });

  testWidgets('the waveform keeps its state across a change of shape', (
    tester,
  ) async {
    final player = playingTrack();
    await _pumpPage(tester, player);
    bool canZoomOut() =>
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byTooltip('Zoom out'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap !=
        null;

    expect(canZoomOut(), isFalse, reason: 'the whole track shows at first');
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(canZoomOut(), isTrue);

    setStudioView(tester, const Size(780, 360));
    await tester.pumpAndSettle();
    expect(canZoomOut(), isTrue, reason: 'the zoom survived the new layout');
  });

  group('waveform targets', () {
    testWidgets('on touch the scrollbar is a full target and the zoom pill '
        'sits beside it', (tester) async {
      await _pumpPage(
        tester,
        playingTrack(),
        size: const Size(360, 780),
        input: InputMode.touch,
      );
      final bar = find.byType(WaveformScrollBar);
      expect(tester.getSize(bar).height, greaterThanOrEqualTo(48));
      final zoom = tester.getRect(find.byType(WaveformZoomControls));
      final strip = tester.getRect(bar);
      // In the scrollbar's row, not over the waveform.
      expect(zoom.center.dy, closeTo(strip.center.dy, 1));
      expect(zoom.left, greaterThanOrEqualTo(strip.right));
      expectNoOverflow(tester);
    });

    testWidgets('with a pointer the zoom pill floats over the waveform', (
      tester,
    ) async {
      await _pumpPage(tester, playingTrack());
      final bar = tester.getRect(find.byType(WaveformScrollBar));
      final zoom = tester.getRect(find.byType(WaveformZoomControls));
      expect(zoom.bottom, lessThan(bar.top));
      expect(bar.height, 16);
    });
  });
}
