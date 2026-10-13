import 'package:dart_plex/dart_plex.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/plex_transcode_session_manager.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/studio/source_resolvers.dart';

import 'stream_fakes.dart';

/// Answers every Plex `/decision` with a playable code.
class _PlayablePlex extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/transcode/universal/decision')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'MediaContainer': <String, dynamic>{'generalDecisionCode': 1001},
          },
        ),
      );
      return;
    }
    handler.reject(DioException(requestOptions: options, message: 'offline'));
  }
}

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
      dio: Dio()..interceptors.add(_PlayablePlex()),
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
    expect(await chain.installOn(player), isTrue);
    expect(player.calls, ['setSourceResolver']);
    expect(player.resolver, isNotNull);
  });
}
