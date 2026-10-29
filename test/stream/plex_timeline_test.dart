import 'package:dart_plex/dart_plex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mpv_studio/features/stream/plex_server.dart';

void main() {
  late List<Uri> timelines;
  late PlexServer server;

  setUp(() {
    timelines = [];
    final client = PlexClient(
      credentials: const PlexCredentials(
        clientIdentifier: 'test-client',
        product: 'MPV Studio',
        version: '0.3.0',
        device: 'test',
        deviceName: 'test',
        platform: 'Generic',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/:/timeline') timelines.add(request.url);
        return http.Response('', 200);
      }),
    );
    client.setToken('token');
    client.connect('http://plex.test:32400', accessToken: 'token');
    server = PlexServer.withClient(client, '7');
  });

  test('a report carries the track length, which PMS needs', () async {
    await server.reportStart('11', duration: const Duration(seconds: 200));
    await server.reportProgress(
      '11',
      position: const Duration(seconds: 15),
      duration: const Duration(seconds: 200),
      paused: true,
    );
    await server.reportStopped(
      '11',
      position: const Duration(seconds: 30),
      duration: const Duration(seconds: 200),
    );
    expect(
      [for (final u in timelines) u.queryParameters['state']],
      ['playing', 'paused', 'stopped'],
    );
    expect([
      for (final u in timelines) u.queryParameters['duration'],
    ], everyElement('200000'));
    expect(timelines[1].queryParameters['time'], '15000');
  });

  test('nothing is reported while the length is unknown', () async {
    await server.reportStart('11', duration: Duration.zero);
    await server.reportStopped(
      '11',
      position: const Duration(seconds: 3),
      duration: Duration.zero,
    );
    expect(timelines, isEmpty);
  });
}
