import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
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
import 'package:mpv_studio/ui/theme_host.dart';

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
Future<ShowcaseApp> pumpShowcaseApp(
  WidgetTester tester,
  ShowcasePlayer player, {
  required Scene scene,
  required Size size,
  Section section = Section.nowPlaying,
  Palette palette = Palette.dark,
  RackController? rack,
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
  final theme = ThemeController(
    initial: palette.isDark ? ThemeMode.dark : ThemeMode.light,
  );
  addTearDown(theme.dispose);
  final router = createAppRouter(
    shell: (navigationShell) => PlaybackShortcuts(
      player: player,
      enabled: input == InputMode.pointer,
      child: StudioShell(
        navigationShell: navigationShell,
        miniPlayer: (context, variant) => MiniPlayer(
          player: player,
          rack: rack,
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
      child: StudioThemeHost(
        controller: theme,
        builder: (context, active) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(active, input: input),
          themeAnimationDuration: Duration.zero,
          routerConfig: router,
          builder: (context, child) =>
              LayoutScope(inputMode: input, child: child!),
        ),
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
  await scene.settleImages();
  return ShowcaseApp(router, theme);
}

/// What a scene may steer in the app it pumped.
class ShowcaseApp {
  ShowcaseApp(this.router, this.theme);

  final GoRouter router;
  final ThemeController theme;
}

/// Puts [covers] (PNG bytes by URL) in the image cache as if downloaded,
/// so `Image.network` on those URLs draws them from the first frame and
/// nothing reaches the network.
Future<void> cacheNetworkCovers(
  WidgetTester tester,
  Map<String, Uint8List> covers,
) async {
  for (final MapEntry(key: url, value: bytes) in covers.entries) {
    late final ui.Image image;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
      codec.dispose();
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
      NetworkImage(url),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image)),
      ),
    );
  }
}

/// The step of the live readouts for this render (see
/// `showcaseUpdateHz`), or null to move them every frame.
Duration? showcaseUpdateInterval() {
  final hz = showcaseUpdateHz;
  return hz == null ? null : Duration(microseconds: (1e6 / hz).round());
}

/// Sets [player] up for [scene]: readouts on the render's step, seeks on
/// that grid, and the playhead moving on each frame.
void drivePlayer(Scene scene, ShowcasePlayer player) {
  final every = showcaseUpdateInterval();
  player
    ..updateInterval = every
    ..seekGrid = every ?? scene.step;
  scene.onFrame = (_, dt) => player.advance(dt);
}

/// [d] rounded to a multiple of [step].
Duration onGrid(Duration d, Duration step) =>
    step * (d.inMicroseconds / step.inMicroseconds).round();

/// Plays on until the playhead is one frame short of [first], the
/// position of the scene's first frame, so the GIF loops without a jump.
Future<void> playUntilLoop(
  Scene scene,
  ShowcasePlayer player,
  Duration first,
) async {
  while (player.playhead + scene.step < first) {
    await scene.frame();
  }
  expect(player.playhead + scene.step, first, reason: 'the loop must close');
}

/// Takes the playhead back with the Left key (5 s a press, key caps
/// showing) far enough that, [tailMs] of scene later and maybe a little
/// waiting, it reaches the first frame's position [first]: how a scene
/// with no seek of its own closes its loop. Focus must be outside text
/// fields, where the playback shortcuts listen.
Future<void> rewindToLoop(
  Scene scene,
  ShowcasePlayer player,
  Duration first, {
  int tailMs = 700,
}) async {
  const stepBack = PlaybackShortcuts.seekStep;
  final ahead = player.playhead - first + Duration(milliseconds: tailMs + 1000);
  final presses = (ahead.inMicroseconds / stepBack.inMicroseconds).ceil();
  for (var i = 0; i < presses; i++) {
    await scene.press(LogicalKeyboardKey.arrowLeft, label: '←', holdMs: 260);
    await scene.wait(60);
  }
}
