import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/http_options.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
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
    // A real stopwatch reads 1 ms now and then (a cold first call), which
    // changed the log text between runs.
    timer: (work) {
      work();
      return const Duration(microseconds: 300);
    },
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

const _tracks = [
  ServerTrack(
    id: '1',
    title: 'So What',
    artist: 'Miles Davis',
    album: 'Kind of Blue',
    duration: Duration(minutes: 9, seconds: 22),
  ),
  ServerTrack(
    id: '2',
    title: 'Blue in Green',
    artist: 'Miles Davis',
    album: 'Kind of Blue',
    duration: Duration(minutes: 5, seconds: 37),
    isFavorite: true,
  ),
  ServerTrack(
    id: '3',
    title: 'Peace Piece',
    artist: 'Bill Evans',
    album: 'Everybody Digs Bill Evans',
    duration: Duration(minutes: 6, seconds: 42),
  ),
];

const _albums = [
  ServerAlbum(
    id: 'a',
    title: 'Kind of Blue',
    artist: 'Miles Davis',
    year: 1959,
  ),
  ServerAlbum(
    id: 'b',
    title: 'Everybody Digs Bill Evans',
    artist: 'Bill Evans',
  ),
  ServerAlbum(id: 'c', title: 'Time Out', artist: 'Dave Brubeck', year: 1959),
  ServerAlbum(id: 'd', title: 'Mingus Ah Um', artist: 'Charles Mingus'),
];

/// A player on the second track of the library.
StreamPlayer _playingTrack() => StreamPlayer(
  PlayerState(
    playlist: Playlist([
      Media(
        'https://jellyfin.test/2',
        extras: const {'serverId': '2', 'server': 'jellyfin'},
      ),
    ], index: 0),
  ),
);

/// A login store that hands back a saved share.
class _SavedShare extends NoSambaLogin {
  @override
  Future<SambaLogin?> load() async =>
      const SambaLogin(host: 'nas.local', share: 'Music');
}

/// The Stream page's Lab and Resolver tabs at every size (dark) and three
/// in light; sign-in cards, a library, its albums, the HTTP options, a
/// share and the error state at a phone and a desktop size, both themes.
void main() {
  setUpAll(loadStudioFonts);
  setUp(() => HttpOptions.lastUsed = const HttpOptions());

  Future<void> golden(
    WidgetTester tester,
    Widget page,
    String size,
    String name, {
    Palette palette = Palette.dark,
    Future<void> Function()? then,
  }) async {
    await pumpAt(tester, page, size, palette: palette);
    if (then != null) await then();
    expectNoOverflow(tester, reason: '$name $size');
    final theme = palette.isDark ? 'dark' : 'light';
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/${name}_${theme}_$size.png'),
    );
  }

  for (final tab in [StreamTab.lab, StreamTab.resolver]) {
    Widget page() => streamView(
      player: StreamPlayer(
        PlayerState(
          playlist: Playlist([
            tab == StreamTab.lab
                ? const Media(
                    'https://streams.radiomast.io/ref-128k-mp3-stereo-preroll',
                  )
                : const Media('none'),
          ], index: 0),
        ),
      ),
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

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette.isDark ? 'dark' : 'light';
    for (final size in ['360x780', '1440x900']) {
      testWidgets('server sign-in $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(player: StreamPlayer(), tab: StreamTab.jellyfin),
          size,
          'server_sign_in',
          palette: palette,
        );
      }, skip: skipGoldens);

      testWidgets('empty library $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(
            player: StreamPlayer(),
            plex: FakeServer(kind: ServerKind.plex, connected: true),
            tab: StreamTab.plex,
          ),
          size,
          'empty_library',
          palette: palette,
          then: tester.pumpAndSettle,
        );
      }, skip: skipGoldens);

      testWidgets('library error $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(
            player: StreamPlayer(),
            jellyfin: FakeServer(
              connected: true,
              fetchError: Exception('The server answered 500.'),
            ),
            tab: StreamTab.jellyfin,
          ),
          size,
          'library_error',
          palette: palette,
          then: tester.pumpAndSettle,
        );
      }, skip: skipGoldens);
    }

    for (final size in ['412x915', '1440x900']) {
      testWidgets('library songs $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(
            player: _playingTrack(),
            jellyfin: FakeServer(connected: true, tracks: _tracks),
            tab: StreamTab.jellyfin,
          ),
          size,
          'library_songs',
          palette: palette,
          then: tester.pumpAndSettle,
        );
      }, skip: skipGoldens);

      testWidgets('album open $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(
            player: _playingTrack(),
            jellyfin: FakeServer(
              connected: true,
              albums: _albums,
              albumTracks: {'a': _tracks.sublist(0, 2)},
            ),
            tab: StreamTab.jellyfin,
          ),
          size,
          'album_open',
          palette: palette,
          then: () async {
            await tester.pumpAndSettle();
            await tester.tap(find.text('Albums'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Kind of Blue'));
            await tester.pumpAndSettle();
          },
        );
      }, skip: skipGoldens);

      testWidgets('album grid $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(
            player: StreamPlayer(),
            jellyfin: FakeServer(connected: true, albums: _albums),
            tab: StreamTab.jellyfin,
          ),
          size,
          'album_grid',
          palette: palette,
          then: () async {
            await tester.pumpAndSettle();
            await tester.tap(find.text('Albums'));
            await tester.pumpAndSettle();
          },
        );
      }, skip: skipGoldens);

      testWidgets('http options $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(player: StreamPlayer()),
          size,
          'http_options',
          palette: palette,
          then: () async {
            await tester.tap(find.byTooltip('HTTP options'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Add header'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.widgetWithText(TextField, 'Value'),
              'a, b',
            );
            await tester.pumpAndSettle();
          },
        );
      }, skip: skipGoldens);

      testWidgets('samba folder $theme at $size', (tester) async {
        final share = FakeShare({
          '': const [
            SambaEntry(name: 'Jazz', isDirectory: true),
            SambaEntry(name: 'Rock', isDirectory: true),
            SambaEntry(
              name: 'Take Five.flac',
              isDirectory: false,
              size: 31457280,
            ),
            SambaEntry(name: 'Naima.mp3', isDirectory: false, size: 8912345),
          ],
        });
        final player = StreamPlayer(
          PlayerState(
            playlist: Playlist([
              sambaMedia(
                const SambaLogin(host: 'nas.local', share: 'Music'),
                '',
                'Naima.mp3',
              ),
            ], index: 0),
          ),
        );
        await golden(
          tester,
          streamView(
            player: player,
            tab: StreamTab.samba,
            samba: SambaTab(
              actions: actionsFor(player),
              connector: (_) async => share,
              store: _SavedShare(),
            ),
          ),
          size,
          'samba_folder',
          palette: palette,
          then: tester.pumpAndSettle,
        );
      }, skip: skipGoldens);

      testWidgets('samba sign-in $theme at $size', (tester) async {
        await golden(
          tester,
          streamView(player: StreamPlayer(), tab: StreamTab.samba),
          size,
          'samba_sign_in',
          palette: palette,
          then: tester.pumpAndSettle,
        );
      }, skip: skipGoldens);
    }
  }
}
