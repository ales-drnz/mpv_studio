import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/now_playing_page.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_meter.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/studio_shell.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';

import '../../tool/showcase/showcase.dart';
import '../support/demo_page.dart';
import '../support/layout_harness.dart';
import 'showcase_player.dart';

/// The desktop showcase window, as the README's GIFs show it.
const Size desktopShowcaseSize = Size(1280, 953);

/// The phone showcase screen.
const Size phoneShowcaseSize = Size(412, 915);

/// Pumps the shell as the app builds it, on [section], with the real
/// Playback page over [player], inside [scene]'s stage, at [size] (touch
/// below 1024 wide, with phone insets). The cover is decoded before the
/// first frame, so it is there from the start. Other sections show the
/// placeholder pages of the shell tests until their scenes bring their
/// own. The waveform's playhead follows the reported position only, not
/// the wall clock.
Future<void> pumpShowcaseApp(
  WidgetTester tester,
  ShowcasePlayer player, {
  required Scene scene,
  required Size size,
  Section section = Section.nowPlaying,
  Palette palette = Palette.dark,
  Widget Function(Section section)? page,
}) async {
  final input = size.width < 1024 ? InputMode.touch : InputMode.pointer;
  setStudioView(
    tester,
    size,
    padding: input == InputMode.touch ? phoneInsets(size) : EdgeInsets.zero,
  );
  usePalette(palette);
  WaveformMeter.debugStopwatch = StillStopwatch.new;
  addTearDown(() => WaveformMeter.debugStopwatch = Stopwatch.new);
  final router = createAppRouter(
    shell: (navigationShell) => PlaybackShortcuts(
      player: player,
      enabled: input == InputMode.pointer,
      child: StudioShell(
        navigationShell: navigationShell,
        miniPlayer: (context, variant) => MiniPlayer(
          player: player,
          variant: variant,
          onOpen: () => navigationShell.goBranch(Section.nowPlaying.index),
        ),
      ),
    ),
    page: (s) => s == Section.nowPlaying
        ? NowPlayingPage(
            player: player,
            onOpenFiles: () {},
            onOpenStream: () {},
          )
        : (page?.call(s) ?? DemoPage(section: s)),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ShowcaseStage(
      scene: scene,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(palette, input: input),
        themeAnimationDuration: Duration.zero,
        routerConfig: router,
        builder: (context, child) =>
            LayoutScope(inputMode: input, child: child!),
      ),
    ),
  );
  if (section != Section.nowPlaying) router.go(section.path);
  final art = player.state.coverArt;
  if (art != null) {
    final context = tester.element(find.byType(Navigator).first);
    await tester.runAsync(() => precacheImage(MemoryImage(art.bytes), context));
  }
  // Not pumpAndSettle: a playing track never settles.
  for (var i = 0; i < 6; i++) {
    await tester.pump(scene.step);
  }
}
