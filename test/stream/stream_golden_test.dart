import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

/// A resolver with the calls of one simulated expiry in its log, at a fixed
/// time.
SignedUrlResolver _resolverWithLog() {
  final resolver = SignedUrlResolver(
    clock: () => DateTime(2026, 10, 13, 18, 42, 7),
  );
  final entry = SignedUrlResolver.wrap('http://localhost:8000/01_pulse.flac');
  final expired =
      resolver.resolve(
            SourceResolveRequest(
              media: Media(entry),
              uri: entry,
              isRetry: false,
            ),
          )
          as String;
  final fresh =
      resolver.resolve(
            SourceResolveRequest(
              media: Media(entry),
              uri: expired,
              isRetry: true,
            ),
          )
          as String;
  resolver.resolve(
    SourceResolveRequest(media: Media(entry), uri: fresh, isRetry: false),
  );
  return resolver;
}

/// The Stream page's Lab and Resolver tabs at every size (dark) and three
/// in light; a server sign-in and an empty library on a phone and a
/// desktop window.
void main() {
  setUpAll(loadStudioFonts);

  Future<void> golden(
    WidgetTester tester,
    Widget page,
    String size,
    String name, {
    Palette palette = Palette.dark,
  }) async {
    await pumpAt(tester, page, size, palette: palette);
    expectNoOverflow(tester, reason: '$name $size');
    final theme = palette.isDark ? 'dark' : 'light';
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/${name}_${theme}_$size.png'),
    );
  }

  for (final tab in [StreamTab.lab, StreamTab.resolver]) {
    Widget page() => streamView(
      player: StreamPlayer(),
      resolver: _resolverWithLog(),
      tab: tab,
    );
    for (final s in studioSizes) {
      testWidgets('${tab.name} dark at $s', (tester) async {
        await golden(tester, page(), s.name, tab.name);
      }, skip: skipGoldens);
    }
    for (final size in ['360x780', '1024x700', '1920x1080']) {
      testWidgets('${tab.name} light at $size', (tester) async {
        await golden(tester, page(), size, tab.name, palette: Palette.light);
      }, skip: skipGoldens);
    }
  }

  for (final size in ['360x780', '1440x900']) {
    testWidgets('server sign-in at $size', (tester) async {
      await golden(
        tester,
        streamView(player: StreamPlayer(), tab: StreamTab.jellyfin),
        size,
        'server_sign_in',
      );
    }, skip: skipGoldens);

    testWidgets('empty library at $size', (tester) async {
      await golden(
        tester,
        streamView(
          player: StreamPlayer(),
          plex: FakeServer(kind: ServerKind.plex, connected: true),
          tab: StreamTab.plex,
        ),
        size,
        'empty_library',
      );
    }, skip: skipGoldens);
  }
}
