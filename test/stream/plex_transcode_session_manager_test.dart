import 'package:dart_plex/dart_plex.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/plex_transcode_session_manager.dart';

/// Answers every `/decision` with a playable code and counts the calls.
class _FakePlex extends Interceptor {
  int decisions = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/transcode/universal/decision')) {
      decisions++;
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'MediaContainer': <String, dynamic>{'generalDecisionCode': 1001},
        },
      ));
      return;
    }
    handler.reject(DioException(requestOptions: options, message: 'offline'));
  }
}

SourceResolveRequest _request(String uri, {bool isRetry = false}) =>
    SourceResolveRequest(media: Media(uri), uri: uri, isRetry: isRetry);

String? _session(String url) => Uri.parse(url).queryParameters['session'];

void main() {
  late _FakePlex fake;
  late PlexTranscodeSessionManager manager;

  setUp(() {
    fake = _FakePlex();
    final dio = Dio()..interceptors.add(fake);
    final client = PlexClient(
      credentials: const PlexCredentials(
        clientIdentifier: 'test-client',
        product: 'MPV Studio',
        version: '0.3.0',
        device: 'test',
        deviceName: 'test',
        platform: 'Generic',
      ),
      dio: dio,
    );
    client.setToken('token');
    client.connect('http://plex.test:32400', accessToken: 'token');
    manager = PlexTranscodeSessionManager(client);
  });

  tearDown(() => manager.dispose());

  test('leaves entries that are not Plex markers alone', () async {
    expect(await manager.resolveSource(_request('https://example.com/a.mp3')),
        isNull);
    expect(await manager.resolveSource(_request('plex-transcode://unknown')),
        isNull);
    expect(fake.decisions, 0);
  });

  test('resolves a marker once and reuses the URL on a re-open', () async {
    final marker = manager.register(
      ratingKey: '42',
      codec: 'aac',
      fallbackUrl: 'http://plex.test/fallback',
    );
    final first = await manager.resolveSource(_request(marker));
    expect(first, contains('/music/:/transcode/universal/start.mpd'));
    final again = await manager.resolveSource(_request(marker));
    expect(again, first);
    expect(fake.decisions, 1);
  });

  test('a retry opens a fresh session with a new URL', () async {
    final marker = manager.register(
      ratingKey: '42',
      codec: 'aac',
      fallbackUrl: 'http://plex.test/fallback',
    );
    final first = (await manager.resolveSource(_request(marker)))!;
    // On a retry the entry is still the marker; the uri is the failed URL.
    final retry = (await manager.resolveSource(SourceResolveRequest(
      media: Media(marker),
      uri: first,
      isRetry: true,
    )))!;
    expect(retry, isNot(first));
    expect(_session(retry), isNot(_session(first)));
    expect(fake.decisions, 2);
  });

  test('direct play falls back to the given URL when the part is unknown',
      () async {
    final marker = manager.register(
      ratingKey: '42',
      codec: 'aac',
      fallbackUrl: 'http://plex.test/fallback',
      transcode: false,
    );
    expect(await manager.resolveSource(_request(marker)),
        'http://plex.test/fallback');
    expect(fake.decisions, 0);
  });
}
