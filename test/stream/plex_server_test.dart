import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/plex_server.dart';
import 'package:mpv_studio/features/stream/plex_transcode_session_manager.dart';

void main() {
  test('a Plex entry carries the session it registers', () {
    const track = ServerTrack(
      id: '42',
      title: 'Song',
      artist: 'Band',
      album: 'Record',
      duration: Duration.zero,
    );
    const options = StreamOptions(
      codec: TranscodeCodec.mp3,
      bitrateKbps: 128,
      protocol: StreamProtocol.hls,
      transport: StreamTransport.mpegts,
    );
    expect(PlexServer().mediaExtras(track, options), {
      PlexTranscodeSessionManager.extrasKey: {
        'ratingKey': '42',
        'codec': 'mp3',
        'bitrateKbps': 128,
        'transcode': true,
        'protocol': 'hls',
        'container': 'mpegts',
      },
    });
  });
}
