import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/now_playing_page.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/studio_shell.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';

import '../support/demo_page.dart';
import '../support/layout_harness.dart';
import 'playback_fake.dart';

/// Pumps the shell as the app builds it, on the Playback section with the
/// real [NowPlayingPage] over [player], at [size]. Touch sizes get phone
/// insets, like the shell goldens.
Future<void> pumpPlayback(
  WidgetTester tester,
  PlaybackFake player, {
  required StudioSize size,
  Palette palette = Palette.dark,
  double textScale = 1,
  VoidCallback? onOpenFiles,
  VoidCallback? onOpenStream,
}) async {
  final input = inputFor(size);
  setStudioView(
    tester,
    size.size,
    padding: input == InputMode.touch
        ? phoneInsets(size.size)
        : EdgeInsets.zero,
  );
  usePalette(palette);
  final router = createAppRouter(
    shell: (navigationShell) => PlaybackShortcuts(
      player: player,
      enabled: input == InputMode.pointer,
      child: StudioShell(
        navigationShell: navigationShell,
        miniPlayer: (context, variant) =>
            MiniPlayer(player: player, variant: variant),
      ),
    ),
    page: (section) => section == Section.nowPlaying
        ? NowPlayingPage(
            player: player,
            onOpenFiles: onOpenFiles ?? () {},
            onOpenStream: onOpenStream ?? () {},
          )
        : DemoPage(section: section),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(palette, input: input),
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: LayoutScope(inputMode: input, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
