import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/rack_environment.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_panel.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/shell/mini_player.dart';
import 'package:mpv_studio/shell/playback_shortcuts.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/shell/studio_shell.dart';
import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';
import 'package:mpv_studio/ui/theme_host.dart';

import '../effects/rack_harness.dart';
import '../now_playing/playback_fake.dart';
import '../now_playing/playback_harness.dart' show pumpPlayback;
import '../queue/queue_fixture.dart';
import '../settings/studio_fakes.dart';
import '../support/demo_page.dart';
import '../support/fake_engine.dart';
import '../support/fake_player.dart';
import '../support/layout_harness.dart';

/// The design showcase: the real pages inside the real shell, rendered
/// with real fonts into the folder named by STUDIO_DESIGN_SHOTS, for
/// reviewing the design language on every page at once. It runs only when
/// that variable is set, as
/// `STUDIO_DESIGN_SHOTS=/some/dir flutter test --update-goldens <this file>`.
void main() {
  final out = Platform.environment['STUDIO_DESIGN_SHOTS'];
  if (out == null) {
    test('renders only with STUDIO_DESIGN_SHOTS set', () {}, skip: true);
    return;
  }
  setUpAll(loadStudioFonts);

  Future<void> shot(String name) => expectLater(
    find.byType(WidgetsApp).first,
    matchesGoldenFile(Uri.file('$out/$name.png')),
  );

  /// The shell on [section] with [page] as that section's body and a
  /// mini-player over [mini].
  Future<void> pumpIn(
    WidgetTester tester, {
    required StudioSize size,
    required Section section,
    required Widget Function() page,
    required FakePlayer mini,
    RackController? rack,
    Palette palette = Palette.dark,
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
    final theme = ThemeController(
      initial: palette.isDark ? ThemeMode.dark : ThemeMode.light,
    );
    addTearDown(theme.dispose);
    final router = createAppRouter(
      shell: (navigationShell) => PlaybackShortcuts(
        player: mini,
        enabled: input == InputMode.pointer,
        child: StudioShell(
          navigationShell: navigationShell,
          miniPlayer: (context, variant) => MiniPlayer(
            player: mini,
            rack: rack,
            variant: variant,
            onOpen: () {},
          ),
        ),
      ),
      page: (s) => s == section ? page() : DemoPage(section: s),
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
          builder: (context, child) =>
              LayoutScope(inputMode: input, child: child!),
        ),
      ),
    );
    if (section != Section.nowPlaying) router.go(section.path);
    await tester.pumpAndSettle();
  }

  String themeOf(Palette p) => p.isDark ? 'dark' : 'light';

  // ---- Playback -------------------------------------------------------
  for (final (size, palette) in [
    ('412x915', Palette.dark),
    ('1440x900', Palette.dark),
    ('412x915', Palette.light),
    ('1440x900', Palette.light),
  ]) {
    testWidgets('playback $size ${themeOf(palette)}', (tester) async {
      final player = playingTrack();
      await pumpPlayback(
        tester,
        player,
        size: studioSize(size),
        palette: palette,
      );
      // Playing: the pause glyph shows. Fixed frames, the meters animate.
      player.emit((s) => s.copyWith(playWhenReady: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expectNoOverflow(tester);
      await shot('playback_${themeOf(palette)}_$size');
    });
  }

  // ---- Queue ----------------------------------------------------------
  Future<void> queue(WidgetTester tester, String size, Palette palette) async {
    final (player, details) = await threeEntries(() => tester.pump());
    player.emit((s) => s.copyWith(playWhenReady: true));
    await pumpIn(
      tester,
      size: studioSize(size),
      section: Section.queue,
      mini: player,
      palette: palette,
      page: () => QueueView(
        player: player,
        guard: unguarded,
        details: details,
        pickFiles: () async => const [],
        pickFolder: () async => const [],
        pickPlaylist: () async => null,
      ),
    );
    expectNoOverflow(tester);
  }

  for (final (size, palette) in [
    ('412x915', Palette.dark),
    ('1440x900', Palette.dark),
    ('412x915', Palette.light),
    ('1440x900', Palette.light),
  ]) {
    testWidgets('queue $size ${themeOf(palette)}', (tester) async {
      await queue(tester, size, palette);
      await shot('queue_${themeOf(palette)}_$size');
    });
  }

  // ---- Shell with the mini-player -------------------------------------
  for (final (size, palette) in [
    ('915x412', Palette.dark),
    ('800x1280', Palette.dark),
    ('915x412', Palette.light),
  ]) {
    testWidgets('shell $size ${themeOf(palette)}', (tester) async {
      await queue(tester, size, palette);
      await shot('shell_${themeOf(palette)}_$size');
    });
  }

  // ---- Extras: the collapsed sidebar and the More sheet ----------------
  testWidgets('collapsed sidebar 1440x900', (tester) async {
    await queue(tester, '1440x900', Palette.dark);
    await tester.tap(find.byTooltip('Collapse the sidebar'));
    await tester.pumpAndSettle();
    await shot('extra_collapsed_dark_1440x900');
  });

  testWidgets('more sheet 412x915', (tester) async {
    await queue(tester, '412x915', Palette.dark);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await shot('extra_more_sheet_dark_412x915');
  });

  // ---- Effects --------------------------------------------------------
  for (final (size, palette) in [
    ('412x915', Palette.dark),
    ('1440x900', Palette.dark),
    ('412x915', Palette.light),
    ('1440x900', Palette.light),
  ]) {
    testWidgets('effects $size ${themeOf(palette)}', (tester) async {
      final rack = RackController(
        FakeEngine([
          const BassEffect(gain: 6, frequency: 120),
          const AcompressorEffect(ratio: 4),
          kMeterStage,
        ]),
      );
      addTearDown(rack.dispose);
      rack.open(rack.chain.stages.first.id);
      await pumpIn(
        tester,
        size: studioSize(size),
        section: Section.effects,
        mini: demoPlayer(),
        rack: rack,
        palette: palette,
        page: () => RackEnvironment(
          taps: RecordingTaps().call,
          pcm: const Stream.empty(),
          spectrum: const SpectrumSettings(),
          loudness: const Stream.empty(),
          child: SignalChainView(
            rack: rack,
            footer: LoudnessPanel(
              meterOn: true,
              onMeterChanged: (_) {},
              readings: const Stream.empty(),
              scan: const LoudnessScan(
                state: LoudnessScanState.ready,
                integrated: -11.2,
                range: 6.4,
                truePeak: 0.9,
              ),
              normalizationOn: true,
              appliedGainDb: -6.8,
              targetLufs: -18,
            ),
          ),
        ),
      );
      expectNoOverflow(tester);
      await shot('effects_${themeOf(palette)}_$size');
    });
  }

  // ---- Settings -------------------------------------------------------
  for (final (size, palette) in [
    ('412x915', Palette.dark),
    ('1440x900', Palette.dark),
    ('412x915', Palette.light),
    ('1440x900', Palette.light),
  ]) {
    testWidgets('settings $size ${themeOf(palette)}', (tester) async {
      final h = await SettingsHarness.create();
      await pumpIn(
        tester,
        size: studioSize(size),
        section: Section.settings,
        mini: demoPlayer(),
        palette: palette,
        page: () => h.wrap(const SettingsPage()),
      );
      await tester.tap(find.text('Network').first);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await shot('settings_${themeOf(palette)}_$size');
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
