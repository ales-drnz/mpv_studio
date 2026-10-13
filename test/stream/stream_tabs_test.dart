import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/http_options.dart';
import 'package:mpv_studio/features/stream/lab_tab.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';
import 'stream_fakes.dart';

const _track1 = ServerTrack(
  id: 't1',
  title: 'First light',
  artist: 'Quartet',
  album: 'Dawn',
  duration: Duration(minutes: 3),
);
const _track2 = ServerTrack(
  id: 't2',
  title: 'Second wind',
  artist: 'Quartet',
  album: 'Dawn',
  duration: Duration(minutes: 4),
);
const _album = ServerAlbum(
  id: 'a1',
  title: 'Dawn',
  artist: 'Quartet',
  year: 2024,
);

void main() {
  setUpAll(loadStudioFonts);
  setUp(() {
    HttpOptions.lastUsed = const HttpOptions();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a tab is built on its first visit only', (tester) async {
    var sambaBuilt = 0;
    await pumpAt(
      tester,
      streamView(
        player: StreamPlayer(),
        samba: Builder(
          builder: (_) {
            sambaBuilt++;
            return const Text('samba body');
          },
        ),
      ),
      '1440x900',
    );
    expect(sambaBuilt, 0);
    await tester.tap(find.text('Samba'));
    await tester.pumpAndSettle();
    expect(find.text('samba body'), findsOneWidget);
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    expect(find.text('samba body', skipOffstage: false), findsOneWidget);
  });

  group('Resolver tab', () {
    testWidgets('logs every resolver call as it happens', (tester) async {
      final resolver = SignedUrlResolver();
      await pumpAt(
        tester,
        streamView(
          player: StreamPlayer(),
          resolver: resolver,
          tab: StreamTab.resolver,
        ),
        '1440x900',
      );
      expect(find.textContaining('No calls yet'), findsOneWidget);

      final entry = SignedUrlResolver.wrap('http://localhost:8000/a.flac');
      final expired =
          resolver.resolve(
                SourceResolveRequest(
                  media: Media(entry),
                  uri: entry,
                  isRetry: false,
                ),
              )
              as String;
      await tester.pump();
      expect(find.text('Expired link'), findsOneWidget);
      expect(find.text('Before open'), findsOneWidget);

      resolver.resolve(
        SourceResolveRequest(media: Media(entry), uri: expired, isRetry: true),
      );
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Fresh link'), findsOneWidget);
      expect(
        find.textContaining('gave http://localhost:8000/a.flac?exp='),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Clear the log'));
      await tester.pump();
      expect(find.textContaining('No calls yet'), findsOneWidget);
    });

    testWidgets('the switch turns simulated expiry off', (tester) async {
      final resolver = SignedUrlResolver();
      await pumpAt(
        tester,
        streamView(
          player: StreamPlayer(),
          resolver: resolver,
          tab: StreamTab.resolver,
        ),
        '1440x900',
      );
      await tester.tap(find.text('Simulate expiry'));
      await tester.pump();
      expect(resolver.simulateExpiry, isFalse);
    });

    testWidgets('plays a signed example through the resolver scheme', (
      tester,
    ) async {
      final player = StreamPlayer();
      await pumpAt(
        tester,
        streamView(player: player, tab: StreamTab.resolver),
        '1440x900',
      );
      await tester.tap(find.text('MP3 128k Stereo, signed'));
      await tester.pump();
      expect(
        player.loaded.single.uri,
        'studio-signed://https://streams.radiomast.io/ref-128k-mp3-stereo',
      );
    });

    testWidgets('refuses to sign a URL without a scheme', (tester) async {
      final player = StreamPlayer();
      await pumpAt(
        tester,
        streamView(player: player, tab: StreamTab.resolver),
        '1440x900',
      );
      final field = find.widgetWithText(
        TextField,
        'URL to sign, e.g. http://localhost:8000/a.flac',
      );
      await tester.enterText(field, 'localhost:8000/a.flac');
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();
      expect(player.loaded, isEmpty);
      expect(
        find.textContaining('Enter a full http or https URL'),
        findsOneWidget,
      );

      await tester.enterText(field, 'http://localhost:8000/a.flac');
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();
      expect(
        player.loaded.single.uri,
        'studio-signed://http://localhost:8000/a.flac',
      );
      expect(
        find.textContaining('Enter a full http or https URL'),
        findsNothing,
      );
    });
  });

  group('Lab URL entry', () {
    Future<StreamPlayer> pumpLab(WidgetTester tester) async {
      final player = StreamPlayer();
      await pumpAt(tester, streamView(player: player), '1440x900');
      return player;
    }

    Future<void> openOptions(WidgetTester tester) async {
      await tester.tap(find.byTooltip('HTTP options'));
      await tester.pumpAndSettle();
    }

    testWidgets('plays the URL with its headers, user agent and chunks', (
      tester,
    ) async {
      final player = await pumpLab(tester);
      await openOptions(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'User agent'),
        'StudioTest/1.0',
      );
      await tester.tap(find.text('Add header'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'X-Token');
      await tester.enterText(find.widgetWithText(TextField, 'Value'), 'abc123');
      await tester.tap(find.text('8 MiB'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Paste a URL'),
        'http://localhost:8000/01_pulse.flac',
      );
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();

      final media = player.loaded.single;
      expect(media.uri, 'http://localhost:8000/01_pulse.flac');
      expect(media.httpHeaders, {
        'X-Token': 'abc123',
        'User-Agent': 'StudioTest/1.0',
      });
      expect(media.httpChunkSize, 8 << 20);
      expect(HttpOptions.lastUsed.userAgent, 'StudioTest/1.0');
    });

    testWidgets('refuses a header value with a comma', (tester) async {
      final player = await pumpLab(tester);
      await openOptions(tester);
      await tester.tap(find.text('Add header'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Accept');
      await tester.enterText(find.widgetWithText(TextField, 'Value'), 'a, b');
      await tester.pump();
      expect(find.text('commas are not allowed.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Paste a URL'),
        'http://localhost:8000/a.flac',
      );
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();
      expect(player.loaded, isEmpty);
      expect(find.text('Accept: commas are not allowed.'), findsOneWidget);
    });

    testWidgets('a browser user agent is sent to Settings, Network', (
      tester,
    ) async {
      final player = StreamPlayer();
      await pumpAt(
        tester,
        Scaffold(
          body: LabTab(
            actions: actionsFor(player),
            hasGlobalUserAgent: () => true,
          ),
        ),
        '1440x900',
      );
      await openOptions(tester);
      expect(find.text('Default (Settings, Network)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'User agent'),
        'Mozilla/5.0 (KHTML, like Gecko)',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Paste a URL'),
        'http://localhost:8000/a.flac',
      );
      await tester.tap(find.byTooltip('Play').first);
      await tester.pump();
      expect(player.loaded, isEmpty);
      expect(
        find.textContaining('A user agent with commas goes in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('a bare URL plays with no options', (tester) async {
      final player = await pumpLab(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Paste a URL'),
        'http://localhost:8000/a.flac',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();
      expect(player.loaded.single.httpHeaders, isNull);
      expect(player.loaded.single.httpChunkSize, isNull);
    });
  });

  group('server sign-in', () {
    Future<FakeServer> pumpSignIn(WidgetTester tester, {Object? error}) async {
      final server = FakeServer(connectError: error);
      await pumpAt(
        tester,
        streamView(
          player: StreamPlayer(),
          jellyfin: server,
          tab: StreamTab.jellyfin,
        ),
        '360x780',
      );
      return server;
    }

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server address'),
        '192.168.1.10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'alex',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret',
      );
    }

    testWidgets('asks for the address and the username', (tester) async {
      final server = await pumpSignIn(tester);
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.text('The server address is required.'), findsOneWidget);
      expect(find.text('The username is required.'), findsOneWidget);
      expect(server.log, isEmpty);
    });

    testWidgets('Enter on the password signs in and opens the library', (
      tester,
    ) async {
      final server = await pumpSignIn(tester);
      await fill(tester);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(server.log, ['connect 192.168.1.10 alex']);
      expect(find.text('No songs'), findsOneWidget);
    });

    testWidgets('says when the credentials are wrong', (tester) async {
      await pumpSignIn(tester, error: FakeAuthError());
      await fill(tester);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.text('The server refused the username or password.'),
        findsOneWidget,
      );
    });

    testWidgets('says when the server is unreachable', (tester) async {
      await pumpSignIn(tester, error: const SocketException('refused'));
      await fill(tester);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not reach the server. Check the address and the network.',
        ),
        findsOneWidget,
      );
    });
  });

  group('server library', () {
    testWidgets('a tapped song queues the list from it', (tester) async {
      final player = StreamPlayer();
      await pumpAt(
        tester,
        streamView(
          player: player,
          jellyfin: FakeServer(connected: true, tracks: [_track1, _track2]),
          tab: StreamTab.jellyfin,
        ),
        '1440x900',
      );
      await tester.tap(find.text('First light'));
      await tester.pump();
      expect(player.calls, ['openAll 2']);
      final first = player.loaded.first;
      expect(first.extras?['serverId'], 't1');
      expect(first.extras?['server'], 'jellyfin');
      expect(first.uri, 'https://jellyfin.test/t1?mode=transcode');
    });

    testWidgets('a song that cannot be built returns to the sign-in form', (
      tester,
    ) async {
      final player = StreamPlayer();
      final server = FakeServer(connected: true, tracks: [_track1])
        ..streamError = const NotConnectedException('Jellyfin');
      await pumpAt(
        tester,
        streamView(player: player, jellyfin: server, tab: StreamTab.jellyfin),
        '1440x900',
      );
      await tester.tap(find.text('First light'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(player.loaded, isEmpty);
      expect(find.text('Connect to Jellyfin'), findsOneWidget);
    });

    testWidgets('a network failure offers a retry', (tester) async {
      final server = FakeServer(
        connected: true,
        fetchError: const SocketException('refused'),
      );
      await pumpAt(
        tester,
        streamView(
          player: StreamPlayer(),
          jellyfin: server,
          tab: StreamTab.jellyfin,
        ),
        '1440x900',
      );
      expect(find.text('Jellyfin is not reachable'), findsOneWidget);
      server.fetchError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No songs'), findsOneWidget);
    });

    testWidgets('an expired session returns to the sign-in form', (
      tester,
    ) async {
      final server = FakeServer(connected: true, fetchError: FakeAuthError());
      await pumpAt(
        tester,
        streamView(
          player: StreamPlayer(),
          jellyfin: server,
          tab: StreamTab.jellyfin,
        ),
        '1440x900',
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect to Jellyfin'), findsOneWidget);
      expect(find.text('The session expired. Sign in again.'), findsOneWidget);
      expect(server.log, contains('logout'));
    });

    Widget albums(StreamPlayer player) => streamView(
      player: player,
      jellyfin: FakeServer(
        connected: true,
        albums: const [_album],
        albumTracks: const {
          'a1': [_track1, _track2],
        },
      ),
      tab: StreamTab.jellyfin,
    );

    testWidgets('albums open beside the grid on a wide window', (tester) async {
      final player = StreamPlayer();
      await pumpAt(tester, albums(player), '1440x900');
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.text('Pick an album'), findsOneWidget);
      await tester.tap(find.text('Dawn'));
      await tester.pumpAndSettle();
      expect(find.text('Second wind'), findsOneWidget);
      expect(find.text('Quartet, 2024, 2 tracks'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(player.calls, ['openAll 2']);
    });

    testWidgets('on a phone the album covers the grid and back closes it', (
      tester,
    ) async {
      await pumpAt(tester, albums(StreamPlayer()), '360x780');
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dawn'));
      await tester.pumpAndSettle();
      expect(find.text('First light'), findsOneWidget);
      expect(find.byTooltip('Back to albums'), findsOneWidget);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(find.text('First light'), findsNothing);
      expect(find.text('Dawn'), findsOneWidget);
    });

    testWidgets('a long press offers play next on a phone', (tester) async {
      final player = StreamPlayer(
        const PlayerState(playlist: Playlist([Media('a'), Media('b')])),
      );
      await pumpAt(
        tester,
        streamView(
          player: player,
          jellyfin: FakeServer(connected: true, tracks: [_track1]),
          tab: StreamTab.jellyfin,
        ),
        '360x780',
      );
      await tester.longPress(find.text('First light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play next'));
      await tester.pumpAndSettle();
      expect(player.calls, ['add', 'move 2 1']);
      expect(player.state.playlist.items[1].extras?['serverId'], 't1');
    });
  });

  group('Samba tab', () {
    testWidgets('signs in, walks folders and goes up on back', (tester) async {
      final player = StreamPlayer();
      final share = FakeShare({
        '': const [
          SambaEntry(name: 'Jazz', isDirectory: true),
          SambaEntry(name: 'notes.txt', isDirectory: false, size: 10),
        ],
        'Jazz': const [
          SambaEntry(name: 'b side.flac', isDirectory: false, size: 4 << 20),
          SambaEntry(name: 'a side.mp3', isDirectory: false, size: 3 << 20),
        ],
      });
      SambaLogin? used;
      await pumpAt(
        tester,
        Scaffold(
          body: SambaTab(
            actions: actionsFor(player),
            restore: () async => null,
            connector: (login) async {
              used = login;
              return share;
            },
          ),
        ),
        '360x780',
      );
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.text('The host is required.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'),
        'nas.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Share'),
        'Music',
      );
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(used?.host, 'nas.local');
      expect(find.text('Jazz'), findsOneWidget);
      expect(find.text('notes'), findsNothing);

      await tester.tap(find.text('Jazz'));
      await tester.pumpAndSettle();
      expect(find.text('Music/Jazz'), findsOneWidget);
      await tester.tap(find.text('b side'));
      await tester.pump();
      expect(player.loaded.map((m) => m.uri), [
        'smb2://nas.local/Music/Jazz/b%20side.flac',
      ]);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(find.text('Jazz'), findsOneWidget);
    });
  });
}
