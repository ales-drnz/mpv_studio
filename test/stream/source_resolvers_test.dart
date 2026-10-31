import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/plex_transcode_session_manager.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/studio/source_resolvers.dart';
import 'package:mpv_studio/studio/studio_log.dart';

import '../settings/studio_fakes.dart';

import 'stream_fakes.dart';

/// Answers every Plex `/decision` with a playable code.
final _playablePlex = MockClient((request) async {
  if (request.url.path.contains('/transcode/universal/decision')) {
    return http.Response(
      jsonEncode({
        'MediaContainer': {'generalDecisionCode': 1001},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  throw http.ClientException('offline', request.url);
});

SourceResolveRequest _first(String uri) =>
    SourceResolveRequest(media: Media(uri), uri: uri, isRetry: false);

void main() {
  late PlexTranscodeSessionManager plex;
  late SignedUrlResolver signed;
  late SourceResolverChain chain;

  setUp(() {
    final client = PlexClient(
      credentials: const PlexCredentials(
        clientIdentifier: 'test-client',
        product: 'MPV Studio',
        version: '0.3.0',
        device: 'test',
        deviceName: 'test',
        platform: 'Generic',
      ),
      httpClient: _playablePlex,
    );
    client.setToken('token');
    client.connect('http://plex.test:32400', accessToken: 'token');
    plex = PlexTranscodeSessionManager(client);
    signed = SignedUrlResolver()..simulateExpiry = false;
    chain = SourceResolverChain([plex.resolveSource, signed.resolve]);
  });

  tearDown(() => plex.dispose());

  test('a Plex marker goes to Plex', () async {
    final marker = plex.register(
      ratingKey: '7',
      codec: 'aac',
      fallbackUrl: 'http://plex.test/fallback',
    );
    final url = await chain(_first(marker));
    expect(url, contains('/music/:/transcode/universal/start.mpd'));
    expect(signed.log, isEmpty);
  });

  test('a signed link goes to the demo resolver', () async {
    const target = 'http://localhost:8000/01_pulse.flac';
    final url = await chain(_first(SignedUrlResolver.wrap(target)));
    expect(url, startsWith('$target?exp='));
    expect(signed.isValid(url!), isTrue);
    expect(signed.log, hasLength(1));
  });

  test('other entries pass through untouched', () async {
    expect(await chain(_first('https://example.com/a.mp3')), isNull);
    expect(await chain(_first('/music/a.flac')), isNull);
    expect(signed.log, isEmpty);
  });

  test('a retry renews an expired signed link', () async {
    signed.simulateExpiry = true;
    final entry = SignedUrlResolver.wrap('http://localhost:8000/a.mp3');
    final expired = (await chain(_first(entry)))!;
    expect(signed.isValid(expired), isFalse);
    expect(expired, contains('/${SignedUrlResolver.expiredPath}/'));

    final fresh = await chain(
      SourceResolveRequest(media: Media(entry), uri: expired, isRetry: true),
    );
    expect(fresh, isNot(expired));
    expect(fresh, startsWith('http://localhost:8000/a.mp3?exp='));
    expect(signed.isValid(fresh!), isTrue);
  });

  test('a throwing resolver is skipped', () async {
    final skipping = SourceResolverChain([
      (_) => throw StateError('broken'),
      (r) => 'https://next.test/${r.uri}',
    ]);
    expect(await skipping(_first('a')), 'https://next.test/a');
  });

  test('installs itself as the player resolver', () async {
    final player = StreamPlayer();
    expect(await chain.installOn(player), isNull);
    expect(player.calls, ['setSourceResolver']);
    expect(player.resolver, isNotNull);
  });

  test('a failing resolver is logged without the URL query', () async {
    final log = ConsoleLog();
    StudioLog.attach(log);
    addTearDown(() => StudioLog.detach(log));
    final failing = SourceResolverChain([(_) => throw StateError('expired')]);
    await failing(_first('https://pms.test/a.mp3?X-Plex-Token=secret'));
    final line = log.backlog.single.text;
    expect(line, contains('https://pms.test/a.mp3'));
    expect(line, isNot(contains('secret')));
  });

  test('a refused install becomes a launch failure', () async {
    final player = StudioFakePlayer()..refuse.add('setSourceResolver');
    final failure = await chain.installOn(player);
    expect(failure?.setting, 'Source resolvers');
  });
}
