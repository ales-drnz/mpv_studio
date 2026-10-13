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
}
