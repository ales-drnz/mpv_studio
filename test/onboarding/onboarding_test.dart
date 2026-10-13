import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_studio/features/onboarding/onboarding.dart';
import 'package:mpv_studio/shell/router.dart';
import 'package:mpv_studio/shell/sections.dart';
import 'package:mpv_studio/studio/app_settings.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/theme.dart';

import '../settings/studio_fakes.dart';
import '../support/layout_harness.dart';

class WelcomeApp {
  WelcomeApp(this.router, this.settings, this.player);
  final GoRouter router;
  final AppSettings settings;
  final StudioFakePlayer player;
}

/// The router with placeholder pages, at [size], with the welcome screen
/// opened as the app opens it on launch.
Future<WelcomeApp> pumpWelcome(
  WidgetTester tester, {
  String size = '360x780',
  Palette palette = Palette.dark,
  Map<String, Object?>? stored,
  List<String> picked = const [],
  Future<List<String>> Function()? pick,
}) async {
  final s = studioSize(size);
  final input = inputFor(s);
  setStudioView(tester, s.size);
  usePalette(palette);
  final settings = await loadSettings(stored);
  final player = StudioFakePlayer();
  final router = createAppRouter(
    shell: (navigationShell) => navigationShell,
    page: (section) => Scaffold(body: Text('page ${section.name}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(palette, input: input),
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      builder: (context, child) => LayoutScope(inputMode: input, child: child!),
    ),
  );
  final context = router.routerDelegate.navigatorKey.currentContext!;
  final actions = OnboardingActions(
    player: player,
    guard: <T>(call) async => call(),
    pickFiles: pick ?? () async => picked,
  );
  // Not awaited: it completes when the screen closes.
  welcomeOnFirstLaunch(context, settings, actions);
  await tester.pumpAndSettle();
  return WelcomeApp(router, settings, player);
}

void main() {
  setUpAll(loadStudioFonts);

  testWidgets('shows on the first launch and Skip records it', (tester) async {
    final app = await pumpWelcome(tester);
    expect(find.text('Welcome to MPV Studio'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MPV Studio'), findsNothing);
    expect(app.settings.onboarded, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('does not show once seen', (tester) async {
    await pumpWelcome(tester, stored: {'onboarded': true});
    expect(find.text('Welcome to MPV Studio'), findsNothing);
  });

  testWidgets('Android back and Escape skip it', (tester) async {
    final app = await pumpWelcome(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MPV Studio'), findsNothing);
    expect(app.settings.onboarded, isTrue);
    await tester.pump(const Duration(seconds: 1));

    final desktop = await pumpWelcome(tester, size: '1440x900');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MPV Studio'), findsNothing);
    expect(desktop.settings.onboarded, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('files picked after the screen closed are not queued', (
    tester,
  ) async {
    final picking = Completer<List<String>>();
    final app = await pumpWelcome(tester, pick: () => picking.future);
    await tester.tap(find.text('Open audio files'));
    await tester.pump();
    // The user closes the screen while the file picker is still open.
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 50));
    picking.complete(['/m/a.flac']);
    await tester.pumpAndSettle();
    expect(app.player.calls, isEmpty);
    expect(find.text('page ${Section.nowPlaying.name}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the demo plays and opens Playback', (tester) async {
    final app = await pumpWelcome(tester);
    await tester.tap(find.text('Try a demo stream'));
    await tester.pumpAndSettle();
    expect(
      app.player.calls.single,
      startsWith('open Media(uri: ${demoStream.uri}'),
    );
    expect(find.text('page ${Section.nowPlaying.name}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('open files queues them and opens the Queue', (tester) async {
    final app = await pumpWelcome(tester, picked: ['/m/a.flac', '/m/b.mp3']);
    await tester.tap(find.text('Open audio files'));
    await tester.pumpAndSettle();
    expect(app.player.calls.single, startsWith('openAll'));
    expect(find.text('page ${Section.queue.name}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a server choice opens its Stream tab', (tester) async {
    final app = await pumpWelcome(tester, size: '1440x900');
    await tester.tap(find.text('Plex'));
    await tester.pumpAndSettle();
    expect(
      app.router.routerDelegate.currentConfiguration.uri.toString(),
      '/stream?tab=plex',
    );
    await tester.pump(const Duration(seconds: 1));
  });

  for (final (size, palette) in [
    ('360x780', Palette.dark),
    ('915x412', Palette.dark),
    ('1440x900', Palette.dark),
    ('1024x700', Palette.dark),
    ('360x780', Palette.light),
    ('412x915', Palette.light),
    ('1440x900', Palette.light),
  ]) {
    final theme = palette.isDark ? 'dark' : 'light';
    testWidgets('golden $theme $size', (tester) async {
      await pumpWelcome(tester, size: size, palette: palette);
      expectNoOverflow(tester, reason: size);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_${theme}_$size.png'),
      );
    }, skip: skipGoldens);
  }

  testWidgets('no overflow at text scale 1.3 on 360x780', (tester) async {
    await pumpWelcome(tester);
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
  });
}
