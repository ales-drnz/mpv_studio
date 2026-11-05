import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/http_options.dart';
import 'package:mpv_studio/features/stream/stream_catalog.dart';

/// The stream options of the Lab: a live radio reopens when it drops, and
/// an entry can fail at once instead of retrying.
void main() {
  test('the reference radios reopen when they drop', () {
    final radio = labStreams.first.items.first;
    expect(radio.live, isTrue);
    expect(streamMedia(radio).streamLavfOptions, {'reconnect_streamed': '1'});
  });

  test('every Icecast radio of the Lab is live', () {
    for (final item in labStreams.expand((c) => c.items)) {
      if (item.url.endsWith('.m3u8')) continue;
      expect(item.live, isTrue, reason: item.label);
    }
  });

  test('a file or a playlist does not', () {
    final hls = labStreams
        .expand((c) => c.items)
        .firstWhere((i) => i.url.endsWith('.m3u8'));
    expect(hls.live, isFalse);
    expect(streamMedia(hls).streamLavfOptions, isNull);
  });

  test('the Lab URL carries reconnect and fail fast', () {
    const options = HttpOptions(reconnect: true, failFast: true);
    expect(options.media('https://example.test/live').streamLavfOptions, {
      'reconnect_streamed': '1',
      'reconnect_on_network_error': '0',
    });
    expect(options.count, 2);
    expect(
      const HttpOptions().media('https://example.test/a').streamLavfOptions,
      isNull,
    );
  });
}
