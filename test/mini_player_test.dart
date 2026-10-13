import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/theme.dart';

import 'now_playing/playback_fake.dart';
import 'support/fake_player.dart';

const _queue = Playlist([
  Media(
    'https://example.test/one.flac',
    extras: {'title': 'Blue Train', 'artist': 'John Coltrane'},
  ),
  Media('https://example.test/two.flac'),
]);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  InputMode input = InputMode.pointer,
}) async {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => LayoutScope(inputMode: input, child: child!),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
  await tester.pump();
}

/// Lets a toast's timer run out, so no timer is left pending.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  late FakePlayer player;

  setUp(() {
    player = FakePlayer(
      const PlayerState(
        playlist: _queue,
        duration: Duration(minutes: 4),
        position: Duration(minutes: 1),
      ),
    );
  });

  testWidgets('shows the current track from the queue extras', (tester) async {
    await _pump(tester, MiniPlayer(player: player));
    expect(find.text('Blue Train'), findsOneWidget);
    expect(find.text('John Coltrane'), findsOneWidget);
  });

  testWidgets('play and pause follow playWhenReady', (tester) async {
    await _pump(tester, MiniPlayer(player: player));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(player.calls, ['play']);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(player.calls, ['play', 'pause']);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('next skips to the next entry', (tester) async {
    await _pump(tester, MiniPlayer(player: player));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    expect(player.calls, ['next']);
  });

  testWidgets('the bar has previous; the phone bar leaves it to swipes', (
    tester,
  ) async {
    await _pump(tester, MiniPlayer(player: player));
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    expect(player.calls, ['previous']);

    await _pump(
      tester,
      MiniPlayer(player: player, variant: MiniPlayerVariant.compact),
    );
    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
  });

  testWidgets('next at the end of the queue says so', (tester) async {
    final fake = playingTrack()..nextResult = false;
    await _pump(tester, MiniPlayer(player: fake));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    expect(find.text('End of queue'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('on touch, swipes skip and open Playback', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      MiniPlayer(
        player: player,
        variant: MiniPlayerVariant.compact,
        onOpen: () => opened++,
      ),
      input: InputMode.touch,
    );
    final info = find.byKey(const ValueKey('mini-info'));
    await tester.fling(info, const Offset(-160, 0), 1200);
    await tester.pumpAndSettle();
    expect(player.calls, ['next']);
    await tester.fling(info, const Offset(160, 0), 1200);
    await tester.pumpAndSettle();
    expect(player.calls, ['next', 'previous']);
    await tester.fling(info, const Offset(0, -80), 1200);
    await tester.pumpAndSettle();
    expect(opened, 1);
    // A slow drag is not a swipe.
    await tester.timedDrag(
      info,
      const Offset(-60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(player.calls, ['next', 'previous']);
  });

  testWidgets('a right-click opens the menu', (tester) async {
    var opened = 0;
    await _pump(tester, MiniPlayer(player: player, onOpen: () => opened++));
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('mini-info'))),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Next track'), findsOneWidget);
    await tester.tap(find.text('Open Playback'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('the cover and title open Playback on tap', (tester) async {
    var opened = 0;
    await _pump(tester, MiniPlayer(player: player, onOpen: () => opened++));
    await tester.tap(find.text('Blue Train'));
    expect(opened, 1);
    expect(find.byTooltip('Open Playback'), findsOneWidget);
  });

  testWidgets('tapping the progress bar seeks there', (tester) async {
    await _pump(tester, MiniPlayer(player: player));
    final bar = find.byKey(const ValueKey('mini-progress'));
    final box = tester.getRect(bar);
    await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
    // A quarter of four minutes.
    expect(player.calls, ['seek 60000']);
  });

  testWidgets('on touch the progress bar only shows the progress', (
    tester,
  ) async {
    await _pump(tester, MiniPlayer(player: player), input: InputMode.touch);
    final box = tester.getRect(find.byKey(const ValueKey('mini-progress')));
    await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
    await tester.pump();
    expect(player.calls, isEmpty);
  });

  testWidgets('a spinner rings the button while loading or buffering', (
    tester,
  ) async {
    await _pump(tester, MiniPlayer(player: player));
    final ring = find.byKey(const ValueKey('mini-waiting'));
    expect(ring, findsNothing);

    player.emitExtra((p) => p.playbackState = MpvPlaybackState.loading);
    await tester.pump();
    expect(ring, findsOneWidget);
    expect(find.byTooltip('Play (Loading)'), findsOneWidget);

    player.emitExtra((p) => p.playbackState = MpvPlaybackState.buffering);
    await tester.pump();
    expect(ring, findsOneWidget);

    player.emitExtra((p) => p.playbackState = MpvPlaybackState.playing);
    await tester.pump();
    expect(ring, findsNothing);

    player.emit((s) => s.copyWith(seeking: true));
    await tester.pump();
    expect(ring, findsOneWidget);
    expect(find.byTooltip('Play (Seeking)'), findsOneWidget);
  });

  testWidgets('controls carry tooltips and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    await _pump(tester, MiniPlayer(player: player, rack: rack));

    expect(find.byTooltip('Next'), findsOneWidget);
    expect(find.byTooltip('Previous'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('No effects to bypass'), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    expect(find.bySemanticsLabel('Seek'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Bypass FX')),
      matchesSemantics(
        label: 'Bypass FX',
        isButton: true,
        hasEnabledState: true,
        hasToggledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the FX toggle bypasses the chain and restores it', (
    tester,
  ) async {
    player.emit((s) => s.copyWith(audioEffects: const [BassEffect(gain: 5)]));
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    await _pump(tester, MiniPlayer(player: player, rack: rack));

    expect(find.text('FX'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('FX'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(rack.bypass, isTrue);
    expect(player.state.audioEffects.single.enabled, isFalse);
    expect(find.text('Dry'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Dry'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(rack.bypass, isFalse);
    expect(player.state.audioEffects.single.enabled, isTrue);
    expect(find.text('FX'), findsOneWidget);
  });

  testWidgets('the FX toggle ignores the loudness meter and keeps it on', (
    tester,
  ) async {
    player.emit((s) => s.copyWith(audioEffects: [kMeterStage]));
    final rack = RackController(PlayerEffectsEngine(player));
    addTearDown(rack.dispose);
    await _pump(tester, MiniPlayer(player: player, rack: rack));
    expect(find.byTooltip('No effects to bypass'), findsOneWidget);

    player.emit(
      (s) => s.copyWith(audioEffects: [const BassEffect(gain: 5), kMeterStage]),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('FX'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(rack.bypass, isTrue);
    expect(player.state.audioEffects, hasLength(2));
    expect(player.state.audioEffects.first.enabled, isFalse);
    expect(player.state.audioEffects.last.enabled, isTrue);
  });

  group('the bar fits the rail and sidebar widths', () {
    for (final width in [512.0, 600.0, 616.0]) {
      for (final input in InputMode.values) {
        for (final (name, length) in [
          ('4-minute', const Duration(minutes: 4)),
          ('hour-long', const Duration(hours: 1, minutes: 2, seconds: 3)),
        ]) {
          testWidgets('$width wide, ${input.name}, $name times, a rack', (
            tester,
          ) async {
            player.emit(
              (s) => s.copyWith(
                duration: length,
                position: length - const Duration(seconds: 1),
                audioEffects: const [BassEffect(gain: 5)],
              ),
            );
            final rack = RackController(PlayerEffectsEngine(player));
            addTearDown(rack.dispose);
            await _pump(
              tester,
              SizedBox(
                width: width,
                child: MiniPlayer(player: player, rack: rack),
              ),
              input: input,
            );
            expect(tester.takeException(), isNull);
            expect(find.byTooltip('Next'), findsOneWidget);
            expect(find.bySemanticsLabel('Bypass FX'), findsOneWidget);
          });
        }
      }
    }

    testWidgets('a roomy bar shows the times and the FX label', (tester) async {
      final rack = RackController(PlayerEffectsEngine(player));
      addTearDown(rack.dispose);
      await _pump(tester, MiniPlayer(player: player, rack: rack));
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('4:00'), findsOneWidget);
      expect(find.text('FX'), findsOneWidget);
    });

    testWidgets('a narrow bar keeps the progress and drops the labels', (
      tester,
    ) async {
      player.emit(
        (s) => s.copyWith(duration: const Duration(hours: 1, minutes: 2)),
      );
      final rack = RackController(PlayerEffectsEngine(player));
      addTearDown(rack.dispose);
      await _pump(
        tester,
        SizedBox(
          width: 512,
          child: MiniPlayer(player: player, rack: rack),
        ),
      );
      expect(find.byKey(const ValueKey('mini-progress')), findsOneWidget);
      expect(find.text('1:02:00'), findsNothing);
      expect(find.text('FX'), findsNothing);
    });
  });
}
