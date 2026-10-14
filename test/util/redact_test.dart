import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/util/redact.dart';

void main() {
  test('takes user names and passwords out of every URL', () {
    expect(
      withoutCredentials(
        'Opening smb2://HOME;alex:s3cr%40t@nas/Music/a.flac done',
      ),
      'Opening smb2://nas/Music/a.flac done',
    );
    expect(
      withoutCredentials('studio-signed://http://me:secret@nas:8000/a.flac'),
      'studio-signed://http://nas:8000/a.flac',
    );
    expect(
      withoutCredentials('a http://u:p@x/1 and ftp://v@y/2'),
      'a http://x/1 and ftp://y/2',
    );
  });

  test('leaves text without credentials alone', () {
    const line = 'http://nas/a.flac?x=1 user@example.com';
    expect(withoutCredentials(line), line);
  });

  group('redactSecrets masks', () {
    for (final name in sensitiveParameters) {
      test('the $name query parameter', () {
        final line =
            'Failed to open https://jf.test/Audio/42/universal'
            '?UserId=7&$name=s3cret&Container=flac';
        final out = redactSecrets(line);
        expect(out, isNot(contains('s3cret')));
        expect(out, contains('$name=$redactedValue&Container=flac'));
        expect(out, contains('?UserId=7&'));
      });
    }

    test('names in any case and as the first parameter', () {
      expect(
        redactSecrets('http://pms.test/a?x-plex-token=abc'),
        'http://pms.test/a?x-plex-token=$redactedValue',
      );
      expect(
        redactSecrets('GET /Items?APIKEY=abc'),
        'GET /Items?APIKEY=$redactedValue',
      );
    });

    test('header fields and quoted values', () {
      expect(
        redactSecrets('X-Emby-Token: abc123 sent'),
        'X-Emby-Token: $redactedValue sent',
      );
      expect(
        redactSecrets('MediaBrowser Client="Studio", Token="abc123"'),
        'MediaBrowser Client="Studio", Token=$redactedValue',
      );
    });

    test('credentials too, and leaves other names alone', () {
      expect(
        redactSecrets('smb2://u:p@nas/a.flac?PlaySessionToken=1&mytoken=2'),
        'smb2://nas/a.flac?PlaySessionToken=1&mytoken=2',
      );
    });
  });
}
