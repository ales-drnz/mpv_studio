import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/studio_shell.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';
import 'package:mpv_studio/ui/theme_host.dart';

import 'demo_page.dart';
import 'fake_player.dart';

/// A named window size of the responsive contract.
class StudioSize {
  const StudioSize(this.name, this.width, this.height);

  /// File-name friendly, e.g. `360x780`.
  final String name;
  final double width;
  final double height;

  Size get size => Size(width, height);

  @override
  String toString() => name;
}

/// Every size the layout must handle: phones in portrait and landscape, a
/// tablet, laptop and desktop windows, and an ultrawide screen.
const List<StudioSize> studioSizes = [
  StudioSize('360x780', 360, 780),
  StudioSize('412x915', 412, 915),
  StudioSize('780x360', 780, 360),
  StudioSize('915x412', 915, 412),
  StudioSize('800x1280', 800, 1280),
  StudioSize('1024x700', 1024, 700),
  StudioSize('1440x900', 1440, 900),
  StudioSize('1920x1080', 1920, 1080),
  StudioSize('2560x1080', 2560, 1080),
];

/// Looks up a [studioSizes] entry by name.
StudioSize studioSize(String name) =>
    studioSizes.firstWhere((s) => s.name == name);

/// The phone-like safe-area insets used for the touch sizes.
EdgeInsets phoneInsets(Size size) => size.height > size.width
    ? const EdgeInsets.only(top: 24, bottom: 16)
    : const EdgeInsets.only(top: 24, left: 32);

/// The input mode a size stands for: touch for phones and the tablet,
/// pointer for the desktop sizes.
InputMode inputFor(StudioSize size) =>
    size.width < 1024 ? InputMode.touch : InputMode.pointer;

/// Golden files are rendered on Linux; other hosts rasterise text a little
/// differently, so golden tests skip there.
final bool skipGoldens = !Platform.isLinux;

bool _fontsLoaded = false;

/// Loads Roboto (also as the `monospace` family) and the Material icons
/// from the Flutter SDK, so goldens show readable text and real icons
/// instead of the test font's boxes. Runs once per test process.
Future<void> loadStudioFonts() async {
  if (_fontsLoaded) return;
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      // .../flutter/bin/cache/artifacts/engine/<host>/flutter_tester
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String file) async {
    final bytes = await File('$dir/$file').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  const roboto = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ];
  for (final family in ['Roboto', 'monospace']) {
    final loader = FontLoader(family);
    for (final file in roboto) {
      loader.addFont(read(file));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
  _fontsLoaded = true;
}

/// Sets the test view to [size] at 1x with the given safe-area [padding],
/// restored after the test.
void setStudioView(
  WidgetTester tester,
  Size size, {
  EdgeInsets padding = EdgeInsets.zero,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: padding.bottom,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

/// Activates [palette] for this test, back to dark afterwards.
void usePalette(Palette palette) {
  Palette.activate(palette);
  addTearDown(() => Palette.activate(Palette.dark));
}

Widget _scaled(BuildContext context, Widget child, double textScale) =>
    MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    );

/// Pumps [child] as the home page of a themed app at [size], with the
/// layout forced to [input], the given [palette] and [textScale].
Future<void> pumpStudio(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 800),
  InputMode input = InputMode.pointer,
  Palette palette = Palette.dark,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  setStudioView(tester, size, padding: padding);
  usePalette(palette);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(palette, input: input),
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => _scaled(
        context,
        LayoutScope(inputMode: input, child: child!),
        textScale,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// The whole shell, as the app builds it (shortcuts included), with placeholder [DemoPage]s for
/// the sections and a real [MiniPlayer] on [player].
class ShellHarness {
  ShellHarness(this.router, this.theme, this.player);

  final GoRouter router;
  final ThemeController theme;
  final FakePlayer player;
}

/// A queue with one titled track, so the mini-player has something to
/// show.
FakePlayer demoPlayer() => FakePlayer(
  const PlayerState(
    playlist: Playlist([
      Media(
        'https://example.test/one.flac',
        extras: {'title': 'Blue in Green', 'artist': 'Bill Evans Trio'},
      ),
    ]),
    duration: Duration(minutes: 5, seconds: 37),
    position: Duration(minutes: 2, seconds: 3),
  ),
);

/// Pumps the shell at [size] on [section], with the given [input],
/// [palette] and [textScale]. The theme switch in the shell works (the
/// shell runs under a [StudioThemeHost]).
Future<ShellHarness> pumpShell(
  WidgetTester tester, {
  required Size size,
  Section section = Section.queue,
  InputMode input = InputMode.pointer,
  Palette palette = Palette.dark,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  FakePlayer? player,
}) async {
  setStudioView(tester, size, padding: padding);
  addTearDown(() => Palette.activate(Palette.dark));
  final fake = player ?? demoPlayer();
  final theme = ThemeController(
    initial: palette.isDark ? ThemeMode.dark : ThemeMode.light,
  );
  addTearDown(theme.dispose);
  final router = createAppRouter(
    // As AppShell builds it, minus the player services.
    shell: (navigationShell) => PlaybackShortcuts(
      player: fake,
      enabled: input == InputMode.pointer,
      child: StudioShell(
        navigationShell: navigationShell,
        miniPlayer: (context, variant) => MiniPlayer(
          player: fake,
          variant: variant,
          onOpen: () => navigationShell.goBranch(Section.nowPlaying.index),
        ),
      ),
    ),
    page: (section) => DemoPage(section: section),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    StudioThemeHost(
      controller: theme,
      builder: (context, active) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(active, input: input),
        themeAnimationDuration: Duration.zero,
        routerConfig: router,
        builder: (context, child) => _scaled(
          context,
          LayoutScope(inputMode: input, child: child!),
          textScale,
        ),
      ),
    ),
  );
  if (section != Section.nowPlaying) router.go(section.path);
  await tester.pumpAndSettle();
  return ShellHarness(router, theme, fake);
}

/// Fails with a readable message when the last frames reported an
/// exception, such as a `RenderFlex` overflow.
void expectNoOverflow(WidgetTester tester, {String? reason}) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: [?reason, 'layout reported: $error'].join(': '),
  );
}
