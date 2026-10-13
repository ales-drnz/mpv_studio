import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/media_server.dart';

void main() {
  test('a bare host gets http and the default port', () {
    expect(
      normalizeServerBase('192.168.1.10', 8096),
      'http://192.168.1.10:8096',
    );
    expect(
      normalizeServerBase(' nas.local/ ', 32400),
      'http://nas.local:32400',
    );
    expect(
      normalizeServerBase('nas.local:9000', 8096),
      'http://nas.local:9000',
    );
  });

  test('a full URL keeps its scheme and port', () {
    expect(
      normalizeServerBase('https://jf.example.com', 8096),
      'https://jf.example.com',
    );
    expect(normalizeServerBase('http://host:80/', 8096), 'http://host:80');
    expect(
      normalizeServerBase('https://example.com/jellyfin/', 8096),
      'https://example.com/jellyfin',
    );
  });
}
