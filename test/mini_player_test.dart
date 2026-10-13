import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/studio/fx_bypass.dart';
import 'package:mpv_studio/ui/theme.dart';

import 'support/fake_player.dart';

const _queue = Playlist([
  Media(
    'https://example.test/one.flac',
    extras: {'title': 'Blue Train', 'artist': 'John Coltrane'},
  ),
  Media('https://example.test/two.flac'),
]);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child)),
    ),
  );
  await tester.pump();
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

  testWidgets('tapping the progress bar seeks there', (tester) async {
    await _pump(tester, MiniPlayer(player: player));
    final bar = find.byKey(const ValueKey('mini-progress'));
    final box = tester.getRect(bar);
    await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
    // A quarter of four minutes.
    expect(player.calls, ['seek 60000']);
  });

  testWidgets('a spinner rings the button while loading or buffering',
      (tester) async {
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
  });

  testWidgets('controls carry tooltips and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final bypass = FxBypass(player);
    addTearDown(bypass.dispose);
    await _pump(tester, MiniPlayer(player: player, bypass: bypass));

    expect(find.byTooltip('Next'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('No effects to bypass'), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
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

  testWidgets('the FX toggle bypasses the chain and restores it',
      (tester) async {
    player.emit(
      (s) => s.copyWith(audioEffects: const [BassEffect(gain: 5)]),
    );
    final bypass = FxBypass(player);
    addTearDown(bypass.dispose);
    await _pump(tester, MiniPlayer(player: player, bypass: bypass));

    expect(find.text('FX'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('FX'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(bypass.active, isTrue);
    expect(player.state.audioEffects.single.enabled, isFalse);
    expect(find.text('Dry'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Dry'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(bypass.active, isFalse);
    expect(player.state.audioEffects.single.enabled, isTrue);
    expect(find.text('FX'), findsOneWidget);
  });
}
